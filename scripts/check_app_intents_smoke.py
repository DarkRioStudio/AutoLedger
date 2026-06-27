#!/usr/bin/env python3
"""Static smoke checks for the v1.6.2 App Intents first pass."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

INTENTS_FILE = ROOT / "AutoLedger/AutoLedger/Domain/Services/AutoLedgerNavigationIntents.swift"
SHORTCUTS_FILE = ROOT / "AutoLedger/AutoLedger/Domain/Services/QuickLedgerIntent.swift"
APP_FILE = ROOT / "AutoLedger/AutoLedger/App/AutoLedgerApp.swift"
ADD_TRANSACTION_FILE = ROOT / "AutoLedger/AutoLedger/Domain/Services/AddTransactionIntent.swift"
LOCALES = ["zh-Hans", "zh-Hant", "en", "ja"]

REQUIRED_INTENT_SNIPPETS = [
    "struct LedgerProfileEntity: AppEntity",
    "struct LedgerProfileEntityQuery: EntityQuery",
    "enum AutoLedgerIntentNavigationDestination",
    "enum AutoLedgerIntentNavigationHandoff",
    "struct OpenMonthlyReportIntent: AppIntent",
    "struct OpenLedgerProfileIntent: AppIntent",
    "struct StartReceiptScanIntent: AppIntent",
    "struct OpenHotelReviewQueueIntent: AppIntent",
    "static var openAppWhenRun: Bool = true",
]

REQUIRED_SHORTCUT_SNIPPETS = [
    "OpenMonthlyReportIntent()",
    "OpenLedgerProfileIntent()",
    "StartReceiptScanIntent()",
]

REQUIRED_APP_SNIPPETS = [
    "consumeAppIntentNavigationHandoffIfNeeded()",
    "AutoLedgerIntentNavigationHandoff.consume()",
    "AutoLedgerHomeTab.report.rawValue",
    "AutoLedgerHomeTab.hotelStays.rawValue",
]

REQUIRED_LOCALIZATION_KEYS = [
    "open_monthly_report.intent.title",
    "open_ledger.intent.title",
    "start_receipt_scan.intent.title",
    "open_hotel_review_queue.intent.title",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    try:
        intents_source = read(INTENTS_FILE)
    except FileNotFoundError:
        intents_source = ""
        failures.append(f"missing {INTENTS_FILE.relative_to(ROOT)}")

    for snippet in REQUIRED_INTENT_SNIPPETS:
        if snippet not in intents_source:
            failures.append(f"missing App Intents snippet: {snippet}")

    shortcuts_source = read(SHORTCUTS_FILE)
    for snippet in REQUIRED_SHORTCUT_SNIPPETS:
        if snippet not in shortcuts_source:
            failures.append(f"missing AppShortcuts registration: {snippet}")
    shortcut_count = shortcuts_source.count("AppShortcut(")
    if shortcut_count > 10:
        failures.append(f"AppShortcutsProvider registers {shortcut_count} shortcuts; iOS metadata export allows at most 10")

    app_source = read(APP_FILE)
    for snippet in REQUIRED_APP_SNIPPETS:
        if snippet not in app_source:
            failures.append(f"missing app handoff consumption: {snippet}")

    add_transaction_source = read(ADD_TRANSACTION_FILE)
    if "struct AddTransactionIntent: AppIntent" not in add_transaction_source or "static var openAppWhenRun: Bool = false" not in add_transaction_source:
        failures.append("AddTransactionIntent must remain an inline action and not force-open the app")

    for locale in LOCALES:
        strings_path = ROOT / f"AutoLedger/AutoLedger/{locale}.lproj/Localizable.strings"
        strings = read(strings_path)
        for key in REQUIRED_LOCALIZATION_KEYS:
            if f'"{key}"' not in strings:
                failures.append(f"{strings_path.relative_to(ROOT)} missing {key}")

    if failures:
        print("App Intents smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("App Intents smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
