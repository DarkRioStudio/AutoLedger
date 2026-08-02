#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Models/LedgerUserSyncStatus.swift"
STORE = ROOT / "AutoLedger/AutoLedger/App/LedgerStore.swift"
DATA_MANAGEMENT = ROOT / "AutoLedger/AutoLedger/Features/Settings/DataManagementView.swift"
DEBUG_VIEW = ROOT / "AutoLedger/AutoLedger/Features/Settings/DebugView.swift"
LOCALES = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]


def require(source: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in source:
        failures.append(f"{label} missing: {snippet}")


def main() -> int:
    failures: list[str] = []
    model = MODEL.read_text(encoding="utf-8")
    store = STORE.read_text(encoding="utf-8")
    data_management = DATA_MANAGEMENT.read_text(encoding="utf-8")
    debug_view = DEBUG_VIEW.read_text(encoding="utf-8")

    for state in [
        "disabled",
        "checkingAccount",
        "syncing",
        "waitingToUpload",
        "upToDate",
        "offline",
        "needsConflictReview",
        "failedWithLocalDataSafe",
    ]:
        require(model, f"case {state}", "LedgerUserSyncStatus", failures)
        key = f'"data_management.cloudkit_state.{state}.title"'
        for locale in LOCALES:
            strings = (
                ROOT / f"AutoLedger/AutoLedger/{locale}.lproj/Localizable.strings"
            ).read_text(encoding="utf-8")
            require(strings, key, f"{locale} localization", failures)

    for snippet in [
        "@Published private(set) var ledgerUserSyncStatus",
        "updateLedgerUserSyncStatus(.checkingAccount)",
        "updateLedgerUserSyncStatus(.waitingToUpload)",
        "userFacingFailureState(for: error)",
        "recordCloudKitSyncSuccess",
    ]:
        require(store, snippet, "LedgerStore", failures)

    require(data_management, "cloudKitUserStatusSection", "DataManagementView", failures)
    require(
        data_management,
        "data_management.cloudkit_last_success_format",
        "DataManagementView",
        failures,
    )
    if "ledgerCloudSyncLog" in data_management:
        failures.append("DataManagementView still exposes developer CloudKit phase logs")
    require(debug_view, "ledgerCloudSyncLog", "DebugView", failures)

    if failures:
        print("Human-readable sync status smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Human-readable sync status smoke passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
