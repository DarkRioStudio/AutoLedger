#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"

FORBIDDEN_PATTERNS = [
    "UIDevice.current.userInterfaceIdiom",
    "UIScreen.main",
    "interfaceOrientation",
    ".isLandscape",
    ".isPortrait",
]

REQUIRED_SNIPPETS = {
    APP / "App" / "AutoLedgerApp.swift": [
        "@StateObject private var navigationState",
        ".environmentObject(navigationState)",
    ],
    APP / "App" / "AutoLedgerNavigationState.swift": [
        "final class AutoLedgerNavigationState",
        "selectedHomeTab",
        "settingsPath",
        "selectedLedgerTransactionID",
        "selectedSubscriptionID",
        "subscriptionEditor",
    ],
    APP / "Features" / "Inbox" / "HomeView.swift": [
        "if #available(iOS 27.0, *)",
        ".tabViewStyle(.sidebarAdaptable)",
        ".defaultTabBarPlacement(.sidebar)",
        "$navigationState.selectedHomeTab",
        "navigationState.openLedgerProfiles()",
    ],
    APP / "Features" / "Ledger" / "LedgerView.swift": [
        "NavigationSplitView",
        "navigationState.selectedLedgerTransactionID",
        "navigationState.isPresentingNewTransaction",
    ],
    APP / "Features" / "Settings" / "SubscriptionListView.swift": [
        "NavigationSplitView",
        "navigationState.selectedSubscriptionID",
        "navigationState.subscriptionEditor",
    ],
    APP / "Features" / "Inbox" / "InboxView.swift": [
        "GridItem(.adaptive",
        "LazyVGrid",
    ],
    APP / "Features" / "Report" / "ReportView.swift": [
        "GridItem(.adaptive",
        "LazyVGrid",
    ],
    APP / "Features" / "Settings" / "SettingsView.swift": [
        "$navigationState.settingsPath",
        ".frame(maxWidth: 760",
    ],
}


def main() -> int:
    failures: list[str] = []

    for path in APP.rglob("*.swift"):
        if ".build" in path.parts:
            continue
        text = path.read_text(encoding="utf-8")
        for pattern in FORBIDDEN_PATTERNS:
            if pattern in text:
                failures.append(f"{path.relative_to(ROOT)} contains forbidden layout pattern: {pattern}")

    app_entry = APP / "App" / "AutoLedgerApp.swift"
    if "@main" not in app_entry.read_text(encoding="utf-8") or "WindowGroup" not in app_entry.read_text(encoding="utf-8"):
        failures.append("AutoLedgerApp.swift must keep the SwiftUI App/WindowGroup lifecycle.")

    for path, snippets in REQUIRED_SNIPPETS.items():
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet not in text:
                failures.append(f"{path.relative_to(ROOT)} is missing required adaptive layout snippet: {snippet}")

    if failures:
        print("Adaptive layout guard failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Adaptive layout guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
