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
    ".toolbar(.hidden, for: .navigationBar)",
    ".navigationTitle(\"\")",
]

REQUIRED_SNIPPETS = {
    APP / "App" / "AutoLedgerApp.swift": [
        "@StateObject private var navigationState",
        ".environmentObject(navigationState)",
        "themeRefreshID",
        ".autoLedgerMotion(AppMotion.theme, value: themeRefreshID)",
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
        "autoLedgerAdaptiveTabBar()",
        "$navigationState.selectedHomeTab",
        "navigationState.openLedgerProfiles()",
    ],
    APP / "Shared" / "Constants" / "AppTheme.swift": [
        "autoLedgerAdaptiveTabBar",
        "#if compiler(>=6.4)",
        "if #available(iOS 27.0, *)",
        ".tabViewStyle(.sidebarAdaptable)",
        ".defaultTabBarPlacement(.sidebar)",
        "autoLedgerFormChrome",
        "autoLedgerListChrome",
        "autoLedgerNavigationBarChrome",
        "autoLedgerSolidNavigationBarChrome",
        "autoLedgerContentTitleNavigation",
        "AutoLedgerPageTitle",
        ".regularMaterial",
        "case harbor",
        "case sunrise",
        "case ledgerInk",
        "case nightFolio",
        "case custom",
        "static let selectableCases: [AppThemePreset] = [.fresh, .classic, .graphite, .ledgerInk, .harbor, .custom]",
        "AppThemeCustomTheme",
    ],
    APP / "Features" / "Settings" / "AppearanceSettingsView.swift": [
        "themeMenuCard",
        "themeDropdownLabel",
        "Menu {",
        "Button {",
        "Image(systemName: \"chevron.up.chevron.down\")",
        "ForEach(AppThemePreset.selectableCases)",
        "AppearancePreviewCard(preset: selectedPreset)",
        "AppearanceCustomThemeLockedCard",
        "ColorPicker",
        "AutoLedgerProView()",
    ],
    APP / "Features" / "Ledger" / "LedgerView.swift": [
        "NavigationSplitView",
        "@Environment(\\.horizontalSizeClass)",
        "prefersPersistentDetail",
        "navigationState.selectedLedgerTransactionID",
        "navigationState.isPresentingNewTransaction",
        "dismissesOnSave: !prefersPersistentDetail",
        "ToolbarItem(placement: .primaryAction)",
        "Menu",
        "autoLedgerListChrome",
        "autoLedgerNavigationBarChrome",
        "navigationSplitViewColumnWidth(min: 360, ideal: 430, max: 520)",
    ],
    APP / "Features" / "iPad" / "iPadWorkspaceView.swift": [
        "@EnvironmentObject private var navigationState",
        "case .ledger:",
        "LedgerView {",
        "openLedgerProfilesFromSharedLedger",
        "canUseBatchCandidateImport",
        "batchProGateBanner",
        "requestBatchFileImport",
    ],
    APP / "Features" / "Settings" / "SubscriptionListView.swift": [
        "NavigationSplitView",
        "navigationState.selectedSubscriptionID",
        "navigationState.subscriptionEditor",
        "ToolbarItem(placement: .primaryAction)",
        "Menu",
        "subscriptionToolbarMenu",
        "isPresented: $isPresentingPhotoPicker",
        "uploadSubscriptionScreenshot()",
        "SubscriptionThemedIconButton",
        "autoLedgerListChrome",
        "autoLedgerFormChrome",
    ],
    APP / "Features" / "Inbox" / "InboxView.swift": [
        "if isQuickSetupExpanded",
        "photoImportButton",
        "receiptScanButton",
        "AutoLedgerPageTitle(\"tab.inbox\")",
        ".autoLedgerContentTitleNavigation(\"tab.inbox\")",
        "quickEntryActionMenu",
        "quickImportButtonRow",
        "autoLedgerSolidNavigationBarChrome",
    ],
    APP / "Features" / "Report" / "ReportView.swift": [
        "GridItem(.adaptive",
        "LazyVGrid",
        "AutoLedgerPageTitle(\"tab.report\")",
        ".autoLedgerContentTitleNavigation(\"tab.report\")",
        "autoLedgerSolidNavigationBarChrome",
    ],
    APP / "Features" / "Settings" / "SettingsView.swift": [
        "$navigationState.settingsPath",
        "autoLedgerReadableContent(maxWidth: 760",
        "AutoLedgerPageTitle(\"settings.title\")",
        ".autoLedgerContentTitleNavigation(\"settings.title\")",
        "autoLedgerSolidNavigationBarChrome",
        "private var proPriceStack",
    ],
    APP / "Features" / "Ledger" / "TransactionEditorView.swift": [
        "Label(\"common.save\", systemImage: \"checkmark\")",
        "transactionActionMenu",
    ],
    APP / "Features" / "Settings" / "LedgerProfileManagementView.swift": [
        "profileRenameButton(profile)",
    ],
    APP / "zh-Hans.lproj" / "Localizable.strings": [
        "\"hotel_stay.detail.title\" = \"编辑消费详情\"",
    ],
    APP / "zh-Hant.lproj" / "Localizable.strings": [
        "\"hotel_stay.detail.title\" = \"編輯消費詳情\"",
    ],
    APP / "en.lproj" / "Localizable.strings": [
        "\"hotel_stay.detail.title\" = \"Edit Stay Details\"",
    ],
    APP / "ja.lproj" / "Localizable.strings": [
        "\"hotel_stay.detail.title\" = \"滞在明細を編集\"",
    ],
    APP / "Features" / "Hotel" / "HotelFolioEmailImportView.swift": [
        ".navigationTitle(\"hotel_stay.email.title\")",
        ".navigationBarTitleDisplayMode(.inline)",
        "ToolbarItem(placement: .principal)",
        "autoLedgerSolidNavigationBarChrome",
    ],
}

FORBIDDEN_FILE_SNIPPETS = {
    APP / "Features" / "Inbox" / "InboxView.swift": [
        "private var pageTitle",
        "VoiceLedgerQuickEntryView()",
        "toolbarRevealOffset: -56",
    ],
    APP / "Features" / "Report" / "ReportView.swift": [
        "private var pageTitle",
    ],
    APP / "Features" / "Settings" / "SettingsView.swift": [
        "private var pageTitle",
    ],
    APP / "Features" / "Settings" / "AppearanceSettingsView.swift": [
        "appearance.mode.subtitle",
        "themePickerGrid",
        "AppearanceThemeOptionCard",
        "Picker(\"appearance.theme_picker\", selection: themeSelection)",
    ],
    APP / "Features" / "Ledger" / "TransactionEditorView.swift": [
        "Label(\"common.save\", systemImage: \"checkmark.circle.fill\")",
        ".buttonBorderShape(.circle)",
        ".labelStyle(.iconOnly)",
    ],
    APP / "Features" / "Settings" / "SubscriptionListView.swift": [
        "subscriptions.scan_history_help",
        "store.detectAndUpsertSubscriptions()",
    ],
    APP / "zh-Hans.lproj" / "Localizable.strings": [
        "\"hotel_stay.detail.title\" = \"酒店消费详情\"",
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

    for path, snippets in FORBIDDEN_FILE_SNIPPETS.items():
        text = path.read_text(encoding="utf-8")
        for snippet in snippets:
            if snippet in text:
                failures.append(f"{path.relative_to(ROOT)} contains duplicate in-content tab title snippet: {snippet}")

    if failures:
        print("Adaptive layout guard failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Adaptive layout guard passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
