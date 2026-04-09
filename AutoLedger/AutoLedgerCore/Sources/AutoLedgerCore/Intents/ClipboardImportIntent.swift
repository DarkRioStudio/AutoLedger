import AppIntents

/// 从剪切板读取支付截图并自动记账 —— 可添加到控制中心 / Siri / 快捷指令
public struct ClipboardImportIntent: AppIntent {
    nonisolated public static let title: LocalizedStringResource = "剪切板记账"
    nonisolated public static let description: IntentDescription = IntentDescription("从剪切板读取支付截图并自动记账")
    nonisolated public static let openAppWhenRun: Bool = true

    /// 主 App 启动时注入实际处理逻辑；Widget Extension 中为 nil
    @MainActor public static var handler: (() -> Void)?

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<String> {
        Self.handler?()
        return .result(value: "正在从剪切板导入...")
    }
}
