import WidgetKit
import SwiftUI

@main
struct ClipboardImportControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.autoledger.clipboard-import") {
            ControlWidgetButton(action: ClipboardImportIntent()) {
                Label("control.clipboard.title", systemImage: "doc.on.clipboard")
            }
        }
        .displayName("control.clipboard.title")
        .description("control.clipboard.description")
    }
}
