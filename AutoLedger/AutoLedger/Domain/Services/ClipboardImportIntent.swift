import AppIntents
import Foundation

/// 从剪切板读取支付截图并自动记账，可添加到控制中心 / Siri / 快捷指令。
struct ClipboardImportIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "clipboard_import_intent.title"
    nonisolated static let description = IntentDescription("clipboard_import_intent.description")
    nonisolated static let openAppWhenRun = true

    @MainActor static var handler: (() -> Void)?

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        Self.handler?()
        return .result(value: String(localized: "clipboard_import_intent.running"))
    }
}

enum ClipboardImportIntentHandoff {
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let pendingRequestKey = "clipboardImportIntentPendingRequest"

    static func consumePendingRequest() -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              defaults.bool(forKey: pendingRequestKey) else { return false }
        defaults.removeObject(forKey: pendingRequestKey)
        return true
    }
}
