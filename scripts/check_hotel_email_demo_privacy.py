#!/usr/bin/env python3
"""Guard the hotel email Demo Mode fixture and review notes against real secrets."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

FILES = [
    ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/HotelFolioEmailImportPlanning.swift",
    ROOT / "AutoLedger/AutoLedger/Domain/Services/HotelFolioEmailImportService.swift",
    ROOT / "versions/v1.6.2-hotel-email-review-notes.md",
]

DEMO_MATERIAL_FILES = [
    ROOT / "AutoLedger/AutoLedgerCore/Sources/AutoLedgerCore/Services/HotelFolioEmailImportPlanning.swift",
    ROOT / "versions/v1.6.2-hotel-email-review-notes.md",
]

REQUIRED_SNIPPETS = [
    "example.test",
    "DEMO-2026-0618",
    "HotelFolioEmailDemoMode.isAvailable",
    "without a real email account",
]

FORBIDDEN_SNIPPETS = [
    "@qq.com",
    "@gmail.com",
    "@icloud.com",
    "@outlook.com",
    "@hotmail.com",
    "@163.com",
    "@126.com",
]

FORBIDDEN_PATTERNS = [
    (re.compile(r"(?i)\bpassword\s*[:=]\s*[^\s`]+"), "plain password-like token"),
    (re.compile(r"\b(?:\d[ -]?){13,19}\b"), "full payment card-like number"),
]


def main() -> int:
    failures: list[str] = []
    combined_parts: list[str] = []
    for path in FILES:
        if not path.exists():
            failures.append(f"missing required file: {path.relative_to(ROOT)}")
            continue
        combined_parts.append(path.read_text(encoding="utf-8"))

    combined = "\n".join(combined_parts)
    demo_material = "\n".join(
        path.read_text(encoding="utf-8")
        for path in DEMO_MATERIAL_FILES
        if path.exists()
    )
    for snippet in REQUIRED_SNIPPETS:
        if snippet not in combined:
            failures.append(f"missing required demo/privacy snippet: {snippet}")

    for snippet in FORBIDDEN_SNIPPETS:
        if snippet.lower() in combined.lower():
            failures.append(f"forbidden real mailbox domain appears in demo material: {snippet}")

    for pattern, label in FORBIDDEN_PATTERNS:
        match = pattern.search(demo_material)
        if match:
            failures.append(f"found {label}: {match.group(0)}")

    if failures:
        print("Hotel email demo privacy check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Hotel email demo privacy check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
