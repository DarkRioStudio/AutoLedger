#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"
CORE = ROOT / "AutoLedger" / "AutoLedgerCore" / "Sources" / "AutoLedgerCore"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []
    planner = (CORE / "Services" / "PendingActionCenterPlanner.swift").read_text(encoding="utf-8")
    center = (APP / "Features" / "Inbox" / "PendingActionCenterView.swift").read_text(encoding="utf-8")
    inbox = (APP / "Features" / "Inbox" / "InboxView.swift").read_text(encoding="utf-8")
    ipad = (APP / "Features" / "iPad" / "iPadWorkspaceView.swift").read_text(encoding="utf-8")

    for category in [
        "receiptReview",
        "hotelReview",
        "duplicateReview",
        "subscriptionAnomaly",
        "cleaningSuggestion",
    ]:
        require(planner, f"case {category}", "PendingActionCenterPlanner", failures)

    require(center, "PendingActionCenterLoader", "PendingActionCenterView", failures)
    require(center, "Task.detached", "PendingActionCenterView", failures)
    require(center, "filteringHandledAnomalies", "PendingActionCenterView", failures)
    require(center, "subscriptionAnomalyDecisionRevision", "PendingActionCenterView", failures)
    require(inbox, "PendingActionCenterCard(", "InboxView", failures)
    require(inbox, "PendingActionCenterListView(", "InboxView", failures)
    require(ipad, "case pendingActions", "IPadWorkspaceView", failures)
    require(ipad, "IPadPendingActionWorkspaceView(", "IPadWorkspaceView", failures)

    if 'canUse(.subscriptionAnomalyDetection)' in center or 'canUse(.advancedDeduplication)' in center:
        failures.append("The pending center itself must remain visible without a Pro gate.")

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "pending_center.title",
            "pending_center.empty.title",
            "pending_center.receipt.title",
            "pending_center.hotel.title",
            "pending_center.duplicate.title",
            "pending_center.subscription.title",
            "pending_center.cleaning.title",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Pending action center smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Pending action center smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
