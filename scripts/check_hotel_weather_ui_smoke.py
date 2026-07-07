#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []
    service_path = APP / "Domain" / "Services" / "CommonAPIHotelWeatherService.swift"
    detail_path = APP / "Features" / "Hotel" / "HotelStayArchiveView.swift"
    catalog_path = APP / "Features" / "Hotel" / "HotelStayLocationCatalog.swift"

    service = service_path.read_text(encoding="utf-8") if service_path.exists() else ""
    detail = detail_path.read_text(encoding="utf-8")
    catalog = catalog_path.read_text(encoding="utf-8")

    for snippet in [
        "enum CommonAPIHotelWeatherService",
        "/v1/weather/hotel-stay-summary",
        "HotelStayWeatherSummary",
        "URLQueryItem(name: \"lat\"",
        "URLQueryItem(name: \"lon\"",
        "URLQueryItem(name: \"checkIn\"",
        "URLQueryItem(name: \"checkOut\"",
        "URLQueryItem(name: \"locale\"",
        "URLQueryItem(name: \"timezone\"",
    ]:
        require(service, snippet, "CommonAPIHotelWeatherService.swift", failures)

    for snippet in [
        "@State private var weatherSummaryState",
        "CommonAPIHotelWeatherService",
        "hotelWeatherCard",
        "hotel_stay.detail.weather.title",
        "hotel_stay.detail.weather.unavailable",
        ".task(id: weatherTaskID)",
    ]:
        require(detail, snippet, "HotelStayArchiveView.swift", failures)

    for snippet in [
        "struct WeatherLocation",
        "let latitude = matchedCity.latitude",
        "let longitude = matchedCity.longitude",
        "let timezone = matchedCity.timezone",
        "weatherLocation",
    ]:
        require(catalog, snippet, "HotelStayLocationCatalog.swift", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "hotel_stay.detail.weather.title",
            "hotel_stay.detail.weather.subtitle_format",
            "hotel_stay.detail.weather.loading",
            "hotel_stay.detail.weather.unavailable",
            "hotel_stay.detail.weather.day_format",
            "hotel_stay.detail.weather.temperature_format",
            "hotel_stay.detail.weather.precipitation_format",
            "hotel_stay.detail.weather.provider_format",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Hotel weather UI smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Hotel weather UI smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
