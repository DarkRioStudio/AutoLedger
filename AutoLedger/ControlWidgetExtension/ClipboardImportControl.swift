import WidgetKit
import SwiftUI
import AutoLedgerCore

@main
struct ClipboardImportControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.autoledger.clipboard-import") {
            ControlWidgetButton(action: ClipboardImportIntent()) {
                Label("剪切板记账", systemImage: "doc.on.clipboard")
            }
        }
        .displayName("剪切板记账")
        .description("从剪切板读取支付截图并自动记账")
    }
}
