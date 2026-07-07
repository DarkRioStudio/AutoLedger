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
    cleaning = (APP / "Features" / "Settings" / "DataCleaningSuggestionsView.swift").read_text(encoding="utf-8")
    ipad = (APP / "Features" / "iPad" / "iPadWorkspaceView.swift").read_text(encoding="utf-8")

    for label, source in [
        ("DataCleaningSuggestionsView", cleaning),
        ("iPadWorkspaceView", ipad),
    ]:
        require(source, "AdvancedRuleAutomationPlanner", label, failures)
        require(source, "advancedRulePlan", label, failures)
        require(source, ".advancedRuleAutomation", label, failures)
        require(source, "advancedRuleAutomation", label, failures)
        require(source, "store.applyDataCleaningPreviews", label, failures)
        require(source, '"ipad.cleaning.rules.title"', label, failures)
        require(source, '"ipad.cleaning.rules.apply"', label, failures)

    require(cleaning, "proEntitlement.canUse(.advancedRuleAutomation)", "DataCleaningSuggestionsView", failures)
    require(cleaning, "pendingPreviews = advancedRulePlan.previewItems", "DataCleaningSuggestionsView", failures)
    require(ipad, "previewPendingApplication = advancedRulePlan.previewItems", "iPadWorkspaceView", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "ipad.cleaning.rules.title",
            "ipad.cleaning.rules.subtitle_format",
            "ipad.cleaning.rules.empty",
            "ipad.cleaning.rules.apply",
            "ipad.cleaning.rules.alias_count_format",
            "ipad.cleaning.rules.category_count_format",
            "ipad.cleaning.rules.affected_count_format",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Advanced rule automation UI smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Advanced rule automation UI smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
