import AppIntents
import AutoLedgerCore
import Foundation
import OSLog

nonisolated(unsafe) private let parseLedgerLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "ParseLedgerTextIntent")

// MARK: - ParseLedgerTextIntent

/// Shortcuts 动作：将自然语言账单描述解析为结构化摘要，不入账，仅返回识别结果。
struct ParseLedgerTextIntent: AppIntent {
    static var title: LocalizedStringResource = "parse_ledger.intent.title"
    static var description: IntentDescription = IntentDescription("parse_ledger.intent.description")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "parse_ledger.text.title",
               description: "parse_ledger.text.description")
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("parse_ledger.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return .result(value: String(localized: "parse_ledger.empty_input"))
        }

        let store = try? SQLiteTransactionStore()
        let corrections = (try? store?.loadCategoryCorrections()) ?? [:]

        let result = VoiceLedgerParser().parse(normalized, corrections: corrections)
        parseLedgerLogger.info("[ParseLedger] 置信度：\(result.confidence.rawValue) 金额：\(result.amount ?? 0)")

        guard result.failureReason == nil,
              let amount = result.amount else {
            let reason = result.failureReason?.rawValue ?? "unknown"
            let msg = String(
                format: String(localized: "parse_ledger.parse_failed_format"),
                reason
            )
            return .result(value: msg)
        }

        let categoryTitle = result.category.title
        let dateStr = formatDate(result.occurredAt)
        let confidence = confidenceLabel(result.confidence)

        let summary = String(
            format: String(localized: "parse_ledger.result_format"),
            result.merchant.isEmpty ? String(localized: "parse_ledger.unknown_merchant") : result.merchant,
            amount,
            categoryTitle,
            dateStr,
            confidence
        )
        return .result(value: summary)
    }

    // MARK: Helpers

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return String(localized: "parse_ledger.today") }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }

    private func confidenceLabel(_ confidence: VoiceLedgerConfidence) -> String {
        switch confidence {
        case .high:        return String(localized: "parse_ledger.confidence.high")
        case .needsReview: return String(localized: "parse_ledger.confidence.medium")
        case .failed:      return String(localized: "parse_ledger.confidence.low")
        }
    }
}
