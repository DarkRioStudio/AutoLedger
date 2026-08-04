#!/usr/bin/env python3
"""Static guard for v1.8 user-visible locale and currency defaults."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILES = {
    "notification": ROOT / "AutoLedger/AutoLedger/Domain/Services/NotificationService.swift",
    "voice": ROOT / "AutoLedger/AutoLedger/Domain/Services/VoiceSpeechRecognizer.swift",
    "watch_quick_add": ROOT / "AutoLedger/AutoLedgerWatch Watch App/QuickAddView.swift",
    "watch_voice": ROOT / "AutoLedger/AutoLedgerWatch Watch App/WatchVoiceConfirmView.swift",
    "share_card": ROOT / "AutoLedger/AutoLedger/Features/ShareCards/MonthlySummaryShareCardView.swift",
    "hotel_archive": ROOT / "AutoLedger/AutoLedger/Features/Hotel/HotelStayArchiveView.swift",
    "formatters": ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Utils/AppFormatters.swift",
    "currency_preference": ROOT / "AutoLedger/AutoLedger/Shared/Constants/ExpenseCurrencyPreference.swift",
    "root": ROOT / "AutoLedger/AutoLedger/App/AutoLedgerApp.swift",
    "ledger_store": ROOT / "AutoLedger/AutoLedger/App/LedgerStore.swift",
    "ledger_view": ROOT / "AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift",
    "inbox": ROOT / "AutoLedger/AutoLedger/Features/Inbox/InboxView.swift",
    "transaction_editor": ROOT / "AutoLedger/AutoLedger/Features/Ledger/TransactionEditorView.swift",
}

FORBIDDEN = {
    "notification": ['String(format: "¥'],
    "voice": ['Locale(identifier: "zh_CN")'],
    "watch_quick_add": ['Text("¥")'],
    "watch_voice": ['Text("¥ '],
    "share_card": ['"yensign.circle.fill"'],
    "hotel_archive": ['?? "CNY"'],
    "ledger_view": ["AppFormatters.currency(transaction.amount))"],
}

REQUIRED = {
    "notification": ["AppFormatters.currency", "currencyCode:"],
    "voice": ["AppLanguagePreference.current.speechRecognitionLocale"],
    "watch_quick_add": ["WatchLedgerFormatters.currencySymbol"],
    "watch_voice": ["WatchLedgerFormatters.currency"],
    "share_card": ['"banknote.fill"'],
    "hotel_archive": ["ExpenseCurrencyPreference.currentCode"],
    "formatters": ["isAmbiguousNumericDate", "prefersDayFirstDateOrder"],
    "currency_preference": [
        "pendingSystemCurrencyChange",
        "useCurrentSystemCurrency",
        "keepPreviousCurrency",
    ],
    "root": [
        '"language.currency.region_change.message_format"',
        "detectSystemCurrencyChangeIfNeeded",
    ],
    "ledger_store": [
        "backfillMissingLedgerCurrencyCodes",
        "transactionCurrencyCode(for:",
        "currentLedgerCurrencyCode",
        "formattedCurrentLedgerAmount",
        "ledgerCurrencyCode: fixedCurrencyCode",
        '"ledger.currency.multiple_unconverted"',
    ],
    "ledger_view": ["code: store.transactionCurrencyCode(for: transaction)"],
    "inbox": ["store.formattedCurrentLedgerAmount"],
    "transaction_editor": [
        'LabeledContent("transaction_editor.currency")',
        'Text("transaction_editor.currency.fixed_help")',
    ],
}


def main() -> int:
    failures: list[str] = []
    sources = {name: path.read_text(encoding="utf-8") for name, path in FILES.items()}

    for name, snippets in FORBIDDEN.items():
        for snippet in snippets:
            if snippet in sources[name]:
                failures.append(f"{FILES[name].relative_to(ROOT)} contains forbidden snippet: {snippet}")

    for name, snippets in REQUIRED.items():
        for snippet in snippets:
            if snippet not in sources[name]:
                failures.append(f"{FILES[name].relative_to(ROOT)} missing required snippet: {snippet}")

    if failures:
        print("Global format smoke failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Global format smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
