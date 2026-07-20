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
            return .result(value: await saveAutomatically(result.draft))
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

    private func saveAutomatically(_ draft: StructuredLedgerJSONDraft) async -> String {
        let store: SQLiteTransactionStore
        do {
            store = try SQLiteTransactionStore()
        } catch {
            importJSONLogger.error("[ImportJSON] 数据库初始化失败：\(error.localizedDescription)")
            return String(localized: "quick_ledger.database_failed")
        }

        let transaction = await transaction(from: draft, store: store)
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

    private func transaction(from draft: StructuredLedgerJSONDraft, store: SQLiteTransactionStore) async -> Transaction {
        let targetContext = targetLedgerContext(in: store)
        let sourceCurrency = LedgerCurrencyOption.supportedCode(matching: draft.currency ?? targetContext.currencyCode)
        guard sourceCurrency != targetContext.currencyCode else {
            return Transaction(
                merchant: draft.merchant,
                amount: draft.amount,
                occurredAt: draft.occurredAt,
                categoryLabel: draft.categoryLabel,
                sourceLabel: ReceiptSource.manual.rawValue,
                note: note(from: draft, targetCurrencyCode: targetContext.currencyCode),
                ledgerID: targetContext.ledgerID,
                ledgerCurrencyCode: targetContext.currencyCode
            )
        }

        do {
            let quote = try await CommonAPIExchangeRateService.quote(
                baseCurrencyCode: sourceCurrency,
                quoteCurrencyCode: targetContext.currencyCode,
                date: draft.occurredAt
            )
            let convertedAmount = (draft.amount * quote.rate * 100).rounded() / 100
            return Transaction(
                merchant: draft.merchant,
                amount: convertedAmount,
                occurredAt: draft.occurredAt,
                categoryLabel: draft.categoryLabel,
                sourceLabel: ReceiptSource.manual.rawValue,
                note: note(from: draft, targetCurrencyCode: targetContext.currencyCode),
                ledgerID: targetContext.ledgerID,
                ledgerCurrencyCode: quote.quoteCurrencyCode,
                originalAmount: draft.amount,
                originalCurrencyCode: quote.baseCurrencyCode,
                exchangeRate: quote.rate,
                exchangeRateDate: quote.date,
                exchangeRateProvider: quote.provider
            )
        } catch {
            importJSONLogger.warning("[ImportJSON] 汇率换算失败，保留原始币种元数据：\(error.localizedDescription)")
            return Transaction(
                merchant: draft.merchant,
                amount: draft.amount,
                occurredAt: draft.occurredAt,
                categoryLabel: draft.categoryLabel,
                sourceLabel: ReceiptSource.manual.rawValue,
                note: note(from: draft, targetCurrencyCode: targetContext.currencyCode),
                ledgerID: targetContext.ledgerID,
                ledgerCurrencyCode: targetContext.currencyCode,
                originalAmount: draft.amount,
                originalCurrencyCode: sourceCurrency
            )
        }
    }

    private func targetLedgerContext(in store: SQLiteTransactionStore) -> (ledgerID: String, currencyCode: String) {
        let preferredLedgerID = UserDefaults.standard.string(forKey: "defaultWriteLedgerID") ?? TodaySpendingSummary.defaultLedgerID
        let profiles = (try? store.loadLedgerProfiles(includeArchived: false)) ?? []
        let profile = profiles.first { $0.id == preferredLedgerID }
            ?? profiles.first { $0.id == TodaySpendingSummary.defaultLedgerID }
            ?? LedgerProfile.defaultLocal()
        return (
            profile.id,
            LedgerCurrencyOption.supportedCode(
                matching: profile.currency ?? ExpenseCurrencyPreference.currentCode
            )
        )
    }

    private func note(from draft: StructuredLedgerJSONDraft, targetCurrencyCode: String) -> String {
        var parts: [String] = []
        if !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(draft.note.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let currency = draft.currency,
           LedgerCurrencyOption.supportedCode(matching: currency) != targetCurrencyCode {
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
