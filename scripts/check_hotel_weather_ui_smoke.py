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
    memory_path = ROOT / "AutoLedger" / "AutoLedgerCore" / "Sources" / "AutoLedgerCore" / "Services" / "HotelJourneyMemory.swift"

    service = service_path.read_text(encoding="utf-8") if service_path.exists() else ""
    detail = detail_path.read_text(encoding="utf-8")
    catalog = catalog_path.read_text(encoding="utf-8")
    memory = memory_path.read_text(encoding="utf-8") if memory_path.exists() else ""

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
        "hotelJourneyMemoryCard",
        "journeyMemoryInput",
        "HotelJourneyMemoryClient.generate",
        "hotel_stay.detail.memory.title",
        "hotelShareCardData(reviewText: journeyMemoryDraft)",
    ]:
        require(detail, snippet, "HotelStayArchiveView.swift", failures)

    for snippet in [
        "enum HotelJourneyMemoryCodec",
        "struct HotelJourneyMemoryInput",
        "conditionDescription",
        "Check-out is exclusive",
    ]:
        require(memory, snippet, "HotelJourneyMemory.swift", failures)

    for forbidden in [
        "roomNumber",
        "confirmationNumber",
        "paymentMethod",
        "rawText",
        "sourcePDF",
        "sourcePDFData",
    ]:
        if forbidden in memory:
            failures.append(f"HotelJourneyMemory.swift should not reference sensitive field: {forbidden}")

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
            "hotel_stay.detail.memory.title",
            "hotel_stay.detail.memory.subtitle",
            "hotel_stay.detail.memory.privacy_note",
            "hotel_stay.detail.memory.share_action",
            "hotel_stay.detail.memory.accessibility_label",
            "hotel_stay.detail.memory.generate",
            "hotel_stay.detail.memory.regenerate",
            "hotel_stay.detail.memory.generating",
            "hotel_stay.detail.memory.configure",
            "hotel_stay.detail.memory.failed",
            "hotel_stay.detail.memory.draft",
            "hotel_stay.detail.weather.condition_unavailable",
            "hotel_stay.detail.weather.value_unavailable",
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
