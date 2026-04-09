#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

TMP_BIN="$(mktemp /tmp/autoledger-offline-regression.XXXXXX)"
trap 'rm -f "$TMP_BIN"' EXIT

CORE="$ROOT/AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore"

# LedgerStore has 'import AutoLedgerCore' which doesn't exist as a module in flat compilation.
# Also depends on SmartReceiptParser (Foundation Models) — stub it out for offline use.
PREP_DIR="$(mktemp -d /tmp/autoledger-prep.XXXXXX)"
trap 'rm -f "$TMP_BIN"; rm -rf "$PREP_DIR"' EXIT
sed '/import AutoLedgerCore/d' "$ROOT/AutoLedger/AutoLedger/App/LedgerStore.swift" > "$PREP_DIR/LedgerStore.swift"

cat > "$PREP_DIR/SmartReceiptParserStub.swift" << 'STUB'
import Foundation
struct SmartReceiptParser {
    struct LLMTrace { let prompt: String; let response: String }
    func parse(text: String, source: ReceiptSource, fallbackMerchant: String? = nil) async -> (receipt: ImportedReceipt, llmTrace: LLMTrace?)? { return nil }
}
STUB

swiftc \
  -o "$TMP_BIN" \
  -lsqlite3 \
  "$CORE/Enums/ReceiptSource.swift" \
  "$CORE/Enums/TransactionCategory.swift" \
  "$CORE/Models/ImportedReceipt.swift" \
  "$CORE/Models/ImportDebugRecord.swift" \
  "$CORE/Models/SampleReceipt.swift" \
  "$CORE/Models/MonthlySnapshot.swift" \
  "$CORE/Models/Transaction.swift" \
  "$CORE/Services/ReceiptParser.swift" \
  "$CORE/Services/SampleReceiptProvider.swift" \
  "$CORE/Persistence/TransactionStore.swift" \
  "$CORE/Persistence/SQLiteTransactionStore.swift" \
  "$PREP_DIR/LedgerStore.swift" \
  "$PREP_DIR/SmartReceiptParserStub.swift" \
  "$CORE/Utils/AppFormatters.swift" \
  "$ROOT/scripts/OfflineRegression.swift"

"$TMP_BIN"
