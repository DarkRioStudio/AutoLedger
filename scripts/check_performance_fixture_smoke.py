#!/usr/bin/env python3
"""Static guardrails for the Debug-only iPad/Mac performance fixture."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "AutoLedger/AutoLedger/App/PerformanceFixtureConfiguration.swift"
APP = ROOT / "AutoLedger/AutoLedger/App/AutoLedgerApp.swift"
APP_DELEGATE = ROOT / "AutoLedger/AutoLedger/App/AutoLedgerAppDelegate.swift"


def require(source: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in source:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []
    fixture = FIXTURE.read_text(encoding="utf-8")
    app = APP.read_text(encoding="utf-8")
    app_delegate = APP_DELEGATE.read_text(encoding="utf-8")

    for snippet in [
        "--performance-fixture-count",
        "[500, 5_000, 20_000]",
        "#if DEBUG",
        "PerformanceFixtureTransactionStore",
        "transactionStore: PerformanceFixtureTransactionStore(count: transactionCount)",
        "loadsPersistedConfiguration: false",
        "private var transactions: [Transaction]",
    ]:
        require(fixture, snippet, "PerformanceFixtureConfiguration", failures)

    if "UserDefaults.standard.set(" in fixture:
        failures.append("PerformanceFixtureConfiguration must not mutate user defaults.")

    for snippet in [
        "@StateObject private var store: LedgerStore",
        "PerformanceFixtureConfiguration.makeLedgerStoreIfRequested() ?? LedgerStore()",
        "!ScreenshotModeConfig.isEnabled && !PerformanceFixtureConfiguration.isEnabled",
        "guard !PerformanceFixtureConfiguration.isEnabled else { return }",
    ]:
        require(app, snippet, "AutoLedgerApp", failures)

    require(
        app_delegate,
        "&& !PerformanceFixtureConfiguration.isEnabled",
        "AutoLedgerAppDelegate",
        failures,
    )

    if failures:
        print("Performance fixture smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Performance fixture smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
