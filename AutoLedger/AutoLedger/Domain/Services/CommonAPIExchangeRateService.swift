import Foundation
import OSLog

nonisolated private let commonAPIExchangeRateLogger = Logger(
    subsystem: "top.darkrio326.AutoLedger",
    category: "CommonAPIExchangeRateService"
)

enum CommonAPIExchangeRateService {
    struct Quote: Sendable {
        let baseCurrencyCode: String
        let quoteCurrencyCode: String
        let date: String
        let rate: Double
        let provider: String
    }

    nonisolated private struct ResponseBody: Decodable {
        let provider: String
        let date: String
        let baseCurrencyCode: String
        let quoteCurrencyCode: String
        let rate: Double
    }

    nonisolated private struct CachedQuote: Codable {
        let baseCurrencyCode: String
        let quoteCurrencyCode: String
        let requestedDate: String
        let rateDate: String
        let rate: Double
        let provider: String
        let fetchedAt: Date
        let expiresAt: Date
    }

    nonisolated private struct ErrorBody: Decodable {
        let error: APIErrorBody
    }

    nonisolated private struct APIErrorBody: Decodable {
        let code: String
        let message: String
    }

    nonisolated private static let endpointURLString = "https://api.darkrio326.top/v1/exchange-rates/rate"

    nonisolated static func quote(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        date: Date
    ) async throws -> Quote {
        let base = normalizedCurrencyCode(baseCurrencyCode)
        let quote = normalizedCurrencyCode(quoteCurrencyCode)
        guard base.count == 3, quote.count == 3 else {
            CommonAPIAnalyticsService.trackCurrencyLookup(
                lookupContext: "transaction_conversion",
                hasForeignCurrency: false,
                status: "failed",
                errorCode: "invalid_currency",
                cacheStatus: "bypass"
            )
            throw ExchangeRateError.invalidCurrency
        }
        if base == quote {
            CommonAPIAnalyticsService.trackCurrencyLookup(
                lookupContext: "transaction_conversion",
                hasForeignCurrency: false,
                status: "success",
                errorCode: "none",
                cacheStatus: "identity"
            )
            return Quote(
                baseCurrencyCode: base,
                quoteCurrencyCode: quote,
                date: dateString(date),
                rate: 1,
                provider: "identity"
            )
        }
        let requestedDate = dateString(date)

        if let cached = cachedQuote(
            baseCurrencyCode: base,
            quoteCurrencyCode: quote,
            requestedDate: requestedDate,
            allowExpired: false
        ) {
            commonAPIExchangeRateLogger.info("[CommonAPI] exchange rate cache hit: \(base)->\(quote) date=\(requestedDate)")
            CommonAPIAnalyticsService.trackCurrencyLookup(
                lookupContext: "transaction_conversion",
                hasForeignCurrency: true,
                status: "success",
                errorCode: "none",
                cacheStatus: "hit"
            )
            return cached
        }

        guard var components = URLComponents(string: endpointURLString) else {
            throw ExchangeRateError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "base", value: base),
            URLQueryItem(name: "quote", value: quote),
            URLQueryItem(name: "date", value: requestedDate)
        ]
        guard let url = components.url else {
            throw ExchangeRateError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8

        let startedAt = Date()
        var didTrackFailure = false
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                didTrackFailure = true
                CommonAPIAnalyticsService.trackCommonAPIRequest(
                    endpointGroup: "exchange_rates",
                    httpStatusBucket: "invalid_response",
                    startedAt: startedAt,
                    errorCode: "invalid_response",
                    cacheStatus: "miss"
                )
                CommonAPIAnalyticsService.trackCurrencyLookup(
                    lookupContext: "transaction_conversion",
                    hasForeignCurrency: true,
                    status: "failed",
                    startedAt: startedAt,
                    errorCode: "invalid_response",
                    cacheStatus: "miss"
                )
                throw ExchangeRateError.invalidResponse
            }
            guard (200...299).contains(http.statusCode) else {
                let errorCode: String
                if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                    commonAPIExchangeRateLogger.warning("[CommonAPI] exchange rate failed: \(body.error.code) \(body.error.message)")
                    errorCode = body.error.code
                } else {
                    errorCode = "http_\(http.statusCode)"
                }
                didTrackFailure = true
                CommonAPIAnalyticsService.trackCommonAPIRequest(
                    endpointGroup: "exchange_rates",
                    httpStatusBucket: CommonAPIAnalyticsService.httpStatusBucket(http.statusCode),
                    startedAt: startedAt,
                    errorCode: errorCode,
                    cacheStatus: "miss"
                )
                CommonAPIAnalyticsService.trackCurrencyLookup(
                    lookupContext: "transaction_conversion",
                    hasForeignCurrency: true,
                    status: "failed",
                    startedAt: startedAt,
                    errorCode: errorCode,
                    cacheStatus: "miss"
                )
                throw ExchangeRateError.httpFailure(http.statusCode)
            }

            let body = try JSONDecoder().decode(ResponseBody.self, from: data)
            let result = Quote(
                baseCurrencyCode: body.baseCurrencyCode,
                quoteCurrencyCode: body.quoteCurrencyCode,
                date: body.date,
                rate: body.rate,
                provider: body.provider
            )
            writeCachedQuote(result, requestedDate: requestedDate)
            CommonAPIAnalyticsService.trackCommonAPIRequest(
                endpointGroup: "exchange_rates",
                httpStatusBucket: CommonAPIAnalyticsService.httpStatusBucket(http.statusCode),
                startedAt: startedAt,
                errorCode: "none",
                cacheStatus: "miss"
            )
            CommonAPIAnalyticsService.trackCurrencyLookup(
                lookupContext: "transaction_conversion",
                hasForeignCurrency: true,
                status: "success",
                startedAt: startedAt,
                errorCode: "none",
                cacheStatus: "miss"
            )
            return result
        } catch {
            if let cached = cachedQuote(
                baseCurrencyCode: base,
                quoteCurrencyCode: quote,
                requestedDate: requestedDate,
                allowExpired: true
            ) {
                commonAPIExchangeRateLogger.warning("[CommonAPI] exchange rate request failed, using cached rate: \(base)->\(quote) date=\(requestedDate)")
                CommonAPIAnalyticsService.trackCurrencyLookup(
                    lookupContext: "transaction_conversion",
                    hasForeignCurrency: true,
                    status: "success",
                    startedAt: startedAt,
                    errorCode: CommonAPIAnalyticsService.errorCode(for: error),
                    cacheStatus: "stale"
                )
                return cached
            }
            if !didTrackFailure {
                CommonAPIAnalyticsService.trackCommonAPIRequest(
                    endpointGroup: "exchange_rates",
                    httpStatusBucket: "network_error",
                    startedAt: startedAt,
                    errorCode: CommonAPIAnalyticsService.errorCode(for: error),
                    cacheStatus: "miss"
                )
                CommonAPIAnalyticsService.trackCurrencyLookup(
                    lookupContext: "transaction_conversion",
                    hasForeignCurrency: true,
                    status: "failed",
                    startedAt: startedAt,
                    errorCode: CommonAPIAnalyticsService.errorCode(for: error),
                    cacheStatus: "miss"
                )
            }
            throw error
        }
    }

    nonisolated private static func normalizedCurrencyCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    nonisolated private static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    nonisolated private static func cachedQuote(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        requestedDate: String,
        allowExpired: Bool
    ) -> Quote? {
        guard let url = cacheFileURL(
            baseCurrencyCode: baseCurrencyCode,
            quoteCurrencyCode: quoteCurrencyCode,
            requestedDate: requestedDate
        ),
              let data = try? Data(contentsOf: url) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let entry = try? decoder.decode(CachedQuote.self, from: data),
              entry.baseCurrencyCode == baseCurrencyCode,
              entry.quoteCurrencyCode == quoteCurrencyCode,
              entry.requestedDate == requestedDate,
              entry.rate > 0 else {
            return nil
        }

        if !allowExpired && entry.expiresAt <= Date() {
            return nil
        }

        return Quote(
            baseCurrencyCode: entry.baseCurrencyCode,
            quoteCurrencyCode: entry.quoteCurrencyCode,
            date: entry.rateDate,
            rate: entry.rate,
            provider: entry.provider
        )
    }

    nonisolated private static func writeCachedQuote(_ quote: Quote, requestedDate: String) {
        guard let directoryURL = cacheDirectoryURL(),
              let fileURL = cacheFileURL(
                baseCurrencyCode: quote.baseCurrencyCode,
                quoteCurrencyCode: quote.quoteCurrencyCode,
                requestedDate: requestedDate
              ) else {
            return
        }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            let now = Date()
            let entry = CachedQuote(
                baseCurrencyCode: quote.baseCurrencyCode,
                quoteCurrencyCode: quote.quoteCurrencyCode,
                requestedDate: requestedDate,
                rateDate: quote.date,
                rate: quote.rate,
                provider: quote.provider,
                fetchedAt: now,
                expiresAt: cacheExpirationDate(for: requestedDate, now: now)
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entry)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            commonAPIExchangeRateLogger.debug("[CommonAPI] exchange rate cache write skipped: \(error.localizedDescription)")
        }
    }

    nonisolated private static func cacheExpirationDate(for requestedDate: String, now: Date) -> Date {
        let today = dateString(now)
        let ttl: TimeInterval = requestedDate == today ? 60 * 60 : 30 * 24 * 60 * 60
        return now.addingTimeInterval(ttl)
    }

    nonisolated private static func cacheDirectoryURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("CommonAPI", isDirectory: true)
            .appendingPathComponent("ExchangeRates", isDirectory: true)
    }

    nonisolated private static func cacheFileURL(
        baseCurrencyCode: String,
        quoteCurrencyCode: String,
        requestedDate: String
    ) -> URL? {
        cacheDirectoryURL()?
            .appendingPathComponent("\(baseCurrencyCode)_\(quoteCurrencyCode)_\(requestedDate).json", isDirectory: false)
    }

    enum ExchangeRateError: LocalizedError {
        case invalidCurrency
        case invalidEndpoint
        case invalidResponse
        case httpFailure(Int)

        var errorDescription: String? {
            switch self {
            case .invalidCurrency:
                return "Invalid currency code."
            case .invalidEndpoint:
                return "Invalid Common API exchange-rate endpoint."
            case .invalidResponse:
                return "Invalid Common API exchange-rate response."
            case .httpFailure(let statusCode):
                return "Common API exchange-rate request failed: HTTP \(statusCode)."
            }
        }
    }
}
