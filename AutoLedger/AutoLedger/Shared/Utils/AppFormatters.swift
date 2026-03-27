import Foundation

enum AppFormatters {
    static let calendar = Calendar(identifier: .gregorian)

    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CNY"
        formatter.currencySymbol = "¥"
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter
    }()

    static func currency(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount)) ?? "¥0.00"
    }

    static func shortDateTime(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func month(_ date: Date) -> String {
        monthFormatter.string(from: date)
    }

    static func parseFlexibleDate(_ rawValue: String) -> Date? {
        let normalized = rawValue
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: "日", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let formats = [
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
