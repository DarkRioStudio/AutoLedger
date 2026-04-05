#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TMP_BIN="$(mktemp /tmp/autoledger-offline-regression.XXXXXX)"
trap 'rm -f "$TMP_BIN"' EXIT

swiftc \
  -o "$TMP_BIN" \
  -lsqlite3 \
  "$ROOT/AutoLedger/AutoLedger/Domain/Enums/ReceiptSource.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Enums/TransactionCategory.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Models/ImportedReceipt.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Models/ImportDebugRecord.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Models/SampleReceipt.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Models/MonthlySnapshot.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Models/Transaction.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift" \
  "$ROOT/AutoLedger/AutoLedger/Domain/Services/SampleReceiptProvider.swift" \
  "$ROOT/AutoLedger/AutoLedger/Data/Persistence/TransactionStore.swift" \
  "$ROOT/AutoLedger/AutoLedger/Data/Persistence/SQLiteTransactionStore.swift" \
  "$ROOT/AutoLedger/AutoLedger/App/LedgerStore.swift" \
  "$ROOT/AutoLedger/AutoLedger/Shared/Utils/AppFormatters.swift" \
  "$ROOT/scripts/OfflineRegression.swift"

"$TMP_BIN"
