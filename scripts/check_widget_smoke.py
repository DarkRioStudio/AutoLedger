#!/usr/bin/env python3
"""Static smoke checks for the v1.6.2 widget first pass."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WIDGET_FILE = ROOT / "AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift"
BUNDLE_FILE = ROOT / "AutoLedger/AutoLedgerWidgets/AutoLedgerWidgetsBundle.swift"
NAVIGATION_FILE = ROOT / "AutoLedger/AutoLedger/App/AutoLedgerNavigationState.swift"
LEDGER_STORE_FILE = ROOT / "AutoLedger/AutoLedger/App/LedgerStore.swift"

REQUIRED_WIDGET_SNIPPETS = [
    "defaultWriteLedgerIDKey",
    "WidgetLedgerScope",
    "topCategory",
    "recentTransactions",
    "upcomingSubscriptions",
    "quickAddURL",
    "autoledger://quick-add",
    "loadUpcomingSubscriptions",
    "WHERE deleted_at IS NULL",
    "ledger_id IS NULL OR ledger_id = ?",
    "WidgetSubscription",
    "Link(destination: WidgetDeepLink.quickAddURL",
]

FORBIDDEN_WIDGET_SNIPPETS = [
    "budgetRemaining",
    "monthlyBudgetAmount",
    "budgetRemainingTitle",
    "budgetNotSet",
    "预算剩余",
    "予算残高",
    "Budget Left",
]

REQUIRED_NAVIGATION_SNIPPETS = [
    "case quickAdd",
    'case "quick-add", "quickadd", "add"',
    "isPresentingNewTransaction = true",
]

REQUIRED_LEDGER_STORE_SNIPPETS = [
    "Self.appGroupDefaults?.set(defaultWriteLedgerID, forKey: Self.defaultWriteLedgerIDKey)",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    widget_source = read(WIDGET_FILE)
    for snippet in REQUIRED_WIDGET_SNIPPETS:
        if snippet not in widget_source:
            failures.append(f"{WIDGET_FILE.relative_to(ROOT)} missing widget snippet: {snippet}")
    for snippet in FORBIDDEN_WIDGET_SNIPPETS:
        if snippet in widget_source:
            failures.append(f"{WIDGET_FILE.relative_to(ROOT)} still contains unsupported budget snippet: {snippet}")

    if "sqlite3_open_v2" not in widget_source or "SQLITE_OPEN_READONLY" not in widget_source:
        failures.append("Widget must open SQLite in read-only mode")
    if "INSERT INTO" in widget_source or "UPDATE " in widget_source or "DELETE FROM" in widget_source:
        failures.append("Widget extension must not write SQLite")

    bundle_source = read(BUNDLE_FILE)
    for widget_name in ["DailyExpenseWidget()", "MonthlyReportWidget()"]:
        if widget_name not in bundle_source:
            failures.append(f"{BUNDLE_FILE.relative_to(ROOT)} missing bundle registration: {widget_name}")

    navigation_source = read(NAVIGATION_FILE)
    for snippet in REQUIRED_NAVIGATION_SNIPPETS:
        if snippet not in navigation_source:
            failures.append(f"{NAVIGATION_FILE.relative_to(ROOT)} missing quick-add route snippet: {snippet}")

    ledger_store_source = read(LEDGER_STORE_FILE)
    for snippet in REQUIRED_LEDGER_STORE_SNIPPETS:
        if snippet not in ledger_store_source:
            failures.append(f"{LEDGER_STORE_FILE.relative_to(ROOT)} missing App Group ledger config sync: {snippet}")

    if failures:
        print("Widget smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Widget smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
