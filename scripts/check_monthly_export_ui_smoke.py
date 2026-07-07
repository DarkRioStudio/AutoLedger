#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []
    report = (APP / "Features" / "Report" / "ReportView.swift").read_text(encoding="utf-8")
    store = (APP / "App" / "LedgerStore.swift").read_text(encoding="utf-8")

    require(report, "monthlyExportSection", "ReportView", failures)
    require(report, "proEntitlement.canUse(.monthlyExportPackage)", "ReportView", failures)
    require(report, "AutoLedgerProView()", "ReportView", failures)
    require(report, "ActivityShareSheet(activityItems:", "ReportView", failures)
    require(report, '"report.monthly_export.title"', "ReportView", failures)
    require(report, '"report.monthly_export.redact_toggle"', "ReportView", failures)
    require(store, "writeMonthlyExportPackage", "LedgerStore", failures)
    require(store, "MonthlyExportPackageBuilder", "LedgerStore", failures)
    require(store, "renderMonthlyExportPDF", "LedgerStore", failures)
    require(store, 'replacingOccurrences(of: ".md", with: ".pdf")', "LedgerStore", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        for key in [
            "report.monthly_export.title",
            "report.monthly_export.body_format",
            "report.monthly_export.redact_toggle",
            "report.monthly_export.export_action",
            "report.monthly_export.pro.action",
            "report.monthly_export.accessibility_label",
            "report.monthly_export.status_ready_format",
            "report.monthly_export.status_failed_format",
        ]:
            require(strings, f'"{key}"', f"{locale} Localizable.strings", failures)

    if failures:
        print("Monthly export UI smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Monthly export UI smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
