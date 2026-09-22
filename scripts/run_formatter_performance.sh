#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/autoledger-formatters.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT
swiftc -O -swift-version 6 -strict-concurrency=complete \
  "$ROOT/AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Utils/AppFormatters.swift" \
  "$ROOT/scripts/FormatterPerformance.swift" -o "$TMP_DIR/benchmark"
"$TMP_DIR/benchmark"
