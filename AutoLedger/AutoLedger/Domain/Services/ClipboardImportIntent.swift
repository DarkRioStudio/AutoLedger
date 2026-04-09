import AppIntents
import UIKit

/// 从剪切板读取支付截图并自动记账 —— 无参数，可添加到控制中心 / Siri / 快捷指令
struct ClipboardImportIntent: AppIntent {
    static var title: LocalizedStringResource = "剪切板记账"
    static var description: IntentDescription = IntentDescription("从剪切板读取支付截图并自动记账")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        await MainActor.run {
            LedgerStore.shared?.attemptClipboardImport(force: true)
        }
        return .result(value: "正在从剪切板导入...")
    }
}
