#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "AutoLedger" / "AutoLedger"
WORKER = ROOT / "tools" / "worker" / "hotel-folio-inbox"


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []
    client = (APP / "Domain" / "Services" / "HotelFolioInboxClient.swift").read_text(encoding="utf-8")
    worker = (WORKER / "src" / "index.ts").read_text(encoding="utf-8")
    tests = (WORKER / "test" / "hotel-folio-inbox.test.ts").read_text(encoding="utf-8")

    require(client, "case serverEntitlementRequired", "HotelFolioInboxClient", failures)
    require(client, 'serverError?.error == "server_entitlement_required"', "HotelFolioInboxClient", failures)
    require(client, 'String(localized: "hotel_stay.cloud_inbox.error.server_entitlement_required")', "HotelFolioInboxClient", failures)
    if "let message = String(data: data" in client:
        failures.append("HotelFolioInboxClient must not expose raw server response bodies")

    require(worker, "appStoreServerLookupEnvironments(config.environment, clientPayload)", "hotel-folio-inbox Worker", failures)
    require(worker, 'rawEnvironment === "sandbox" || rawEnvironment === "production"', "hotel-folio-inbox Worker", failures)
    require(tests, 'environment: "Sandbox"', "hotel-folio-inbox tests", failures)
    require(tests, 'environment: "Production"', "hotel-folio-inbox tests", failures)

    for locale in ["zh-Hans", "zh-Hant", "en", "ja", "ko"]:
        strings = (APP / f"{locale}.lproj" / "Localizable.strings").read_text(encoding="utf-8")
        require(
            strings,
            '"hotel_stay.cloud_inbox.error.server_entitlement_required"',
            f"{locale} Localizable.strings",
            failures,
        )

    if failures:
        print("Cloud inbox entitlement smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Cloud inbox entitlement smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
