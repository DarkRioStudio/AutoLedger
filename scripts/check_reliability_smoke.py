#!/usr/bin/env python3
"""Static smoke checks for v1.6.2 CSV / JSON backup reliability coverage."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OFFLINE_REGRESSION = ROOT / "scripts/OfflineRegression.swift"
BACKUP_BUNDLE = ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/BackupBundle.swift"
SQLITE_STORE = ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Persistence/SQLiteTransactionStore.swift"
LEDGER_STORE = ROOT / "AutoLedger/AutoLedger/App/LedgerStore.swift"

REQUIRED_OFFLINE_SNIPPETS = [
    "private static func verifyLedgerCSVCodec",
    "LedgerCSVCodec preserves quoted note",
    "LedgerCSVCodec keeps invalid row for review",
    "StructuredLedgerJSONParser auto-saves high confidence JSON",
    "StructuredLedgerJSONParser routes medium confidence JSON to review",
    "private static func verifyBackupRoundTrip",
    "BackupBundle preserves transaction ledger id",
    "BackupBundle preserves hotel stay transaction link",
    "BackupBundle preserves active transaction sync metadata",
    "BackupBundle preserves deleted transaction tombstone",
    "BackupBundle preserves deleted sync tombstone",
    "BackupBundle includes subscription annual price metadata",
    "BackupBundle includes subscription notes metadata",
    "Backup restore keeps active transaction",
    "Backup restore keeps transaction ledger id",
    "Backup restore keeps hotel stay transaction link",
    "Backup restore keeps deleted transaction",
    "Backup restore keeps active sync revision",
    "Backup restore keeps deleted sync tombstone",
    "Backup restore keeps sync idempotency key",
    "Backup restore keeps subscriptions",
    "Backup restore keeps custom categories",
    "Backup restore keeps custom sources",
    "Backup restore keeps merchant aliases",
    "Backup restore keeps category corrections",
    "Backup restore keeps subscription notes metadata",
]

REQUIRED_BACKUP_SNIPPETS = [
    "public let ledgerID: String?",
    "public let hotelStayRecordID: UUID?",
    "public let deletedAt: Date?",
    "public let syncMetadata: TransactionSyncMetadata?",
    "public let subscriptionMetadata: BackupSubscriptionMetadata",
    "public let appSettings: BackupAppSettings",
]

REQUIRED_SQLITE_SNIPPETS = [
    "public func loadBackupTransactions() throws -> [BackupTransaction]",
    "syncMetadata: TransactionSyncMetadata(",
    "public func replaceForRestore(",
    "private func insertBackupTransaction(_ transaction: BackupTransaction) throws",
    "sync_revision",
    "sync_idempotency_key",
    "sync_conflict_state",
]

REQUIRED_LEDGER_SNIPPETS = [
    "func makeBackupBundle() throws -> BackupBundle",
    "try sqlStore.loadBackupTransactions()",
    "func restoreBackup(_ bundle: BackupBundle) throws",
    "try sqlStore.replaceForRestore(",
    "clearCloudKitPushCheckpoint()",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def require_snippets(source: str, snippets: list[str], path: Path, failures: list[str]) -> None:
    for snippet in snippets:
        if snippet not in source:
            failures.append(f"{path.relative_to(ROOT)} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []

    require_snippets(read(OFFLINE_REGRESSION), REQUIRED_OFFLINE_SNIPPETS, OFFLINE_REGRESSION, failures)
    require_snippets(read(BACKUP_BUNDLE), REQUIRED_BACKUP_SNIPPETS, BACKUP_BUNDLE, failures)
    require_snippets(read(SQLITE_STORE), REQUIRED_SQLITE_SNIPPETS, SQLITE_STORE, failures)
    require_snippets(read(LEDGER_STORE), REQUIRED_LEDGER_SNIPPETS, LEDGER_STORE, failures)

    if failures:
        print("Reliability smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Reliability smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
