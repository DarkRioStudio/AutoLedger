#!/usr/bin/env python3
"""Guard hotel folio PDF sync so binary PDFs travel as CKAsset, not JSON base64."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift"
LEDGER_STORE = ROOT / "AutoLedger/AutoLedger/App/LedgerStore.swift"
SCHEMA = ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/LedgerSyncPlan.swift"
RUNNER = ROOT / "scripts/run_offline_regression.sh"

REQUIRED_ADAPTER_SNIPPETS = [
    "case assetData(",
    "CKAsset(fileURL:",
    "sourcePDFData: nil",
    "assetData(from:",
    "sourcePDFData: assetData",
    "retryHotelStayArchiveChunkWithoutPDFAssets",
    "removingHotelPDFAssets",
    "shouldRetryHotelStayArchiveWithoutPDFAssets",
]

REQUIRED_LEDGER_STORE_SNIPPETS = [
    "mergeHotelStayRecordPreservingLocalPDF",
    "mergeHotelStayDraftPreservingLocalPDF",
]

FORBIDDEN_LEDGER_STORE_SNIPPETS = [
    "酒店 PDF 附件暂未被 CloudKit 接收",
]

REQUIRED_SCHEMA_SNIPPETS = [
    'public static let sourcePDFAsset = "sourcePDFAsset"',
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def function_body(source: str, name: str) -> str:
    match = re.search(rf"private static func {re.escape(name)}\b", source)
    if not match:
        return ""
    start = match.start()
    brace = source.find("{", start)
    if brace == -1:
        return ""
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[start : index + 1]
    return ""


def main() -> int:
    failures: list[str] = []
    try:
        adapter = read(ADAPTER)
        ledger_store = read(LEDGER_STORE)
        schema = read(SCHEMA)
        runner = read(RUNNER)
    except FileNotFoundError as exc:
        print(f"missing required file: {exc}")
        return 1

    for snippet in REQUIRED_ADAPTER_SNIPPETS:
        if snippet not in adapter:
            failures.append(f"missing hotel PDF asset adapter snippet: {snippet}")

    for snippet in REQUIRED_LEDGER_STORE_SNIPPETS:
        if snippet not in ledger_store:
            failures.append(f"missing hotel PDF pull merge snippet: {snippet}")

    for snippet in FORBIDDEN_LEDGER_STORE_SNIPPETS:
        if snippet in ledger_store:
            failures.append(f"hotel PDF asset fallback should not be user-visible: {snippet}")

    for snippet in REQUIRED_SCHEMA_SNIPPETS:
        if snippet not in schema:
            failures.append(f"missing hotel PDF asset schema snippet: {snippet}")

    record_mapper = function_body(adapter, "mapHotelStayRecord")
    draft_mapper = function_body(adapter, "mapHotelStayDraft")
    for name, body in [
        ("mapHotelStayRecord", record_mapper),
        ("mapHotelStayDraft", draft_mapper),
    ]:
        if "payloadJSON" not in body or "sourcePDFData: nil" not in body:
            failures.append(f"{name} does not strip sourcePDFData before payloadJSON encoding")
        if "sourcePDFAsset" not in body or ".assetData(" not in body:
            failures.append(f"{name} does not attach sourcePDFAsset as asset data")

    if "check_cloudkit_hotel_pdf_asset_smoke.py" not in runner:
        failures.append("offline regression does not run hotel PDF asset smoke")

    if failures:
        print("CloudKit hotel PDF asset smoke failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("CloudKit hotel PDF asset smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
