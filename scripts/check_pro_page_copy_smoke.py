#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"
SUPPORT_VIEW = APP / "Features" / "Settings" / "SupportAutoLedgerView.swift"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def extract_property_array(source: str, property_name: str) -> str:
    match = re.search(
        rf"private var {property_name}: \[Pro(?:Feature|Roadmap)Item\] \{{(?P<body>.*?)\n    \}}",
        source,
        re.S,
    )
    return match.group("body") if match else ""


def main() -> int:
    failures: list[str] = []
    support = SUPPORT_VIEW.read_text(encoding="utf-8")
    feature_items = extract_property_array(support, "featureItems")
    roadmap_items = extract_property_array(support, "roadmapItems")

    if not feature_items:
        failures.append("SupportAutoLedgerView missing featureItems body")
    if not roadmap_items:
        failures.append("SupportAutoLedgerView missing roadmapItems body")

    for item_id in ["email", "cloudInbox", "batch", "dedupe", "search", "alerts", "export", "rules"]:
        require(feature_items, f'id: "{item_id}"', "featureItems", failures)

    for title_key in [
        "pro.feature.search.title",
        "pro.feature.alerts.title",
        "pro.feature.export.title",
        "pro.feature.rules.title",
    ]:
        require(feature_items, f'title: "{title_key}"', "featureItems", failures)
        if title_key in roadmap_items:
            failures.append(f"roadmapItems should not still use implemented feature key: {title_key}")

    for title_key in [
        "pro.roadmap.cloud_assist.title",
        "pro.roadmap.review_queue.title",
        "pro.roadmap.share_templates.title",
        "pro.roadmap.cross_device.title",
    ]:
        require(roadmap_items, f'title: "{title_key}"', "roadmapItems", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        if '"pro.roadmap.item_badge" = "1.6.0";' in strings:
            failures.append(f"{locale} roadmap badge still exposes internal version number")
        for key in [
            "pro.description",
            "pro.hero.subtitle",
            "pro.features.title",
            "pro.roadmap.subtitle",
            "pro.roadmap.item_badge",
            "pro.roadmap.cloud_assist.title",
            "pro.roadmap.cloud_assist.body",
            "pro.roadmap.review_queue.title",
            "pro.roadmap.review_queue.body",
            "pro.roadmap.share_templates.title",
            "pro.roadmap.share_templates.body",
            "pro.roadmap.cross_device.title",
            "pro.roadmap.cross_device.body",
            "pro.active.body",
            "pro.status.active.body",
            "pro.product.monthly.description_format",
            "pro.product.yearly.description_format",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Pro page copy smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Pro page copy smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
