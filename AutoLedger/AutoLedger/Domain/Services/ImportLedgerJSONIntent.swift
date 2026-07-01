import AppIntents
import AutoLedgerCore
import Foundation
import OSLog
import UIKit
import WidgetKit

nonisolated(unsafe) private let importJSONLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "ImportLedgerJSONIntent")

/// Shortcuts 动作：从结构化 JSON 创建账单；高置信度自动保存，中等置信度交给 App 内确认页。
struct ImportLedgerJSONIntent: AppIntent {
    static var title: LocalizedStringResource = "import_ledger_json.intent.title"
    static var description: IntentDescription = IntentDescription("import_ledger_json.intent.description")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "import_ledger_json.text.title",
               description: "import_ledger_json.text.description",
               default: "")
    var jsonText: String

    static var parameterSummary: some ParameterSummary {
        Summary("import_ledger_json.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let input = normalizedInput()
        let result: StructuredLedgerJSONParseResult
        do {
            result = try StructuredLedgerJSONParser().parse(input)
        } catch {
            importJSONLogger.error("[ImportJSON] 解析失败：\(String(describing: error))")
            return .result(value: errorMessage(for: error))
        }

        switch result.decision {
        case .autoSave:
            return .result(value: saveAutomatically(result.draft))
        case .needsConfirmation:
            StructuredLedgerJSONIntentHandoffStore.save(
                StructuredLedgerJSONIntentHandoff(draft: result.draft, rawJSON: input)
            )
            return .result(value: String(localized: "import_ledger_json.review_required"))
        }
    }

    private func normalizedInput() -> String {
        let trimmed = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func saveAutomatically(_ draft: StructuredLedgerJSONDraft) -> String {
        let store: SQLiteTransactionStore
        do {
            store = try SQLiteTransactionStore()
        } catch {
            importJSONLogger.error("[ImportJSON] 数据库初始化失败：\(error.localizedDescription)")
            return String(localized: "quick_ledger.database_failed")
        }

        let transaction = transaction(from: draft)
        do {
            try store.save(transaction: transaction)
        } catch {
            importJSONLogger.error("[ImportJSON] 保存失败：\(error.localizedDescription)")
            return String(localized: "import_ledger_json.save_failed")
        }

        WidgetCenter.shared.reloadAllTimelines()
        NotificationService.markIntentLedgerSaveNeedsCloudPush()
        Task { @MainActor in
            QuickLedgerNavigationState.shared.markOpenLedgerPending()
            WatchConnectivityHost.shared.publishLatestLedgerSnapshot()
            NotificationCenter.default.post(name: NotificationService.didSaveTransactionFromIntent, object: nil)
            NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
        }

        return String(
            format: String(localized: "import_ledger_json.saved_format"),
            draft.merchant,
            draft.amount,
            draft.confidence
        )
    }

    private func transaction(from draft: StructuredLedgerJSONDraft) -> Transaction {
        Transaction(
            merchant: draft.merchant,
            amount: draft.amount,
            occurredAt: draft.occurredAt,
            categoryLabel: draft.categoryLabel,
            sourceLabel: ReceiptSource.manual.rawValue,
            note: note(from: draft)
        )
    }

    private func note(from draft: StructuredLedgerJSONDraft) -> String {
        var parts: [String] = []
        if !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(draft.note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let currency = draft.currency, currency != "CNY" {
            parts.append(String(format: String(localized: "import_ledger_json.currency_note_format"), currency))
        }
        parts.append(String(format: String(localized: "import_ledger_json.confidence_note_format"), draft.confidence))
        return parts.joined(separator: "\n")
    }

    private func errorMessage(for error: Error) -> String {
        guard let error = error as? StructuredLedgerJSONError else {
            return String(localized: "import_ledger_json.invalid_json")
        }
        switch error {
        case .emptyInput:
            return String(localized: "import_ledger_json.empty_input")
        case .invalidJSON:
            return String(localized: "import_ledger_json.invalid_json")
        case .missingAmount:
            return String(localized: "import_ledger_json.missing_amount")
        case .invalidAmount:
            return String(localized: "import_ledger_json.invalid_amount")
        case .missingMerchant:
            return String(localized: "import_ledger_json.missing_merchant")
        case .lowConfidence(let confidence):
            return String(
                format: String(localized: "import_ledger_json.low_confidence_format"),
                confidence
            )
        }
    }
}
