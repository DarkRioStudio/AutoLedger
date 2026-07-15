#!/usr/bin/env python3
"""Static smoke checks for long-list containers and loading guards."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEDGER_VIEW = ROOT / "AutoLedger/AutoLedger/Features/Ledger/LedgerView.swift"
DELETED_VIEW = ROOT / "AutoLedger/AutoLedger/Features/Ledger/DeletedTransactionsView.swift"
HOTEL_VIEW = ROOT / "AutoLedger/AutoLedger/Features/Hotel/HotelStayArchiveView.swift"
SUBSCRIPTION_VIEW = ROOT / "AutoLedger/AutoLedger/Features/Settings/SubscriptionListView.swift"
IPAD_WORKSPACE = ROOT / "AutoLedger/AutoLedger/Features/iPad/iPadWorkspaceView.swift"

REQUIRED_SNIPPETS = {
    LEDGER_VIEW: [
        "List(selection: $navigationState.selectedLedgerTransactionID)",
        "ForEach(results)",
        ".refreshable",
        ".navigationSplitViewColumnWidth(min: 360, ideal: 430, max: 520)",
        "reconcileSelection(with: visibleIDs)",
    ],
    DELETED_VIEW: [
        "List {",
        "ForEach(store.deletedTransactions)",
        "let snapshot = store.deletedTransactions",
        "store.permanentlyDeleteTransaction(transaction)",
    ],
    HOTEL_VIEW: [
        "List(selection: $selectedRecordID)",
        "private var recordByID: [UUID: HotelStayRecord]",
        "let recordsByID = recordByID",
        "recordsByID[row.id]",
        "ForEach(snapshot.rows)",
        "ForEach(pendingDrafts)",
        ".navigationSplitViewColumnWidth(min: 340, ideal: 420, max: 520)",
    ],
    SUBSCRIPTION_VIEW: [
        "List(selection: $navigationState.selectedSubscriptionID)",
        "ForEach(upcoming)",
        "ForEach(scopedSubscriptions)",
        "onChange(of: scopedSubscriptions.map(\\.id))",
        "navigationState.selectedSubscriptionID = nil",
    ],
    IPAD_WORKSPACE: [
        "private var previewList: some View",
        "@State private var snapshot = DataCleaningPreviewSnapshot()",
        ".task(id: analysisRevision)",
        "await refreshAnalysis()",
        "DataCleaningPreviewPlanner().buildDuplicateCandidates(transactions: transactions)",
        "case .dateDescending:\n            return source",
        "ScrollView {",
        "LazyVStack(alignment: .leading, spacing: 12)",
        "ForEach(DataCleaningPreviewKind.allCases, id: \\.rawValue)",
        "ForEach(kindItems)",
    ],
}

FORBIDDEN_SNIPPETS = {
    HOTEL_VIEW: [
        "records.first(where:",
    ],
    IPAD_WORKSPACE: [
        "private var snapshot: DataCleaningPreviewSnapshot {\n        store.dataCleaningPreviewSnapshot()",
        "case .dateDescending:\n            return source.sorted",
    ],
}


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []

    for path, snippets in REQUIRED_SNIPPETS.items():
        source = read(path)
        for snippet in snippets:
            if snippet not in source:
                failures.append(f"{path.relative_to(ROOT)} missing long-list snippet: {snippet}")

    for path, snippets in FORBIDDEN_SNIPPETS.items():
        source = read(path)
        for snippet in snippets:
            if snippet in source:
                failures.append(f"{path.relative_to(ROOT)} contains forbidden long-list pattern: {snippet}")

    if failures:
        print("Long-list performance smoke check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Long-list performance smoke check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
