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
    view = (APP / "Features" / "Settings" / "SubscriptionListView.swift").read_text(encoding="utf-8")

    require(view, "SubscriptionAnomalyDetector", "SubscriptionListView", failures)
    require(view, "subscriptionAnomalySection", "SubscriptionListView", failures)
    require(view, "proEntitlement.canUse(.subscriptionAnomalyDetection)", "SubscriptionListView", failures)
    require(view, "AutoLedgerProView()", "SubscriptionListView", failures)
    require(view, '"subscriptions.anomaly.title"', "SubscriptionListView", failures)
    require(view, '"subscriptions.anomaly.pressure_format"', "SubscriptionListView", failures)
    require(view, "recordSubscriptionAnomalyDecision", "SubscriptionListView", failures)
    require(view, ".confirmed", "SubscriptionListView", failures)
    require(view, ".ignored", "SubscriptionListView", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "subscriptions.anomaly.title",
            "subscriptions.anomaly.pro.title",
            "subscriptions.anomaly.pro.body",
            "subscriptions.anomaly.price_increase",
            "subscriptions.anomaly.price_increase_format",
            "subscriptions.anomaly.duplicate_charge",
            "subscriptions.anomaly.duplicate_charge_format",
            "subscriptions.anomaly.billing_cycle_drift",
            "subscriptions.anomaly.billing_cycle_drift_format",
            "subscriptions.anomaly.pressure",
            "subscriptions.anomaly.pressure_format",
            "subscriptions.anomaly.confirm",
            "subscriptions.anomaly.ignore",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Subscription anomaly UI smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Subscription anomaly UI smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
