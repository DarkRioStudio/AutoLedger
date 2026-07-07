import Foundation
import OSLog

nonisolated private let commonAPIHotelWeatherLogger = Logger(
    subsystem: "top.darkrio326.AutoLedger",
    category: "CommonAPIHotelWeatherService"
)

enum CommonAPIHotelWeatherService {
    struct HotelStayWeatherDay: Decodable, Equatable, Sendable {
        let date: String
        let tempMin: Double?
        let tempMax: Double?
        let precipitationAmount: Double?
        let snowfallAmount: Double?
        let description: String
        let icon: String
    }

    struct HotelStayWeatherSummary: Decodable, Equatable, Sendable {
        struct Location: Decodable, Equatable, Sendable {
            let lat: Double
            let lon: Double
        }

        let location: Location
        let checkIn: String
        let checkOut: String
        let timezone: String
        let units: String
        let days: [HotelStayWeatherDay]
        let unavailableReason: String?
    }

    struct Response: Decodable, Equatable, Sendable {
        let provider: String
        let cached: Bool
        let data: HotelStayWeatherSummary
        let privacy: String
    }

    nonisolated private struct ErrorBody: Decodable {
        let error: APIErrorBody
    }

    nonisolated private struct APIErrorBody: Decodable {
        let code: String
        let message: String
    }

    nonisolated private static let endpointURLString = "https://api.darkrio326.top/v1/weather/hotel-stay-summary"

    nonisolated static func summary(
        latitude: Double,
        longitude: Double,
        checkIn: String,
        checkOut: String,
        locale: String,
        timezone: String,
        units: String = "metric"
    ) async throws -> Response {
        guard var components = URLComponents(string: endpointURLString) else {
            throw HotelWeatherError.invalidEndpoint
        }
        components.queryItems = [
            URLQueryItem(name: "lat", value: formattedCoordinate(latitude)),
            URLQueryItem(name: "lon", value: formattedCoordinate(longitude)),
            URLQueryItem(name: "checkIn", value: checkIn),
            URLQueryItem(name: "checkOut", value: checkOut),
            URLQueryItem(name: "locale", value: locale),
            URLQueryItem(name: "timezone", value: timezone),
            URLQueryItem(name: "units", value: units)
        ]
        guard let url = components.url else {
            throw HotelWeatherError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw HotelWeatherError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                commonAPIHotelWeatherLogger.warning("[CommonAPI] hotel weather failed: \(body.error.code) \(body.error.message)")
                throw HotelWeatherError.apiFailure(code: body.error.code)
            }
            throw HotelWeatherError.httpFailure(http.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    nonisolated private static func formattedCoordinate(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    enum HotelWeatherError: LocalizedError {
        case invalidEndpoint
        case invalidResponse
        case httpFailure(Int)
        case apiFailure(code: String)

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Invalid Common API hotel weather endpoint"
            case .invalidResponse:
                return "Invalid Common API hotel weather response"
            case .httpFailure(let statusCode):
                return "Common API hotel weather returned HTTP \(statusCode)"
            case .apiFailure(let code):
                return "Common API hotel weather failed: \(code)"
            }
        }
    }
}
