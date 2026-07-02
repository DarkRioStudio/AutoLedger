#!/usr/bin/env python3
"""Validate that localized .strings files match the baseline key set."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

RESOURCE_SETS = [
    "AutoLedger/AutoLedger",
    "AutoLedger/AutoLedgerWatch Watch App",
    "AutoLedger/AutoLedgerWatchWidgetsExtension",
    "AutoLedger/ControlWidgetExtension",
    "AutoLedger/ShareExtension",
]

BASELINE_LOCALE = "en"
REQUIRED_LOCALES = ["zh-Hans", "zh-Hant", "en", "ja", "ko"]
STRING_FILE_PATTERN = re.compile(r'^\s*"((?:[^"\\]|\\.)+)"\s*=')

MAIN_APP_REQUIRED_KEYS = {
    "hotel_folio.import.error.unsupported_file",
    "hotel_folio.import.error.cannot_open_pdf",
    "hotel_folio.import.error.empty_text",
    "hotel_stay.review.title",
    "hotel_stay.review.hotel_name",
    "hotel_stay.review.total",
    "hotel_stay.review.validation.required",
    "hotel_stay.list.title",
    "hotel_stay.list.empty.title",
    "hotel_stay.detail.title",
    "hotel_stay.detail.linked_transaction",
    "hotel_stay.detail.raw_text",
    "settings.ledger_profiles.title",
    "settings.ledger_profiles.subtitle",
    "ledger_profiles.title",
    "ledger_profiles.add",
    "ledger_profiles.action.rename",
    "ledger_profiles.action.set_default",
    "ledger_profiles.action.archive",
    "ledger.scope.all",
    "ledger.action.move",
    "ledger.move.title",
    "ledger.move.error.unavailable_target",
    "ledger.move.error.not_found",
    "ledger.move.error.persistence_failed_format",
    "ledger.move.success_format",
}

MAIN_APP_REQUIRED_PREFIX_COUNTS = {
    "hotel_stay.": 60,
    "hotel_folio.import.error.": 3,
    "ledger_profiles.": 14,
}


def collect_strings_files(resource_root: Path) -> set[str]:
    names: set[str] = set()
    for locale_dir in resource_root.glob("*.lproj"):
        if locale_dir.is_dir():
            names.update(path.name for path in locale_dir.glob("*.strings"))
    return names


def read_keys(path: Path) -> set[str]:
    keys: set[str] = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        match = STRING_FILE_PATTERN.match(line)
        if match:
            keys.add(match.group(1))
    return keys


def main() -> int:
    failures: list[str] = []

    for relative_root in RESOURCE_SETS:
        resource_root = ROOT / relative_root
        strings_files = collect_strings_files(resource_root)
        if not strings_files:
            failures.append(f"{relative_root}: no .strings files found")
            continue

        for strings_file in sorted(strings_files):
            baseline_path = resource_root / f"{BASELINE_LOCALE}.lproj" / strings_file
            if not baseline_path.exists():
                failures.append(f"{relative_root}: missing baseline {baseline_path.relative_to(ROOT)}")
                continue

            baseline_keys = read_keys(baseline_path)
            for locale in REQUIRED_LOCALES:
                localized_path = resource_root / f"{locale}.lproj" / strings_file
                if not localized_path.exists():
                    failures.append(f"{relative_root}: missing {localized_path.relative_to(ROOT)}")
                    continue

                localized_keys = read_keys(localized_path)
                missing = sorted(baseline_keys - localized_keys)
                extra = sorted(localized_keys - baseline_keys)
                if missing:
                    sample = ", ".join(missing[:8])
                    failures.append(
                        f"{localized_path.relative_to(ROOT)}: missing {len(missing)} keys"
                        f" (sample: {sample})"
                    )
                if extra:
                    sample = ", ".join(extra[:8])
                    failures.append(
                        f"{localized_path.relative_to(ROOT)}: has {len(extra)} extra keys"
                        f" (sample: {sample})"
                    )

                if relative_root == "AutoLedger/AutoLedger" and strings_file == "Localizable.strings":
                    missing_required = sorted(MAIN_APP_REQUIRED_KEYS - localized_keys)
                    if missing_required:
                        sample = ", ".join(missing_required[:8])
                        failures.append(
                            f"{localized_path.relative_to(ROOT)}: missing required v1.6.1 feature keys"
                            f" (sample: {sample})"
                        )

                    for prefix, minimum_count in MAIN_APP_REQUIRED_PREFIX_COUNTS.items():
                        matched_count = sum(1 for key in localized_keys if key.startswith(prefix))
                        if matched_count < minimum_count:
                            failures.append(
                                f"{localized_path.relative_to(ROOT)}: expected at least {minimum_count}"
                                f" keys with prefix {prefix!r}, found {matched_count}"
                            )

    if failures:
        print("Localization coverage check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("Localization coverage check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
