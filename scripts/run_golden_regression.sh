#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${1:-$ROOT/tests/golden/ledger_text_interpreter/cases.jsonl}"
CORE="$ROOT/AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore"
TMP_BIN="$(mktemp /tmp/autoledger-golden.XXXXXX)"
PREP_DIR="$(mktemp -d /tmp/autoledger-golden-prep.XXXXXX)"
trap 'rm -f "$TMP_BIN"; rm -rf "$PREP_DIR"' EXIT

sed '/import AutoLedgerCore/d' "$ROOT/AutoLedger/AutoLedger/Domain/Services/ReceiptParser.swift" > "$PREP_DIR/ReceiptParser.swift"

swiftc \
  -o "$TMP_BIN" \
  "$CORE/Enums/ReceiptSource.swift" \
  "$CORE/Enums/TransactionCategory.swift" \
  "$CORE/Models/ImportedReceipt.swift" \
  "$CORE/Models/SampleReceipt.swift" \
  "$CORE/Models/LedgerInterpretationModels.swift" \
  "$CORE/Utils/AppFormatters.swift" \
  "$CORE/Services/SampleReceiptProvider.swift" \
  "$PREP_DIR/ReceiptParser.swift" \
  "$CORE/Services/VoiceLedgerParser.swift" \
  "$CORE/Services/LedgerRecognitionLanguagePack.swift" \
  "$CORE/Services/LedgerDateCandidateExtractor.swift" \
  "$CORE/Services/BillRelevanceGate.swift" \
  "$CORE/Services/PaymentAmountExtractor.swift" \
  "$CORE/Services/MerchantResolver.swift" \
  "$CORE/Services/CategoryResolver.swift" \
  "$CORE/Services/LedgerTextInterpreterCore.swift" \
  "$ROOT/tools/receipt_ocr/golden_regression.swift"

"$TMP_BIN" "$CASES"
