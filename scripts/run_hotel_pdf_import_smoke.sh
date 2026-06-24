#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_BIN="$(mktemp /tmp/autoledger-hotel-pdf-import-smoke.XXXXXX)"
PREP_DIR="$(mktemp -d /tmp/autoledger-hotel-pdf-import-prep.XXXXXX)"
trap 'rm -f "$TMP_BIN"; rm -rf "$PREP_DIR"' EXIT

CORE="$ROOT/AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore"
SERVICE="$ROOT/AutoLedger/AutoLedger/Domain/Services/HotelFolioManualPDFImporter.swift"

sed '/import AutoLedgerCore/d' "$SERVICE" > "$PREP_DIR/HotelFolioManualPDFImporter.swift"

swiftc \
  -o "$TMP_BIN" \
  -framework AppKit \
  -framework PDFKit \
  "$CORE/Enums/ReceiptSource.swift" \
  "$CORE/Enums/TransactionCategory.swift" \
  "$CORE/Models/TodaySpendingSummary.swift" \
  "$CORE/Models/Transaction.swift" \
  "$CORE/Models/HotelStay.swift" \
  "$PREP_DIR/HotelFolioManualPDFImporter.swift" \
  "$ROOT/scripts/HotelFolioPDFImportSmoke.swift"

"$TMP_BIN"
