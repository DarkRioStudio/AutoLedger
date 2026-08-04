import Foundation

enum ExpenseCurrencyPreference {
    struct SystemCurrencyChange: Equatable {
        let previousCode: String
        let currentCode: String
    }

    static let userDefaultsKey = "expenseDefaultCurrencyCode"
    static let systemValue = "system"
    private static let acceptedSystemCurrencyCodeKey = "expenseAcceptedSystemCurrencyCode"

    static var systemCurrencyCode: String {
        let code = Locale.autoupdatingCurrent.currency?.identifier
        return LedgerCurrencyOption.supportedCode(matching: code)
    }

    static var currentCode: String {
        let stored = UserDefaults.standard.string(forKey: userDefaultsKey) ?? systemValue
        guard stored != systemValue else {
            return acceptedSystemCurrencyCode
        }
        return LedgerCurrencyOption.supportedCode(matching: stored)
    }

    static func prepareForLaunch() {
        guard UserDefaults.standard.string(forKey: acceptedSystemCurrencyCodeKey) == nil else { return }
        UserDefaults.standard.set(systemCurrencyCode, forKey: acceptedSystemCurrencyCodeKey)
    }

    static func pendingSystemCurrencyChange() -> SystemCurrencyChange? {
        let stored = normalizedRawValue(UserDefaults.standard.string(forKey: userDefaultsKey))
        guard stored == systemValue else { return nil }

        let previousCode = acceptedSystemCurrencyCode
        let currentCode = systemCurrencyCode
        guard previousCode != currentCode else { return nil }
        return SystemCurrencyChange(previousCode: previousCode, currentCode: currentCode)
    }

    static func useCurrentSystemCurrency() {
        let currentCode = systemCurrencyCode
        UserDefaults.standard.set(currentCode, forKey: acceptedSystemCurrencyCodeKey)
        UserDefaults.standard.set(systemValue, forKey: userDefaultsKey)
    }

    static func keepPreviousCurrency(after change: SystemCurrencyChange) {
        UserDefaults.standard.set(change.previousCode, forKey: userDefaultsKey)
        UserDefaults.standard.set(change.currentCode, forKey: acceptedSystemCurrencyCodeKey)
    }

    static func normalizedRawValue(_ value: String?) -> String {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, trimmed != systemValue else {
            return systemValue
        }
        return LedgerCurrencyOption.supportedCode(matching: trimmed)
    }

    private static var acceptedSystemCurrencyCode: String {
        prepareForLaunch()
        let stored = UserDefaults.standard.string(forKey: acceptedSystemCurrencyCodeKey)
        return LedgerCurrencyOption.supportedCode(matching: stored)
    }
}
