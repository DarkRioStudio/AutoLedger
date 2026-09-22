import Foundation
import Dispatch

// Compile alongside AppFormatters.swift with swiftc -O; uses synthetic data only.
@main
struct FormatterPerformance {
    static func referenceCurrency(_ amount: Double, code: String, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = AppFormatters.currencyMinorDigits(code)
        formatter.maximumFractionDigits = AppFormatters.currencyMinorDigits(code)
        return formatter.string(from: NSNumber(value: amount))!
    }

    static func referenceDate(_ date: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = AppFormatters.calendar
        formatter.timeZone = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
        return formatter.string(from: date)
    }

    static func measure(_ operation: () -> Int) -> (Double, Int) {
        let start = DispatchTime.now().uptimeNanoseconds
        let checksum = operation()
        return (Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000, checksum)
    }

    static func main() {
        let locales = ["en_US", "en_GB", "en_CA", "en_AU", "en_SG", "zh_CN", "ja_JP", "ko_KR"]
        let codes = ["USD", "GBP", "CAD", "AUD", "SGD", "JPY", "KRW", "CNY"]
        let date = Date(timeIntervalSince1970: 1_783_188_300)
        // Mix regions/currencies concurrently so a shared mutable formatter or
        // an incomplete cache key cannot silently return another caller's format.
        let expected = locales.indices.map { index in
            referenceCurrency(-1234.56, code: codes[index], locale: Locale(identifier: locales[index]))
        }
        let expectedDates = locales.map { referenceDate(date, locale: Locale(identifier: $0)) }
        DispatchQueue.concurrentPerform(iterations: 2_000) { iteration in
            let index = iteration % locales.count
            let locale = Locale(identifier: locales[index])
            precondition(AppFormatters.currency(-1234.56, code: codes[index], locale: locale) == expected[index])
            precondition(AppFormatters.shortDateTime(date, locale: locale) == expectedDates[index])
        }
        // Exercise eviction and currency changes while keeping the locale fixed.
        for code in Locale.commonISOCurrencyCodes {
            let locale = Locale(identifier: "en_US")
            precondition(AppFormatters.currency(0.125, code: code, locale: locale)
                == referenceCurrency(0.125, code: code, locale: locale))
        }
        print("PASS formatter parity, mixed-locale concurrency and eviction")
        let locale = Locale(identifier: "en_US")
        for count in [500, 5_000, 20_000] {
            let baseline = measure {
                var checksum = 0
                for index in 0..<count {
                    // Old row rendered amount/date twice (label + accessibility).
                    for _ in 0..<2 {
                        checksum += referenceCurrency(Double(index) / 100, code: "USD", locale: locale).utf8.count
                        checksum += referenceDate(date.addingTimeInterval(Double(index)), locale: locale).utf8.count
                    }
                }
                return checksum
            }
            let cached = measure {
                var checksum = 0
                for index in 0..<count {
                    let amount = AppFormatters.currency(Double(index) / 100, code: "USD", locale: locale)
                    let dateText = AppFormatters.shortDateTime(date.addingTimeInterval(Double(index)), locale: locale)
                    checksum += 2 * (amount.utf8.count + dateText.utf8.count)
                }
                return checksum
            }
            precondition(baseline.1 == cached.1)
            print(String(format: "rows=%d uncached_ms=%.2f cached_ms=%.2f speedup=%.1fx", count, baseline.0, cached.0, baseline.0 / cached.0))
        }
    }
}
