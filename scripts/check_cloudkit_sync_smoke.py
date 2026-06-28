#!/usr/bin/env python3
"""Static smoke checks for CloudKit sync pull paths."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift"
STORE = ROOT / "AutoLedger/AutoLedger/App/LedgerStore.swift"
RUNNER = ROOT / "scripts/run_offline_regression.sh"


REQUIRED_SNIPPETS = [
    "LedgerCloudSyncManifest",
    "syncManifestRecordName()",
    "fetchSyncManifest()",
    "pushSyncManifest(",
    "CKFetchRecordsOperation(recordIDs:",
    "fetchRecordsByID(",
    "transactionRecordNames",
    "hotelStayRecordNames",
    "hotelStayDraftRecordNames",
]

REQUIRED_STORE_SNIPPETS = [
    "sqliteStoreForCloudSync()",
    "当前同步状态未持有 SQLite 实例，正在重新打开默认本地账本。",
]

FORBIDDEN_SNIPPETS = [
    "CKFetchRecordZoneChangesOperation",
    "CKRecordZone.default().zoneID",
    "CKQueryOperation(query:",
    "CKQuery(",
    "NSPredicate(value: true)",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    try:
        adapter = read(ADAPTER)
        store = read(STORE)
        runner = read(RUNNER)
    except FileNotFoundError as exc:
        print(f"missing required file: {exc}")
        return 1

    for snippet in REQUIRED_SNIPPETS:
        if snippet not in adapter:
            failures.append(f"missing CloudKit change-feed snippet: {snippet}")

    for snippet in REQUIRED_STORE_SNIPPETS:
        if snippet not in store:
            failures.append(f"missing LedgerStore CloudKit SQLite recovery snippet: {snippet}")

    for snippet in FORBIDDEN_SNIPPETS:
        if snippet in adapter:
            failures.append(f"CloudKit sync adapter still uses query-based pull snippet: {snippet}")

    if "iCloud 同步需要 SQLite 账本。" in store:
        failures.append("LedgerStore still exposes SQLite store absence as a terminal iCloud sync status")

    if "check_cloudkit_sync_smoke.py" not in runner:
        failures.append("offline regression does not run CloudKit sync smoke")

    if failures:
        print("CloudKit sync smoke failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("CloudKit sync smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
