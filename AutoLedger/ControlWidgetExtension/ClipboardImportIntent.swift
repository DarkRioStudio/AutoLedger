import AppIntents
import Foundation

struct ClipboardImportIntent: AppIntent {
    nonisolated static let title: LocalizedStringResource = "clipboard_import_intent.title"
    nonisolated static let description = IntentDescription("clipboard_import_intent.description")
    nonisolated static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        ClipboardImportIntentHandoff.requestImport()
        return .result(value: String(localized: "clipboard_import_intent.running"))
    }
}

private enum ClipboardImportIntentHandoff {
    private static let appGroupIdentifier = "group.top.darkrio326.AutoLedger"
    private static let pendingRequestKey = "clipboardImportIntentPendingRequest"

    static func requestImport() {
        let defaults = UserDefaults(suiteName: appGroupIdentifier)
        defaults?.set(true, forKey: pendingRequestKey)
    }
}
