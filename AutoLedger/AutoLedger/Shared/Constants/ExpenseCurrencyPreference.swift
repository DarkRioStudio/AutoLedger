import Foundation

enum ExpenseCurrencyPreference {
    static let userDefaultsKey = "expenseDefaultCurrencyCode"
    static let systemValue = "system"

    static var systemCurrencyCode: String {
        let code = Locale.autoupdatingCurrent.currency?.identifier
        return LedgerCurrencyOption.supportedCode(matching: code)
    }

    static var currentCode: String {
        let stored = UserDefaults.standard.string(forKey: userDefaultsKey) ?? systemValue
        guard stored != systemValue else {
            return systemCurrencyCode
        }
        return LedgerCurrencyOption.supportedCode(matching: stored)
    }

    static func normalizedRawValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != systemValue else {
            return systemValue
        }
        return LedgerCurrencyOption.supportedCode(matching: trimmed)
    }
}
