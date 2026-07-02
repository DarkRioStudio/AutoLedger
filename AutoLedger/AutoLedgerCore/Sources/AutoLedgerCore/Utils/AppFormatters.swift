import Foundation

public enum AppFormatters: Sendable {
    public static let calendar = Calendar(identifier: .gregorian)

    nonisolated(unsafe) private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    nonisolated(unsafe) private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    nonisolated(unsafe) private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    nonisolated(unsafe) private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    public static func currency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }

    public static func currency(_ amount: Double, code: String?) -> String {
        let normalizedCode = code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        guard !normalizedCode.isEmpty else {
            return currency(amount)
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = normalizedCode
        formatter.maximumFractionDigits = currencyMinorDigits(normalizedCode)
        formatter.minimumFractionDigits = currencyMinorDigits(normalizedCode)
        return formatter.string(from: NSNumber(value: amount)) ?? "\(normalizedCode) \(amount)"
    }

    public static func shortDateTime(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    public static func month(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    public static func exportDateTime(_ date: Date) -> String {
        exportDateFormatter.string(from: date)
    }

    private static func currencyMinorDigits(_ code: String) -> Int {
        switch code.uppercased() {
        case "JPY", "KRW", "VND", "IDR":
            return 0
        default:
            return 2
        }
    }

    public static func parseFlexibleDate(_ rawValue: String) -> Date? {
        let normalized = rawValue
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: #"日\s*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "/", with: "-")
            // OCR 可能产出全角空格、不间断空格等 Unicode 空白，统一替换为 ASCII 空格
            .replacingOccurrences(of: #"[\u00A0\u2000-\u200B\u3000\uFEFF]"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let formats = [
            "yyyy-M-d HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-M-d HH:mm",
            "yyyy-MM-dd HH:mm",
            "yyyy-M-d",
            "yyyy-MM-dd"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }
}
