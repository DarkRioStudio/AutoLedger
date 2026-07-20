import Foundation

struct LedgerCurrencyOption: Identifiable, Hashable {
    static var defaultCode: String {
        let systemCode = Locale.autoupdatingCurrent.currency?.identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return common.contains { $0.code == systemCode } ? systemCode : "USD"
    }

    let code: String
    let symbol: String
    let decimalDigits: Int
    let localizedNames: CommonAPICatalogService.LocalizedText?

    init(
        code: String,
        symbol: String,
        decimalDigits: Int,
        localizedNames: CommonAPICatalogService.LocalizedText? = nil
    ) {
        self.code = code
        self.symbol = symbol
        self.decimalDigits = decimalDigits
        self.localizedNames = localizedNames
    }

    var id: String { code }

    var localizedTitle: String {
        let name = localizedNames?.localizedName ?? Locale.autoupdatingCurrent.localizedString(forCurrencyCode: code) ?? code
        return "\(code) · \(symbol) · \(name)"
    }

    static var common: [LedgerCurrencyOption] {
        let cached = CommonAPICatalogService.cachedCurrencyCatalog()?.currencies.map {
            LedgerCurrencyOption(
                code: $0.code,
                symbol: $0.symbol,
                decimalDigits: $0.decimalDigits,
                localizedNames: $0.names
            )
        } ?? []
        return cached.isEmpty ? bundledCommon : cached
    }

    private static let bundledCommon: [LedgerCurrencyOption] = [
        .init(code: "CNY", symbol: "¥", decimalDigits: 2),
        .init(code: "USD", symbol: "$", decimalDigits: 2),
        .init(code: "EUR", symbol: "€", decimalDigits: 2),
        .init(code: "JPY", symbol: "¥", decimalDigits: 0),
        .init(code: "GBP", symbol: "£", decimalDigits: 2),
        .init(code: "HKD", symbol: "HK$", decimalDigits: 2),
        .init(code: "MOP", symbol: "MOP$", decimalDigits: 2),
        .init(code: "TWD", symbol: "NT$", decimalDigits: 2),
        .init(code: "SGD", symbol: "S$", decimalDigits: 2),
        .init(code: "KRW", symbol: "₩", decimalDigits: 0),
        .init(code: "THB", symbol: "฿", decimalDigits: 2),
        .init(code: "MYR", symbol: "RM", decimalDigits: 2),
        .init(code: "IDR", symbol: "Rp", decimalDigits: 0),
        .init(code: "PHP", symbol: "₱", decimalDigits: 2),
        .init(code: "VND", symbol: "₫", decimalDigits: 0),
        .init(code: "AUD", symbol: "A$", decimalDigits: 2),
        .init(code: "CAD", symbol: "C$", decimalDigits: 2),
        .init(code: "CHF", symbol: "CHF", decimalDigits: 2),
        .init(code: "NZD", symbol: "NZ$", decimalDigits: 2),
        .init(code: "AED", symbol: "د.إ", decimalDigits: 2)
    ]

    static func supportedCode(matching value: String?) -> String {
        let normalized = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        return common.contains { $0.code == normalized } ? normalized : defaultCode
    }
}
