import Foundation

enum HotelStayJourneyMemoryComposer {
    typealias Localizer = (_ key: String, _ fallback: String?) -> String
    typealias TemperatureFormatter = (Double) -> String

    static func memoryText(
        hotelName: String,
        locationText: String,
        dateRangeText: String,
        weatherDays: [CommonAPIHotelWeatherService.HotelStayWeatherDay],
        localized: Localizer,
        temperatureFormatter: TemperatureFormatter
    ) -> String {
        let hotel = trimmed(hotelName) ?? localized("hotel_stay.detail.memory.default_hotel", nil)
        let location = trimmed(locationText) ?? localized("hotel_stay.detail.memory.default_location", nil)
        let dateRange = trimmed(dateRangeText) ?? localized("hotel_stay.detail.memory.default_dates", nil)
        let weather = weatherSummary(from: weatherDays, localized: localized)
        let temperature = temperatureRange(from: weatherDays, localized: localized, formatter: temperatureFormatter)

        if let weather, let temperature {
            return String(
                format: localized("hotel_stay.detail.memory.weather_format", nil),
                hotel,
                location,
                dateRange,
                weather,
                temperature
            )
        }

        if let weather {
            return String(
                format: localized("hotel_stay.detail.memory.weather_only_format", nil),
                hotel,
                location,
                dateRange,
                weather
            )
        }

        return String(
            format: localized("hotel_stay.detail.memory.simple_format", nil),
            hotel,
            location,
            dateRange
        )
    }

    private static func weatherSummary(
        from days: [CommonAPIHotelWeatherService.HotelStayWeatherDay],
        localized: Localizer
    ) -> String? {
        let descriptions = days
            .map(\.description)
            .compactMap(trimmed)
            .reduce(into: [String]()) { result, description in
                if !result.contains(where: { $0.caseInsensitiveCompare(description) == .orderedSame }) {
                    result.append(description)
                }
            }
            .prefix(2)

        guard !descriptions.isEmpty else { return nil }
        return descriptions.joined(separator: localized("hotel_stay.detail.memory.weather_separator", nil))
    }

    private static func temperatureRange(
        from days: [CommonAPIHotelWeatherService.HotelStayWeatherDay],
        localized: Localizer,
        formatter: TemperatureFormatter
    ) -> String? {
        let lows = days.compactMap(\.tempMin)
        let highs = days.compactMap(\.tempMax)
        guard let low = lows.min(), let high = highs.max() else { return nil }
        return String(
            format: localized("hotel_stay.detail.memory.temperature_range_format", nil),
            formatter(low),
            formatter(high)
        )
    }

    nonisolated private static func trimmed(_ value: String?) -> String? {
        guard let text = value?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        return text
    }
}
