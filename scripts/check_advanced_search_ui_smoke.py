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
    ledger = (APP / "Features" / "Ledger" / "LedgerView.swift").read_text(encoding="utf-8")

    require(ledger, "LedgerAdvancedSearchQuery", "LedgerView", failures)
    require(ledger, "LedgerAdvancedSearchService", "LedgerView", failures)
    require(ledger, "advancedSearchSheet", "LedgerView", failures)
    require(ledger, "savedAdvancedSearches", "LedgerView", failures)
    require(ledger, "proEntitlement.canUse(.advancedSearch)", "LedgerView", failures)
    require(ledger, "AutoLedgerProView()", "LedgerView", failures)
    require(ledger, '"ledger.advanced_search.title"', "LedgerView", failures)
    require(ledger, '"ledger.advanced_search.save_current"', "LedgerView", failures)
    require(ledger, '"ledger.advanced_search.hotel_folio"', "LedgerView", failures)
    require(ledger, "@State private var draftQuery", "LedgerView draft search", failures)
    require(ledger, "@State private var isAmountFilterEnabled", "LedgerView amount toggle", failures)
    require(ledger, "@State private var isCategoryFilterEnabled", "LedgerView category toggle", failures)
    require(ledger, "@State private var isSourceFilterEnabled", "LedgerView source toggle", failures)
    require(ledger, "@State private var isLedgerFilterEnabled", "LedgerView ledger toggle", failures)
    require(ledger, "normalizedDraftQuery", "LedgerView disabled-filter normalization", failures)
    require(ledger, ".safeAreaInset(edge: .bottom)", "LedgerView apply action", failures)
    require(ledger, 'Label("ledger.advanced_search.apply"', "LedgerView apply action", failures)
    require(ledger, "onApply(snapshot, snapshot.keyword)", "LedgerView explicit apply", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "ledger.advanced_search.title",
            "ledger.advanced_search.subtitle",
            "ledger.advanced_search.amount_range",
            "ledger.advanced_search.date_range",
            "ledger.advanced_search.category",
            "ledger.advanced_search.source",
            "ledger.advanced_search.ledger",
            "ledger.advanced_search.hotel_folio",
            "ledger.advanced_search.original_currency",
            "ledger.advanced_search.save_current",
            "ledger.advanced_search.saved",
            "ledger.advanced_search.clear",
            "ledger.advanced_search.apply",
            "ledger.advanced_search.pro.title",
            "ledger.advanced_search.pro.body",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Advanced search UI smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Advanced search UI smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
