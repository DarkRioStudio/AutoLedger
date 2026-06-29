import Foundation

enum ScreenshotScene: String, CaseIterable {
    case preview
    case ocrBill = "ocr_bill"
    case quickCapture = "quick_capture"
    case voiceEntry = "voice_entry"
    case watchEcosystem = "watch_ecosystem"
    case importMethods = "import_methods"
    case autoExtract = "auto_extract"
    case reviewEdit = "review_edit"
    case monthlyReport = "monthly_report"
    case settingsManagement = "settings_management"
    case emailFolioImport = "email_folio_import"
    case cloudFolioInbox = "cloud_folio_inbox"
    case hotelStays = "hotel_stays"
    case proSubscription = "pro_subscription"
}

enum ScreenshotPlatform: String {
    case ios
    case ipad
    case mac
    case watch
}

enum ScreenshotModeConfig {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }

    static var platform: ScreenshotPlatform {
        guard let rawValue = argumentValue(after: "--screenshot-platform"),
              let platform = ScreenshotPlatform(rawValue: rawValue)
        else { return .ios }
        return platform
    }

    static var scene: ScreenshotScene {
        guard platform == .ios,
              let rawValue = argumentValue(after: "--screenshot-scene"),
              let scene = ScreenshotScene(rawValue: rawValue)
        else { return .preview }
        return scene
    }

    static var sceneIdentifier: String {
        argumentValue(after: "--screenshot-scene") ?? defaultSceneIdentifier(for: platform)
    }

    static var localeIdentifier: String {
        if let locale = argumentValue(after: "-AppleLocale") {
            return locale
        }
        return Locale.preferredLanguages.first ?? "zh-Hans"
    }

    static var usesFreeProState: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-free-pro")
    }

    private static func argumentValue(after key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key),
              args.indices.contains(index + 1)
        else { return nil }
        return args[index + 1]
    }

    private static func defaultSceneIdentifier(for platform: ScreenshotPlatform) -> String {
        switch platform {
        case .ios:
            ScreenshotScene.preview.rawValue
        case .ipad:
            "workspace_overview"
        case .mac:
            "mac_capture"
        case .watch:
            "watch_quick_add"
        }
    }
}
