#!/usr/bin/env python3
"""Static smoke checks for AutoLedger deep link routing."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"
PROJECT = ROOT / "AutoLedger" / "AutoLedger.xcodeproj" / "project.pbxproj"
INFO_PLIST = APP / "Info.plist"
REQUIRED_LOCALES = ["zh-Hans", "zh-Hant", "en", "ja"]
STRING_FILE_PATTERN = re.compile(r'^\s*"((?:[^"\\]|\\.)+)"\s*=')

REQUIRED_SNIPPETS = {
    PROJECT: [
        "INFOPLIST_FILE = AutoLedger/Info.plist;",
    ],
    INFO_PLIST: [
        "<key>CFBundleURLTypes</key>",
        "<string>top.darkrio326.AutoLedger</string>",
        "<string>autoledger</string>",
    ],
    APP / "App" / "AutoLedgerApp.swift": [
        ".onOpenURL { url in",
        "navigationState.openDeepLink(url, store: store)",
    ],
    APP / "App" / "AutoLedgerNavigationState.swift": [
        "enum AutoLedgerDeepLinkDestination",
        "enum AutoLedgerDeepLinkParser",
        'static let scheme = "autoledger"',
        "case ledgerToday",
        "case transaction(UUID)",
        "case hotelStay(UUID)",
        "case hotelCloudCandidate(UUID?)",
        "case subscriptions",
        "case ledgerProfiles",
        "case scan",
        "case quickAdd",
        'case "hotel-cloud-candidate", "hotelcloudcandidate"',
        'case "hotel-cloud-candidates", "hotelcloudcandidates"',
        'case "quick-add", "quickadd", "add"',
        "@Published var selectedHotelStayRecordID",
        "@Published var pendingHotelCloudCandidateID",
        "func openDeepLink(_ url: URL, store: LedgerStore) -> Bool",
        "selectLedgerForTransaction",
        "selectLedgerForHotelStay",
    ],
    APP / "Features" / "Hotel" / "HotelStayArchiveView.swift": [
        "NavigationSplitView",
        "@Binding private var selectedRecordID",
        "NavigationLink(value: row.id)",
        "hotel_stay.detail.empty.title",
    ],
    APP / "Features" / "Settings" / "SettingsView.swift": [
        "NavigationLink(value: SettingsNavigationTarget.subscriptions)",
        "case .subscriptions:",
    ],
    APP / "Features" / "iPad" / "iPadWorkspaceView.swift": [
        "routeSharedHomeTab",
        ".onChange(of: navigationState.selectedHomeTab)",
    ],
}

REQUIRED_LOCALIZATION_KEYS = {
    "hotel_stay.detail.empty.title",
    "hotel_stay.detail.empty.description",
}


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

    for path, snippets in REQUIRED_SNIPPETS.items():
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in text:
                failures.append(
                    f"{path.relative_to(ROOT)} is missing deep link snippet: {snippet}"
                )

    for locale in REQUIRED_LOCALES:
        strings_path = APP / f"{locale}.lproj" / "Localizable.strings"
        keys = read_keys(strings_path)
        missing = sorted(REQUIRED_LOCALIZATION_KEYS - keys)
        if missing:
            failures.append(
                f"{strings_path.relative_to(ROOT)} is missing deep link keys: {', '.join(missing)}"
            )

    if failures:
        print("Deep link smoke check failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Deep link smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
