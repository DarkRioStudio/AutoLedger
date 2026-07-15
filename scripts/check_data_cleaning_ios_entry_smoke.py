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
    settings = (APP / "Features" / "Settings" / "SettingsView.swift").read_text(encoding="utf-8")
    cleaning = (APP / "Features" / "Settings" / "DataCleaningSuggestionsView.swift").read_text(encoding="utf-8")
    ledger = (APP / "Features" / "Ledger" / "LedgerView.swift").read_text(encoding="utf-8")

    require(settings, 'settingsSection(title: "settings.section.smart_cleanup")', "SettingsView", failures)
    require(settings, "private func dataCleaningShortcutRow()", "SettingsView", failures)
    require(settings, "DataCleaningSuggestionsView()", "SettingsView", failures)
    require(settings, "wand.and.sparkles", "SettingsView", failures)
    require(ledger, "isPresentingDataCleaning", "LedgerView", failures)
    require(ledger, "DataCleaningSuggestionsView()", "LedgerView", failures)
    require(ledger, 'Label("settings.data_cleaning.title", systemImage: "wand.and.sparkles")', "LedgerView", failures)

    appearance_index = settings.find('settingsSection(title: "settings.section.appearance")')
    cleanup_index = settings.find('settingsSection(title: "settings.section.smart_cleanup")')
    if cleanup_index < 0 or appearance_index < 0 or cleanup_index > appearance_index:
        failures.append("SettingsView must show the data-cleaning shortcut before the Appearance section.")

    require(cleaning, '@AppStorage("dataCleaningCloudAssistEnabled")', "DataCleaningSuggestionsView", failures)
    require(cleaning, "cloudAssistAuthorizationCard", "DataCleaningSuggestionsView", failures)
    require(cleaning, "DataCleaningAssistRequestPolicy", "DataCleaningSuggestionsView", failures)
    require(cleaning, "DataCleaningAssistRequestContext", "DataCleaningSuggestionsView", failures)
    require(cleaning, "if !isCloudAssistEnabled", "DataCleaningSuggestionsView", failures)
    require(cleaning, "reason: .disabledByUser", "DataCleaningSuggestionsView", failures)
    require(cleaning, "reason: .requiresPro", "DataCleaningSuggestionsView", failures)
    require(cleaning, "userEnabledCloudAssist: true", "DataCleaningSuggestionsView", failures)
    require(cleaning, "cloud_assist", "DataCleaningSuggestionsView", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "settings.section.smart_cleanup",
            "ipad.cleaning.cloud_assist.title",
            "ipad.cleaning.cloud_assist.subtitle",
            "ipad.cleaning.cloud_assist.status.allowed",
            "ipad.cleaning.cloud_assist.status.disabled",
            "ipad.cleaning.cloud_assist.status.requires_pro",
            "ipad.cleaning.cloud_assist.status.insufficient_history",
            "ipad.cleaning.cloud_assist.status.cooling_down",
            "ipad.cleaning.cloud_assist.status.backoff",
            "ipad.cleaning.cloud_assist.privacy_note",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Data-cleaning iOS entry smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Data-cleaning iOS entry smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
