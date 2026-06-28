#!/usr/bin/env python3
"""Static smoke checks for v1.6.2 Japanese release and multilingual golden coverage."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WIDGET_FILE = ROOT / "AutoLedger/AutoLedgerWidgets/AutoLedgerWidgets.swift"
SHORTCUTS_FILE = ROOT / "AutoLedger/AutoLedger/Domain/Services/QuickLedgerIntent.swift"
INTENTS_FILE = ROOT / "AutoLedger/AutoLedger/Domain/Services/AutoLedgerNavigationIntents.swift"
JA_STRINGS = ROOT / "AutoLedger/AutoLedger/ja.lproj/Localizable.strings"
GOLDEN_CASES = ROOT / "tests/golden/ledger_text_interpreter/cases.jsonl"
GOLDEN_RUNNER = ROOT / "tools/receipt_ocr/golden_regression.swift"
CHECKLIST = ROOT / "versions/v1.6.2-ja-release-review-checklist.md"

REQUIRED_WIDGET_SNIPPETS = [
    "fileprivate static var isJapanese",
    'localized(zh: "今日支出", ja: "今日の支出", en: "Today\'s Spend")',
    'localized(zh: "本地账本", ja: "ローカル台帳", en: "Local Ledger")',
    'localized(zh: "待确认", ja: "確認待ち", en: "Needs Review")',
    'localized(zh: "餐饮", ja: "飲食", en: "Dining")',
    'localized(zh: "手动记录", ja: "手動記録", en: "Manual")',
]

FORBIDDEN_WIDGET_SNIPPETS = [
    'localized(zh: "默认写入账本：%@", ja: "既定の記録先：%@", en: "Default ledger: %@")',
    "默认写入账本：",
    "Default ledger:",
    "既定の記録先：",
]

REQUIRED_SHORTCUT_PHRASES = [
    "で記録",
    "クリップボードから記録",
    "音声記録",
    "手動記録",
    "レシート文字を解析",
    "JSON 台帳",
    "クイック追加",
    "今月の統計",
    "レシートスキャン",
]

REQUIRED_JA_STRING_KEYS = [
    '"open_monthly_report.intent.title"',
    '"open_ledger.intent.title"',
    '"start_receipt_scan.intent.title"',
    '"open_hotel_review_queue.intent.title"',
]

REQUIRED_GOLDEN_SNIPPETS = [
    '"id":"core_ja_receipt_total_merchant"',
    '"id":"core_ja_cafe_category"',
    '"localeIdentifier":"ja-JP"',
    "合計 ¥1,080",
    "店舗: 東京カフェ",
]

REQUIRED_RUNNER_SNIPPETS = [
    "let localeIdentifier: String?",
    "localeIdentifier: testCase.localeIdentifier",
]

REQUIRED_CHECKLIST_SNIPPETS = [
    "# v1.6.2 日文发布审校清单",
    "App Intents / Shortcuts",
    "Widget",
    "识别语言包与 Golden",
    "core_ja_receipt_total_merchant",
    "core_ja_cafe_category",
    "手动 PDF / Share Extension",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def require_snippets(source: str, snippets: list[str], path: Path, failures: list[str]) -> None:
    for snippet in snippets:
        if snippet not in source:
            failures.append(f"{path.relative_to(ROOT)} missing snippet: {snippet}")


def reject_snippets(source: str, snippets: list[str], path: Path, failures: list[str]) -> None:
    for snippet in snippets:
        if snippet in source:
            failures.append(f"{path.relative_to(ROOT)} should not contain removed widget copy: {snippet}")


def main() -> int:
    failures: list[str] = []

    widget_source = read(WIDGET_FILE)
    require_snippets(widget_source, REQUIRED_WIDGET_SNIPPETS, WIDGET_FILE, failures)
    reject_snippets(widget_source, FORBIDDEN_WIDGET_SNIPPETS, WIDGET_FILE, failures)

    shortcuts_source = read(SHORTCUTS_FILE)
    require_snippets(shortcuts_source, REQUIRED_SHORTCUT_PHRASES, SHORTCUTS_FILE, failures)
    shortcut_count = shortcuts_source.count("AppShortcut(")
    if shortcut_count > 10:
        failures.append(f"{SHORTCUTS_FILE.relative_to(ROOT)} registers {shortcut_count} AppShortcuts; keep at most 10")

    intents_source = read(INTENTS_FILE)
    if "OpenHotelReviewQueueIntent" not in intents_source:
        failures.append(f"{INTENTS_FILE.relative_to(ROOT)} missing hotel review queue intent")

    require_snippets(read(JA_STRINGS), REQUIRED_JA_STRING_KEYS, JA_STRINGS, failures)
    require_snippets(read(GOLDEN_CASES), REQUIRED_GOLDEN_SNIPPETS, GOLDEN_CASES, failures)
    require_snippets(read(GOLDEN_RUNNER), REQUIRED_RUNNER_SNIPPETS, GOLDEN_RUNNER, failures)
    require_snippets(read(CHECKLIST), REQUIRED_CHECKLIST_SNIPPETS, CHECKLIST, failures)

    if failures:
        print("L10N release smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("L10N release smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
