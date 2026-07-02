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
            throw ExchangeRateError.invalidCurrency
        }
        if base == quote {
            return Quote(
                baseCurrencyCode: base,
                quoteCurrencyCode: quote,
                date: dateString(date),
                rate: 1,
                provider: "identity"
            )
        }

        guard var components = URLComponents(string: endpointURLString) else {
            throw ExchangeRateError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "base", value: base),
            URLQueryItem(name: "quote", value: quote),
            URLQueryItem(name: "date", value: dateString(date))
        ]
        guard let url = components.url else {
            throw ExchangeRateError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ExchangeRateError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                commonAPIExchangeRateLogger.warning("[CommonAPI] exchange rate failed: \(body.error.code) \(body.error.message)")
            }
            throw ExchangeRateError.httpFailure(http.statusCode)
        }

        let body = try JSONDecoder().decode(ResponseBody.self, from: data)
        return Quote(
            baseCurrencyCode: body.baseCurrencyCode,
            quoteCurrencyCode: body.quoteCurrencyCode,
            date: body.date,
            rate: body.rate,
            provider: body.provider
        )
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
