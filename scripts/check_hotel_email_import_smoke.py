#!/usr/bin/env python3
"""Guard the hotel email import flow against Demo Mode regressions."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

VIEW = ROOT / "AutoLedger/AutoLedger/Features/Hotel/HotelFolioEmailImportView.swift"
SERVICE = ROOT / "AutoLedger/AutoLedger/Domain/Services/HotelFolioEmailImportService.swift"
PLANNING = ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/HotelFolioEmailImportPlanning.swift"
RUNNER = ROOT / "scripts/run_offline_regression.sh"
LOCALIZATION_FILES = sorted((ROOT / "AutoLedger/AutoLedger").glob("*.lproj/Localizable.strings"))

REQUIRED_VIEW_SNIPPETS = [
    "selectedAttachmentIDs",
    "selectedAttachmentPairs",
    "importSelectedAttachments()",
    "onDraftsReady: ([HotelStayDraft]) -> Void",
    "recordEmailScanDebug(",
    "handleScanProgress(",
    "checkmark.square.fill",
    "phoneSearchDays = 30",
    "phoneMaxMessages = 100",
    "shouldShowScanScopeFields",
    "macScanScopeFields",
    "effectiveScanScopeSettings(from:",
]

REQUIRED_SERVICE_SNIPPETS = [
    "HotelFolioEmailScanProgress",
    "HotelFolioEmailScanPhase",
    "operationTimeoutSeconds",
    "withIMAPTimeout(operation:",
    "HotelFolioIMAPResponseScanner",
    "HotelFolioIMAPTaggedResponse",
    "isTaggedResponseComplete",
    "literalLength(in:",
    "taggedCompletionLine(in data: Data",
    "safeSummary(of:",
    # RFC 7888/IMAP servers may return synchronizing, non-synchronizing,
    # or literal8 markers. Fetch extraction must understand those markers.
    # Keep this exact pattern guarded because QQ/other IMAP providers vary.
    r'#"(?:~)?\{(\d+)\+?\}\r?\n"#',
    "hotel_stay.email.error.invalid_response_format",
    "UID SEARCH SINCE",
    "UID SEARCH ALL",
    "hotelFolioCandidateMessage(",
    "HotelFolioTextPDFBuilder.makePDFData(",
    "email-body-folio.pdf",
    "settings.maxMessages > 0 && candidates.count >= settings.maxMessages",
    "扫描时间窗内全部邮件",
    "readResponse(tag: String) async throws -> HotelFolioIMAPTaggedResponse",
    ".candidateAccepted(subject:",
    ".completed(candidates.count)",
]

FORBIDDEN_SERVICE_SNIPPETS = [
    "searchHotelCandidateUIDs(since:",
    "candidateSearchCriteria",
    "mergeCandidateUIDs(",
    "keywordSearching",
    "keywordSearchCompleted",
]

FORBIDDEN_SNIPPETS = [
    "HotelFolioEmailDemoMode",
    "HotelFolioEmailDemoFixture",
    "demoSection",
    "loadDemoMode",
    "hotel_stay.email.section.demo",
    "hotel_stay.email.demo_load",
    "hotel_stay.email.demo_footer",
    "hotel_stay.email.status.demo_loaded",
    "autoledger-demo-hotel-folio.pdf",
    "folio-\\(uid)-\\(index).pdf",
]


def read(path: Path) -> str:
    if not path.exists():
        raise FileNotFoundError(path)
    return path.read_text(encoding="utf-8")


def main() -> int:
    failures: list[str] = []
    try:
        view = read(VIEW)
        service = read(SERVICE)
        planning = read(PLANNING)
        runner = read(RUNNER)
        l10n = "\n".join(read(path) for path in LOCALIZATION_FILES)
    except FileNotFoundError as exc:
        print(f"missing required file: {exc}")
        return 1

    combined = "\n".join([view, service, planning, runner, l10n])

    for snippet in REQUIRED_VIEW_SNIPPETS:
        if snippet not in view:
            failures.append(f"missing hotel email batch UI snippet: {snippet}")

    for snippet in REQUIRED_SERVICE_SNIPPETS:
        if snippet not in service:
            failures.append(f"missing hotel email scan reliability snippet: {snippet}")

    for snippet in FORBIDDEN_SERVICE_SNIPPETS:
        if snippet in service:
            failures.append(f"keyword-scoped hotel email scan snippet still present: {snippet}")

    if "check_hotel_email_import_smoke.py" not in runner:
        failures.append("offline regression does not run hotel email import smoke")
    if "check_hotel_email_demo_privacy.py" in runner:
        failures.append("offline regression still runs removed Demo Mode privacy check")

    for snippet in FORBIDDEN_SNIPPETS:
        if snippet in combined:
            failures.append(f"removed Demo Mode snippet still present: {snippet}")

    if failures:
        print("Hotel email import smoke failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Hotel email import smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
