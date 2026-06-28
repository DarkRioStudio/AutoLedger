#!/usr/bin/env python3
"""Static smoke checks for CloudKit sync pull paths."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADAPTER = ROOT / "AutoLedger/AutoLedger/Domain/Services/LedgerCloudKitSyncAdapter.swift"
RUNNER = ROOT / "scripts/run_offline_regression.sh"


REQUIRED_SNIPPETS = [
    "CKFetchRecordZoneChangesOperation",
    "CKRecordZone.default().zoneID",
    "fetchDefaultZonePayloads(",
    "isRecoverableZoneChangePartialFailure(",
    "CKError.Code.partialFailure",
    "continuation.resume(returning: records)",
]

FORBIDDEN_SNIPPETS = [
    "CKQueryOperation(query:",
    "CKQuery(",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    try:
        adapter = read(ADAPTER)
        runner = read(RUNNER)
    except FileNotFoundError as exc:
        print(f"missing required file: {exc}")
        return 1

    for snippet in REQUIRED_SNIPPETS:
        if snippet not in adapter:
            failures.append(f"missing CloudKit change-feed snippet: {snippet}")

    for snippet in FORBIDDEN_SNIPPETS:
        if snippet in adapter:
            failures.append(f"CloudKit sync adapter still uses query-based pull snippet: {snippet}")

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
