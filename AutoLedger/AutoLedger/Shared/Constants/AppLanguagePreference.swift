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
}
