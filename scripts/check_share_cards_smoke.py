#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"
SHARE_CARDS = APP / "Features" / "ShareCards"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []
    report = (APP / "Features" / "Report" / "ReportView.swift").read_text(encoding="utf-8")
    hotel = (APP / "Features" / "Hotel" / "HotelStayArchiveView.swift").read_text(encoding="utf-8")
    share_files = {
        path.name: path.read_text(encoding="utf-8")
        for path in sorted(SHARE_CARDS.glob("*.swift"))
    }
    share_text = "\n".join(share_files.values())

    for expected in [
        "MonthlySummaryShareCardView.swift",
        "HotelStayShareCardView.swift",
        "ShareCardExportService.swift",
        "ShareCardPreviewSheet.swift",
    ]:
        if expected not in share_files:
            failures.append(f"ShareCards missing file: {expected}")

    require(report, "monthPickerMenu(snapshot)", "ReportView", failures)
    require(report, "toolbarShareButton(snapshot)", "ReportView", failures)
    require(report, "ShareCardPreviewSheet(mode: mode)", "ReportView", failures)
    require(report, "monthlyShareCardData(from:", "ReportView", failures)
    require(hotel, "shareStayCardSection", "HotelStayDetailView", failures)
    require(hotel, "hotelShareCardData(", "HotelStayDetailView", failures)
    require(share_text, "ImageRenderer", "ShareCardExportService", failures)
    require(share_text, "FileManager.default.temporaryDirectory", "ShareCardExportService", failures)
    require(share_text, "ActivityShareSheet(activityItems:", "ShareCardPreviewSheet", failures)
    require(share_text, "MonthlySummaryShareCardView", "ShareCards", failures)
    require(share_text, "HotelStayShareCardView", "ShareCards", failures)

    forbidden_in_share_cards = [
        "roomNumber",
        "confirmationNumber",
        "paymentMethod",
        "rawText",
        "sourcePDF",
        "sourcePDFData",
    ]
    for token in forbidden_in_share_cards:
        if token in share_text:
            failures.append(f"ShareCards should not reference sensitive field: {token}")

    hotel_data_match = re.search(
        r"private func hotelShareCardData\([^\)]*\) -> HotelStayShareCardData \{(?P<body>.*?)\n    \}",
        hotel,
        re.S,
    )
    if not hotel_data_match:
        failures.append("HotelStayDetailView missing hotelShareCardData body")
    else:
        body = hotel_data_match.group("body")
        for token in forbidden_in_share_cards:
            if token in body:
                failures.append(f"hotelShareCardData should not reference sensitive field: {token}")

    required_keys = [
        "share_card.monthly.entry_title",
        "share_card.monthly.action",
        "share_card.monthly.preview_title",
        "share_card.monthly.show_amount",
        "share_card.monthly.summary_top_category_format",
        "report.month_picker.current_month",
        "report.month_picker.accessibility_label",
        "share_card.hotel.action",
        "share_card.hotel.preview_title",
        "share_card.hotel.show_price",
        "share_card.hotel.review_editor",
        "share_card.hotel.privacy_note",
        "share_card.amount_hidden",
        "share_card.share_action",
        "share_card.watermark",
        "share_card.error.render_failed",
    ]
    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in required_keys:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Share cards smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Share cards smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
