import Foundation

public struct ReceiptCurrencyDetection: Equatable, Sendable {
    public let currencyCode: String
    public let evidence: String

    public init(currencyCode: String, evidence: String) {
        self.currencyCode = currencyCode
        self.evidence = evidence
    }
}

public enum ReceiptCurrencyDetector {
    private struct Rule {
        let code: String
        let evidences: [String]
    }

    private static let strongRules: [Rule] = [
        Rule(code: "CNY", evidences: ["CNY", "RMB", "CN¥", "CN￥", "人民币"]),
        Rule(code: "HKD", evidences: ["HKD", "HK$", "港币", "港幣"]),
        Rule(code: "MOP", evidences: ["MOP", "MOP$", "澳门元", "澳門元"]),
        Rule(code: "TWD", evidences: ["TWD", "NT$", "新台币", "新台幣"]),
        Rule(code: "JPY", evidences: ["JPY", "JP¥", "JP￥", "日本円", "日元", "円"]),
        Rule(code: "KRW", evidences: ["KRW", "₩", "韩元", "韓元", "원"]),
        Rule(code: "USD", evidences: ["USD", "US$", "美元"]),
        Rule(code: "SGD", evidences: ["SGD", "S$", "新加坡元"]),
        Rule(code: "AUD", evidences: ["AUD", "A$", "澳元"]),
        Rule(code: "CAD", evidences: ["CAD", "C$", "加元"]),
        Rule(code: "NZD", evidences: ["NZD", "NZ$", "纽元", "紐元"]),
        Rule(code: "EUR", evidences: ["EUR", "€", "欧元", "歐元"]),
        Rule(code: "GBP", evidences: ["GBP", "£", "英镑", "英鎊"]),
        Rule(code: "CHF", evidences: ["CHF", "瑞郎"]),
        Rule(code: "THB", evidences: ["THB", "฿", "泰铢", "泰銖"]),
        Rule(code: "MYR", evidences: ["MYR", "RM", "马币", "馬幣"]),
        Rule(code: "IDR", evidences: ["IDR", "RP", "印尼盾"]),
        Rule(code: "PHP", evidences: ["PHP", "₱", "菲律宾比索", "菲律賓比索"]),
        Rule(code: "VND", evidences: ["VND", "₫", "越南盾"]),
        Rule(code: "AED", evidences: ["AED", "د.إ", "迪拉姆"])
    ]

    public static func detectCode(in text: String) -> String? {
        detect(in: text)?.currencyCode
    }

    public static func detect(in text: String) -> ReceiptCurrencyDetection? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let uppercased = trimmed.uppercased()

        for rule in strongRules {
            if let evidence = rule.evidences.first(where: { containsEvidence($0, in: uppercased) }) {
                return ReceiptCurrencyDetection(currencyCode: rule.code, evidence: evidence)
            }
        }

        if trimmed.contains("¥") || trimmed.contains("￥") {
            if containsEvidence("円", in: uppercased) {
                return ReceiptCurrencyDetection(currencyCode: "JPY", evidence: "¥+円")
            }
            return ReceiptCurrencyDetection(currencyCode: "CNY", evidence: "¥")
        }

        if trimmed.contains("$") {
            return ReceiptCurrencyDetection(currencyCode: "USD", evidence: "$")
        }

        return nil
    }

    private static func containsEvidence(_ evidence: String, in uppercasedText: String) -> Bool {
        let normalizedEvidence = evidence.uppercased()
        guard normalizedEvidence.unicodeScalars.allSatisfy({ scalar in
            (65...90).contains(Int(scalar.value)) || (48...57).contains(Int(scalar.value))
        }) else {
            return uppercasedText.contains(normalizedEvidence)
        }

        let pattern = #"(?<![A-Z0-9])"# + NSRegularExpression.escapedPattern(for: normalizedEvidence) + #"(?![A-Z0-9])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return uppercasedText.contains(normalizedEvidence)
        }
        let range = NSRange(uppercasedText.startIndex..<uppercasedText.endIndex, in: uppercasedText)
        return regex.firstMatch(in: uppercasedText, range: range) != nil
    }
}
