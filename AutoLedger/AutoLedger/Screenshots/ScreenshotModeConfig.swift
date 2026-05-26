import Foundation

enum ScreenshotScene: String, CaseIterable {
    case preview
    case quickCapture = "quick_capture"
    case importMethods = "import_methods"
    case autoExtract = "auto_extract"
    case reviewEdit = "review_edit"
    case monthlyReport = "monthly_report"
    case settingsManagement = "settings_management"
}

enum ScreenshotModeConfig {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }

    static var platform: String {
        argumentValue(after: "--screenshot-platform") ?? "ios"
    }

    static var scene: ScreenshotScene {
        guard platform == "ios",
              let rawValue = argumentValue(after: "--screenshot-scene"),
              let scene = ScreenshotScene(rawValue: rawValue)
        else { return .preview }
        return scene
    }

    static var localeIdentifier: String {
        if let locale = argumentValue(after: "-AppleLocale") {
            return locale
        }
        return Locale.preferredLanguages.first ?? "zh-Hans"
    }

    private static func argumentValue(after key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key),
              args.indices.contains(index + 1)
        else { return nil }
        return args[index + 1]
    }
}
