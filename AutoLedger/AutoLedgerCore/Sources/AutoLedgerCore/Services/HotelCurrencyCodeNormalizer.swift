import Foundation

public enum HotelCurrencyCodeNormalizer: Sendable {
    private static let supportedCodes: Set<String> = [
        "CNY", "USD", "JPY", "EUR", "GBP", "HKD", "MOP", "TWD", "SGD", "KRW",
        "THB", "MYR", "AUD", "CAD"
    ]

    public static func normalizedCode(_ value: String?, context: String? = nil) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let uppercased = trimmed.uppercased()
        if supportedCodes.contains(uppercased) {
            return uppercased
        }

        let compact = uppercased
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ".", with: "")

        if supportedCodes.contains(compact) {
            return compact
        }

        let searchable = [trimmed, compact, context ?? ""]
            .joined(separator: " ")
            .uppercased()

        let directAliases: [(String, String)] = [
            ("RMB", "CNY"),
            ("CN¥", "CNY"),
            ("CNY¥", "CNY"),
            ("人民币", "CNY"),
            ("人民幣", "CNY"),
            ("JP¥", "JPY"),
            ("JPY¥", "JPY"),
            ("YEN", "JPY"),
            ("円", "JPY"),
            ("日元", "JPY"),
            ("日圓", "JPY"),
            ("US$", "USD"),
            ("USD$", "USD"),
            ("US DOLLAR", "USD"),
            ("U.S. DOLLAR", "USD"),
            ("UNITED STATES DOLLAR", "USD"),
            ("美元", "USD"),
            ("HK$", "HKD"),
            ("HONG KONG DOLLAR", "HKD"),
            ("港币", "HKD"),
            ("港幣", "HKD"),
            ("MOP$", "MOP"),
            ("MACAU PATACA", "MOP"),
            ("MACANESE PATACA", "MOP"),
            ("PATACA", "MOP"),
            ("澳门元", "MOP"),
            ("澳門元", "MOP"),
            ("NT$", "TWD"),
            ("NEW TAIWAN DOLLAR", "TWD"),
            ("新台币", "TWD"),
            ("新台幣", "TWD"),
            ("台币", "TWD"),
            ("台幣", "TWD"),
            ("S$", "SGD"),
            ("SINGAPORE DOLLAR", "SGD"),
            ("新加坡元", "SGD"),
            ("₩", "KRW"),
            ("KOREAN WON", "KRW"),
            ("韩元", "KRW"),
            ("韓元", "KRW"),
            ("฿", "THB"),
            ("THAI BAHT", "THB"),
            ("泰铢", "THB"),
            ("泰銖", "THB"),
            ("RM", "MYR"),
            ("MALAYSIAN RINGGIT", "MYR"),
            ("马币", "MYR"),
            ("馬幣", "MYR"),
            ("A$", "AUD"),
            ("AU$", "AUD"),
            ("AUSTRALIAN DOLLAR", "AUD"),
            ("澳元", "AUD"),
            ("C$", "CAD"),
            ("CA$", "CAD"),
            ("CANADIAN DOLLAR", "CAD"),
            ("加元", "CAD"),
            ("€", "EUR"),
            ("EURO", "EUR"),
            ("欧元", "EUR"),
            ("歐元", "EUR"),
            ("£", "GBP"),
            ("POUND", "GBP"),
            ("英镑", "GBP"),
            ("英鎊", "GBP")
        ]

        if let match = directAliases.first(where: { searchable.contains($0.0.uppercased()) }) {
            return match.1
        }

        let exactAliases: [String: String] = [
            "元": "CNY",
            "圆": "CNY",
            "圓": "CNY",
            "DOLLAR": "USD",
            "DOLLARS": "USD",
            "POUND": "GBP",
            "POUNDS": "GBP"
        ]
        if let match = exactAliases[uppercased] ?? exactAliases[trimmed] {
            return match
        }

        if trimmed == "¥" || trimmed == "￥" {
            return contextSuggestsJapan(context) ? "JPY" : "CNY"
        }

        if trimmed == "$" {
            if contextContains(context, terms: ["HONG KONG", "香港"]) { return "HKD" }
            if contextContains(context, terms: ["TAIWAN", "台灣", "台湾"]) { return "TWD" }
            if contextContains(context, terms: ["SINGAPORE", "新加坡"]) { return "SGD" }
            return "USD"
        }

        return nil
    }

    private static func contextSuggestsJapan(_ context: String?) -> Bool {
        contextContains(context, terms: [
            "JAPAN", "TOKYO", "OSAKA", "KYOTO", "NAGOYA", "SAPPORO", "FUKUOKA",
            "日本", "東京", "大阪", "京都", "名古屋", "札幌", "福岡", "円", "日元", "日圓"
        ])
    }

    private static func contextContains(_ context: String?, terms: [String]) -> Bool {
        let value = context?.uppercased() ?? ""
        return terms.contains { value.contains($0.uppercased()) }
    }
}
