import Foundation

public enum AppFormatters: Sendable {
    /// Business date calculations remain Gregorian while following the user's current time zone.
    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = .autoupdatingCurrent
        value.timeZone = .autoupdatingCurrent
        return value
    }

    private static let normalizedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public static func currency(
        _ amount: Double,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        currency(amount, code: nil, locale: locale)
    }

    public static func currency(
        _ amount: Double,
        code: String?,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let normalizedCode = resolvedCurrencyCode(code, locale: locale)
        let minorDigits = currencyMinorDigits(normalizedCode)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = normalizedCode
        formatter.maximumFractionDigits = minorDigits
        formatter.minimumFractionDigits = minorDigits
        return formatter.string(from: NSNumber(value: amount)) ?? fallbackCurrencyString(
            amount,
            code: normalizedCode,
            minorDigits: minorDigits,
            locale: locale
        )
    }

    public static func shortDateTime(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        localizedDateString(date, template: "MMMdjm", locale: locale)
    }

    public static func month(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        localizedDateString(date, template: "yMMMM", locale: locale)
    }

    public static func shortMonth(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        localizedDateString(date, template: "MMM", locale: locale)
    }

    public static func shortDate(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        localizedDateString(date, template: "Md", locale: locale)
    }

    public static func time(
        _ date: Date,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        localizedDateString(date, template: "jm", locale: locale)
    }

    public static func exportDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    public static func normalizedDateString(_ rawValue: String) -> String? {
        guard let date = parseFlexibleDate(rawValue) else { return nil }
        return normalizedDateFormatter.string(from: date)
    }

    public static func resolvedCurrencyCode(
        _ code: String?,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let normalized = code?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        if normalized.count == 3,
           normalized.unicodeScalars.allSatisfy(CharacterSet.uppercaseLetters.contains) {
            return normalized
        }
        return locale.currency?.identifier.uppercased() ?? "USD"
    }

    public static func currencyMinorDigits(_ code: String) -> Int {
        switch code.uppercased() {
        case "JPY", "KRW", "VND", "IDR":
            return 0
        default:
            return 2
        }
    }

    private static func localizedDateString(_ date: Date, template: String, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private static func fallbackCurrencyString(
        _ amount: Double,
        code: String,
        minorDigits: Int,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = minorDigits
        formatter.maximumFractionDigits = minorDigits
        let value = formatter.string(from: NSNumber(value: amount)) ?? String(amount)
        return "\(code) \(value)"
    }

    public static func parseFlexibleDate(
        _ rawValue: String,
        locale: Locale = .autoupdatingCurrent
    ) -> Date? {
        let normalized = rawValue
            .replacingOccurrences(of: "年", with: "-")
            .replacingOccurrences(of: "月", with: "-")
            .replacingOccurrences(of: #"日\s*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "/", with: "-")
            // OCR 可能产出全角空格、不间断空格等 Unicode 空白，统一替换为 ASCII 空格
            .replacingOccurrences(of: #"[\u00A0\u2000-\u200B\u3000\uFEFF]"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let monthFirstFormats = [
            "M-d-yy HH:mm:ss",
            "MM-dd-yy HH:mm:ss",
            "M-d-yy HH:mm",
            "MM-dd-yy HH:mm",
            "M-d-yy",
            "MM-dd-yy",
            "M-d-yyyy",
            "MM-dd-yyyy"
        ]
        let dayFirstFormats = [
            "d-M-yy HH:mm:ss",
            "dd-MM-yy HH:mm:ss",
            "d-M-yy HH:mm",
            "dd-MM-yy HH:mm",
            "d-M-yy",
            "dd-MM-yy",
            "d-M-yyyy",
            "dd-MM-yyyy"
        ]
        let yearFirstFormats = [
            "yyyy-M-d HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-M-d HH:mm",
            "yyyy-MM-dd HH:mm",
            "yyyy-M-d",
            "yyyy-MM-dd"
        ]
        let localeOrderedFormats = prefersDayFirstDateOrder(locale: locale)
            ? dayFirstFormats + monthFirstFormats
            : monthFirstFormats + dayFirstFormats
        let formats = yearFirstFormats + localeOrderedFormats

        for dateFormat in formats {
            guard format(dateFormat, isCompatibleWith: normalized) else { continue }
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.isLenient = false
            formatter.dateFormat = dateFormat
            if let date = formatter.date(from: normalized) {
                return date
            }
        }

        return nil
    }

    /// Returns true when a numeric date can validly mean either month/day or day/month.
    /// Year-first dates and dates with a component above 12 are not ambiguous.
    public static func isAmbiguousNumericDate(_ rawValue: String) -> Bool {
        let pattern = #"(?<!\d)(\d{1,2})[\-\/.](\d{1,2})[\-\/.](\d{2}|\d{4})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(rawValue.startIndex..<rawValue.endIndex, in: rawValue)

        for match in regex.matches(in: rawValue, range: range) {
            guard match.numberOfRanges == 4,
                  let firstRange = Range(match.range(at: 1), in: rawValue),
                  let secondRange = Range(match.range(at: 2), in: rawValue),
                  let first = Int(rawValue[firstRange]),
                  let second = Int(rawValue[secondRange])
            else { continue }

            if (1...12).contains(first),
               (1...12).contains(second),
               first != second {
                return true
            }
        }
        return false
    }

    public static func prefersDayFirstDateOrder(locale: Locale) -> Bool {
        guard let pattern = DateFormatter.dateFormat(
            fromTemplate: "Mdy",
            options: 0,
            locale: locale
        ),
        let monthIndex = pattern.firstIndex(of: "M"),
        let dayIndex = pattern.firstIndex(of: "d") else {
            return false
        }
        return dayIndex < monthIndex
    }

    private static func format(_ format: String, isCompatibleWith normalized: String) -> Bool {
        guard let dateToken = normalized.split(separator: " ").first else { return true }
        let parts = dateToken.split(separator: "-")
        guard parts.count == 3 else { return true }

        if format.hasPrefix("yyyy") {
            return parts[0].count == 4
        }
        if format.hasPrefix("yy") {
            return parts[0].count == 2
        }
        if format.contains("-yyyy") {
            return parts[2].count == 4
        }
        if format.contains("-yy") {
            return parts[2].count == 2
        }
        return true
    }
}
