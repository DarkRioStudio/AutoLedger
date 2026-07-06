import Foundation
import SwiftUI

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"

    nonisolated static let userDefaultsKey = "appLanguagePreference"
    nonisolated private static let catalogLanguageKeys = ["zh-Hans", "zh-Hant", "en", "ja", "ko"]

    nonisolated var id: String { rawValue }

    nonisolated var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .zhHans:
            return Locale(identifier: "zh-Hans")
        case .zhHant:
            return Locale(identifier: "zh-Hant")
        case .english:
            return Locale(identifier: "en")
        case .japanese:
            return Locale(identifier: "ja")
        case .korean:
            return Locale(identifier: "ko")
        }
    }

    nonisolated var catalogLanguageKey: String {
        switch self {
        case .system:
            let preferredIdentifier = Bundle.main.preferredLocalizations.first
            return Self.catalogLanguageKey(
                preferredIdentifier ?? Locale.autoupdatingCurrent.identifier
            )
        case .zhHans:
            return "zh-Hans"
        case .zhHant:
            return "zh-Hant"
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        }
    }

    var localizedTitleKey: LocalizedStringKey {
        switch self {
        case .system:
            return "language.option.system"
        case .zhHans:
            return "language.option.zh_hans"
        case .zhHant:
            return "language.option.zh_hant"
        case .english:
            return "language.option.english"
        case .japanese:
            return "language.option.japanese"
        case .korean:
            return "language.option.korean"
        }
    }

    nonisolated static var current: AppLanguagePreference {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
        return rawValue.flatMap(AppLanguagePreference.init(rawValue:)) ?? .system
    }

    nonisolated static func catalogLanguageKey(_ identifier: String) -> String {
        let normalized = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")

        if normalized.hasPrefix("ko") {
            return "ko"
        }
        if normalized.hasPrefix("ja") {
            return "ja"
        }
        if normalized.contains("hans") {
            return "zh-Hans"
        }
        if normalized.contains("hant") {
            return "zh-Hant"
        }
        if normalized == "zh" || normalized.hasPrefix("zh-") {
            if normalized.contains("-tw") || normalized.contains("-hk") || normalized.contains("-mo") {
                return "zh-Hant"
            }
            return "zh-Hans"
        }
        return "en"
    }

    nonisolated static func localizedString(
        _ key: String,
        locale: Locale,
        fallback: String? = nil
    ) -> String {
        localizedString(
            key,
            languageKey: catalogLanguageKey(locale.identifier),
            fallback: fallback
        )
    }

    nonisolated static func localizedString(
        _ key: String,
        languageKey: String,
        fallback: String? = nil
    ) -> String {
        let fallbackValue = fallback ?? key
        guard
            let path = Bundle.main.path(forResource: languageKey, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return Bundle.main.localizedString(forKey: key, value: fallbackValue, table: nil)
        }
        return bundle.localizedString(forKey: key, value: fallbackValue, table: nil)
    }

    nonisolated static func localizedStrings(_ key: String, fallback: String? = nil) -> Set<String> {
        var values = Set<String>()
        if let fallback, !fallback.isEmpty {
            values.insert(fallback)
        }
        for languageKey in catalogLanguageKeys {
            let value = localizedString(
                key,
                languageKey: languageKey,
                fallback: fallback
            )
            if !value.isEmpty {
                values.insert(value)
            }
        }
        return values
    }
}
