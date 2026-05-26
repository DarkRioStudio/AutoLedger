import Foundation

enum WatchScreenshotScene: String, CaseIterable {
    case quickAdd = "watch_quick_add"
    case recent = "watch_recent"
    case confirm = "watch_confirm"
    case sync = "watch_sync"
}

enum WatchScreenshotModeConfig {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--screenshot-mode")
    }

    static var scene: WatchScreenshotScene {
        guard argumentValue(after: "--screenshot-platform") == "watch",
              let rawValue = argumentValue(after: "--screenshot-scene"),
              let scene = WatchScreenshotScene(rawValue: rawValue)
        else { return .quickAdd }
        return scene
    }

    static var localeIdentifier: String {
        argumentValue(after: "-AppleLocale") ?? Locale.preferredLanguages.first ?? "zh-Hans"
    }

    private static func argumentValue(after key: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: key),
              args.indices.contains(index + 1)
        else { return nil }
        return args[index + 1]
    }
}
