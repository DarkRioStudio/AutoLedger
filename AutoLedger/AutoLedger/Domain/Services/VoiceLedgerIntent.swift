import AppIntents
import AutoLedgerCore
import Foundation
import OSLog
import WidgetKit

nonisolated(unsafe) private let voiceIntentLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "VoiceLedgerIntent")

struct VoiceLedgerIntent: AppIntent {
    static var title: LocalizedStringResource = "voice_ledger.intent.title"
    static var description: IntentDescription = IntentDescription("voice_ledger.intent.description")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "voice_ledger.content.title", description: "voice_ledger.content.description")
    var content: String

    static var parameterSummary: some ParameterSummary {
        Summary("记录 \(\.$content)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let normalizedText = content.trimmingCharacters(in: .whitespacesAndNewlines)

        let store: SQLiteTransactionStore
        do {
            store = try SQLiteTransactionStore()
        } catch {
            return .result(value: String(localized: "quick_ledger.database_failed"))
        }

        let corrections = (try? store.loadCategoryCorrections()) ?? [:]
        let interpretation = await LedgerTextInterpreter().interpret(
            LedgerTextInterpretationInput(
                text: normalizedText,
                preferredSource: .voice,
                fallbackMerchant: nil,
                ocrMinConfidence: nil,
                categoryCorrections: corrections
            )
        )
        let result: VoiceLedgerParseResult
        if case .voice(let parsed, _, _) = interpretation {
            result = parsed
        } else {
            result = VoiceLedgerParser().parse(normalizedText, corrections: corrections)
        }

        guard result.confidence == .high,
              result.failureReason == nil,
              let receipt = result.makeReceipt(),
              let amount = result.amount else {
            let message = failureMessage(for: result.failureReason)
            writeDebugEvent(stage: .parseFailed, rawText: normalizedText, receipt: result.makeReceipt(), summary: message)
            return .result(value: message)
        }

        let existing = (try? store.loadTransactions()) ?? []
        let isDuplicate = existing.contains {
            $0.merchant == receipt.merchant &&
            abs($0.amount - amount) < 0.01 &&
            abs($0.occurredAt.timeIntervalSince(receipt.occurredAt)) < 60
        }
        let isTextDuplicate = ImportDuplicateDetector.hasOCRTextDuplicate(
            rawText: normalizedText,
            debugRecords: (try? store.loadDebugEvents()) ?? [],
            activeTransactionIDs: Set(existing.map(\.id)),
            imageSource: .voiceIntent,
            threshold: 0.95
        )

        if isDuplicate || isTextDuplicate {
            let message = String(
                format: String(localized: "voice_ledger_duplicate"),
                receipt.merchant,
                amount
            )
            writeDebugEvent(stage: .duplicateSkipped, rawText: normalizedText, receipt: receipt, summary: message)
            return .result(value: message)
        }

        let transaction = Transaction(
            merchant: receipt.merchant,
            amount: amount,
            occurredAt: receipt.occurredAt,
            category: receipt.suggestedCategory,
            source: .voice,
            note: String(localized: "voice_ledger_note")
        )

        do {
            try store.save(transaction: transaction)
        } catch {
            let message = String(localized: "voice_ledger_persistence_failed")
            writeDebugEvent(stage: .persistenceFailed, rawText: normalizedText, receipt: receipt, summary: "\(message)：\(error.localizedDescription)")
            return .result(value: message)
        }

        WidgetCenter.shared.reloadAllTimelines()

        await MainActor.run {
            NotificationCenter.default.post(name: NotificationService.didSaveTransactionFromIntent, object: nil)
        }

        await NotificationService.shared.scheduleQuickLedgerSuccessNotification(
            merchant: receipt.merchant,
            amount: amount,
            transactionID: transaction.id
        )

        let message = String(
            format: String(localized: "voice_ledger_success"),
            receipt.merchant,
            amount
        )
        voiceIntentLogger.info("[VoiceIntent] saved merchant=\(receipt.merchant) amount=\(amount)")
        writeDebugEvent(stage: .persisted, rawText: normalizedText, receipt: receipt, summary: message, transactionID: transaction.id)
        return .result(value: message)
    }

    nonisolated private func failureMessage(for reason: VoiceLedgerFailureReason?) -> String {
        switch reason {
        case .noAmount:
            return String(localized: "voice_ledger_no_amount")
        case .multipleAmounts:
            return String(localized: "voice_ledger_multiple_amounts")
        case .unsupportedIncomeOrTransfer:
            return String(localized: "voice_ledger_income_not_supported")
        default:
            return String(localized: "voice_ledger_unclear")
        }
    }

    nonisolated private func writeDebugEvent(
        stage: ImportDebugStage,
        rawText: String,
        receipt: ImportedReceipt?,
        summary: String,
        transactionID: UUID? = nil
    ) {
        let record = ImportDebugRecord(
            stage: stage,
            source: .voice,
            imageSource: .voiceIntent,
            rawText: rawText,
            parsedReceipt: receipt,
            summary: summary,
            transactionID: transactionID
        )
        guard let store = try? SQLiteTransactionStore() else { return }
        try? store.saveDebugEvent(record)
    }
}
