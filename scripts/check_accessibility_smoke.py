#!/usr/bin/env python3
"""Static smoke checks for accessibility, Dynamic Type, and adaptive UI guardrails."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"
WATCH_APP = ROOT / "AutoLedger" / "AutoLedgerWatch Watch App"

REQUIRED_LOCALES = ["zh-Hans", "zh-Hant", "en", "ja"]
STRING_FILE_PATTERN = re.compile(r'^\s*"((?:[^"\\]|\\.)+)"\s*=')

ALLOWED_DYNAMIC_TYPE_PATHS = {
    APP / "Screenshots" / "ScreenshotHostView.swift",
    WATCH_APP / "Screenshots" / "WatchScreenshotHostView.swift",
}

REQUIRED_SNIPPETS = {
    APP / "Features" / "Inbox" / "InboxView.swift": [
        "@Environment(\\.accessibilityReduceMotion)",
        "GridItem(.adaptive",
        "accessibilityLabel",
        "accessibilityHint",
    ],
    APP / "Features" / "Ledger" / "LedgerView.swift": [
        "@Environment(\\.accessibilityReduceMotion)",
        "if reduceMotion",
        "accessibilityLabel(\"\\(transaction.merchant)",
        "accessibilityHint(Text(\"ledger.transaction.edit_hint\"))",
        "prefersPersistentDetail",
    ],
    APP / "Features" / "Report" / "ReportView.swift": [
        "@Environment(\\.accessibilityReduceMotion)",
        "@Environment(\\.accessibilityDifferentiateWithoutColor)",
        "summaryAccessibilityLabel",
        "categoryChartAccessibilityLabel",
        "trendChartAccessibilityLabel",
        "merchantAccessibilityLabel",
    ],
    APP / "Features" / "Hotel" / "HotelStayArchiveView.swift": [
        ".accessibilityElement(children: .combine)",
        ".accessibilityLabel(Text(\"hotel_stay.detail.source_pdf\"))",
        "truncationMode(.tail)",
    ],
    APP / "Features" / "Settings" / "SubscriptionListView.swift": [
        ".accessibilityElement(children: .ignore)",
        "accessibilityValue(summary)",
        "autoLedgerFormChrome",
    ],
    APP / "Shared" / "Components" / "MetricCard.swift": [
        ".lineLimit(1)",
        ".minimumScaleFactor",
        ".allowsTightening(true)",
    ],
    APP / "Shared" / "Constants" / "AppTheme.swift": [
        "autoLedgerReadableContent",
        "autoLedgerListChrome",
        "autoLedgerFormChrome",
    ],
}

REQUIRED_MAIN_APP_ACCESSIBILITY_KEYS = {
    "report.summary.accessibility_format",
    "report.category.accessibility_format",
    "report.trend.accessibility_format",
    "report.merchant.accessibility_format",
    "ledger.transaction.edit_hint",
    "inbox.hero.monthly_expense.accessibility_hint",
    "inbox.hero.top_merchant.accessibility_hint",
    "hotel_stay.detail.source_pdf",
    "transaction_subscription.create_help",
    "support.purchase.accessibility_hint",
}


def swift_files(root: Path) -> list[Path]:
    if not root.exists():
        return []
    return [path for path in root.rglob("*.swift") if ".build" not in path.parts]


def read_keys(path: Path) -> set[str]:
    keys: set[str] = set()
    if not path.exists():
        return keys
    for line in path.read_text(encoding="utf-8").splitlines():
        match = STRING_FILE_PATTERN.match(line)
        if match:
            keys.add(match.group(1))
    return keys


def main() -> int:
    failures: list[str] = []

    for path in swift_files(APP) + swift_files(WATCH_APP):
        text = path.read_text(encoding="utf-8")
        if ".dynamicTypeSize(" in text and path not in ALLOWED_DYNAMIC_TYPE_PATHS:
            failures.append(
                f"{path.relative_to(ROOT)} locks Dynamic Type outside screenshot mode"
            )
        if ".fixedSize(horizontal: true" in text:
            failures.append(
                f"{path.relative_to(ROOT)} uses fixed horizontal text sizing"
            )

    for path, snippets in REQUIRED_SNIPPETS.items():
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in text:
                failures.append(
                    f"{path.relative_to(ROOT)} is missing accessibility smoke snippet: {snippet}"
                )

    for locale in REQUIRED_LOCALES:
        strings_path = APP / f"{locale}.lproj" / "Localizable.strings"
        keys = read_keys(strings_path)
        missing = sorted(REQUIRED_MAIN_APP_ACCESSIBILITY_KEYS - keys)
        if missing:
            sample = ", ".join(missing[:8])
            failures.append(
                f"{strings_path.relative_to(ROOT)} is missing accessibility keys: {sample}"
            )

    if failures:
        print("Accessibility smoke check failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Accessibility smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
