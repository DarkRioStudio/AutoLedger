import AppIntents
import Foundation
import OSLog

nonisolated(unsafe) private let openQuickAddLogger = Logger(subsystem: "top.darkrio326.AutoLedger", category: "OpenQuickAddIntent")

// MARK: - OpenQuickAddIntent

/// Shortcuts / Siri 动作：打开 AutoLedger 并直接进入快速记账界面。
struct OpenQuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "open_quick_add.intent.title"
    static var description: IntentDescription = IntentDescription("open_quick_add.intent.description")
    /// 必须打开 App。
    static var openAppWhenRun: Bool = true

    static var parameterSummary: some ParameterSummary {
        Summary("open_quick_add.parameter_summary")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // openAppWhenRun = true 保证 App 已在前台后触发导航
        await MainActor.run {
            QuickLedgerNavigationState.shared.markCreateTransactionPending()
            NotificationCenter.default.post(name: NotificationService.quickLedgerOpenLedgerEvent, object: nil)
            NotificationCenter.default.post(name: NotificationService.openNewTransactionEvent, object: nil)
        }
        openQuickAddLogger.info("[OpenQuickAdd] 已触发快速新增事务导航")
        return .result(value: String(localized: "open_quick_add.launched"))
    }
}
