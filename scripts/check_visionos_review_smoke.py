#!/usr/bin/env python3
"""Static smoke checks for visionOS App Review fallback data."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VISION_CONTENT = ROOT / "AutoLedger/AutoLedgerVision/ContentView.swift"

REQUIRED_SOURCE_SNIPPETS = [
    "visionOS sample dashboard data",
    "visionOS 示例看板数据",
]

REQUIRED_LOAD_TRANSACTION_SNIPPETS = [
    "let transactions = sortForDashboard(snapshot.displayTransactions)",
    "if !transactions.isEmpty {",
    "return transactions",
    "return sortForDashboard(VisionDashboardSimulatorData.transactions(referenceDate: Date()))",
]

FORBIDDEN_SOURCE_SNIPPETS = [
    "visionOS simulator demo data",
    "visionOS 模拟器演示数据",
]

FORBIDDEN_LOAD_TRANSACTION_SNIPPETS = [
    "return sortForDashboard(snapshot.displayTransactions)",
    "return []",
]


def extract_load_transactions(source: str) -> str:
    start = source.find("nonisolated private static func loadTransactions()")
    end = source.find("nonisolated private static func sortForDashboard", start)
    if start == -1 or end == -1:
        return ""
    return source[start:end]


def main() -> int:
    source = VISION_CONTENT.read_text(encoding="utf-8")
    load_transactions = extract_load_transactions(source)
    failures: list[str] = []

    if not load_transactions:
        failures.append(f"{VISION_CONTENT.relative_to(ROOT)} missing loadTransactions() block")

    for snippet in REQUIRED_SOURCE_SNIPPETS:
        if snippet not in source:
            failures.append(f"{VISION_CONTENT.relative_to(ROOT)} missing snippet: {snippet}")

    for snippet in FORBIDDEN_SOURCE_SNIPPETS:
        if snippet in source:
            failures.append(f"{VISION_CONTENT.relative_to(ROOT)} should not contain review-risk snippet: {snippet}")

    for snippet in REQUIRED_LOAD_TRANSACTION_SNIPPETS:
        if snippet not in load_transactions:
            failures.append(f"{VISION_CONTENT.relative_to(ROOT)} loadTransactions() missing snippet: {snippet}")

    for snippet in FORBIDDEN_LOAD_TRANSACTION_SNIPPETS:
        if snippet in load_transactions:
            failures.append(f"{VISION_CONTENT.relative_to(ROOT)} loadTransactions() should not contain review-risk snippet: {snippet}")

    if failures:
        print("visionOS review smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("visionOS review smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
