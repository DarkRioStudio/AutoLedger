import AppIntents
import Foundation

/// 从剪切板读取支付截图并自动记账 —— 可添加到控制中心 / Siri / 快捷指令
public struct ClipboardImportIntent: AppIntent {
    nonisolated public static let title: LocalizedStringResource = "clipboard_import_intent.title"
    nonisolated public static let description: IntentDescription = IntentDescription("clipboard_import_intent.description")
    nonisolated public static let openAppWhenRun: Bool = true

    /// 主 App 启动时注入实际处理逻辑；Widget Extension 中为 nil
    @MainActor public static var handler: (() -> Void)?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        Self.handler?()
        return .result(value: String(localized: "clipboard_import_intent.running"))
    }
}
