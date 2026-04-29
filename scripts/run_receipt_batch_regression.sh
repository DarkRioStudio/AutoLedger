#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INPUT="${1:-}"
OUTPUT="${2:-.tmp/receipt_ocr/receipt_batch.parse.jsonl}"
REPORT="${3:-}"

if [[ -z "$INPUT" ]]; then
  echo "Usage: bash scripts/run_receipt_batch_regression.sh <ocr.jsonl> [parse.jsonl] [report.md]" >&2
  exit 2
fi

CORE="$ROOT/AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore"
TMP_BIN="$(mktemp /tmp/autoledger-receipt-batch.XXXXXX)"
trap 'rm -f "$TMP_BIN"' EXIT

swiftc \
  -o "$TMP_BIN" \
  "$CORE/Enums/ReceiptSource.swift" \
  "$CORE/Enums/TransactionCategory.swift" \
  "$CORE/Models/ImportedReceipt.swift" \
  "$CORE/Models/LedgerInterpretationModels.swift" \
  "$CORE/Services/VoiceLedgerParser.swift" \
  "$CORE/Services/BillRelevanceGate.swift" \
  "$CORE/Services/LedgerTextInterpreterCore.swift" \
  "$ROOT/tools/receipt_ocr/batch_parse.swift"

"$TMP_BIN" "$INPUT" "$OUTPUT"

if [[ -n "$REPORT" ]]; then
  echo "Generating Markdown report..."
  TMP_REPORT_BIN="$(mktemp /tmp/autoledger-batch-report.XXXXXX)"
  trap 'rm -f "$TMP_REPORT_BIN" "$TMP_BIN"' EXIT
  swiftc \
    -o "$TMP_REPORT_BIN" \
    "$CORE/Enums/TransactionCategory.swift" \
    "$CORE/Models/LedgerInterpretationModels.swift" \
    "$CORE/Services/LedgerTextInterpreterCore.swift" \
    "$ROOT/tools/receipt_ocr/batch_report.swift" 2>/dev/null || \
  swiftc \
    -o "$TMP_REPORT_BIN" \
    "$ROOT/tools/receipt_ocr/batch_report.swift"
  "$TMP_REPORT_BIN" "$OUTPUT" "$REPORT"
  echo "Report: $REPORT"
fi
