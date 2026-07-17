#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "appstore-screenshots"
CONFIG = TOOL / "config" / "screenshots.json"
REQUIRED_LOCALES = ("zh-Hans", "zh-Hant", "en", "ja", "ko")
SHOT_GROUPS = (
    "iosShots",
    "ipadShots",
    "macShots",
    "watchShots",
    "tvosShots",
    "visionosShots",
)
EXPECTED_SHOT_COUNT = 30


def require(text: str, snippet: str, label: str, failures: list[str]) -> None:
    if snippet not in text:
        failures.append(f"{label} missing snippet: {snippet}")


def main() -> int:
    failures: list[str] = []

    if not CONFIG.exists():
        print(f"Screenshot localization smoke failed:\n - missing {CONFIG.relative_to(ROOT)}")
        return 1

    try:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError) as error:
        print(f"Screenshot localization smoke failed:\n - cannot read config: {error}")
        return 1

    locales = config.get("locales", {})
    for locale in REQUIRED_LOCALES:
        if locale not in locales:
            failures.append(f"screenshots.json missing locale: {locale}")

    korean = locales.get("ko", {})
    if korean.get("appleLanguages") != "(ko)":
        failures.append("ko appleLanguages must be (ko)")
    if korean.get("appleLocale") != "ko_KR":
        failures.append("ko appleLocale must be ko_KR")

    total_shots = 0
    for group in SHOT_GROUPS:
        shots = config.get(group)
        if not isinstance(shots, list) or not shots:
            failures.append(f"screenshots.json missing non-empty group: {group}")
            continue

        total_shots += len(shots)
        ids = [shot.get("id") for shot in shots if isinstance(shot, dict)]
        if len(ids) != len(set(ids)):
            failures.append(f"{group} contains duplicate shot IDs")

        for index, shot in enumerate(shots):
            shot_id = shot.get("id", f"index {index}") if isinstance(shot, dict) else f"index {index}"
            if not isinstance(shot, dict):
                failures.append(f"{group}/{shot_id} must be an object")
                continue
            for field in ("title", "subtitle"):
                translations = shot.get(field)
                if not isinstance(translations, dict):
                    failures.append(f"{group}/{shot_id} missing {field} translations")
                    continue
                for locale in REQUIRED_LOCALES:
                    value = translations.get(locale)
                    if not isinstance(value, str) or not value.strip():
                        failures.append(f"{group}/{shot_id} missing non-empty {field}.{locale}")

    if total_shots != EXPECTED_SHOT_COUNT:
        failures.append(
            f"expected {EXPECTED_SHOT_COUNT} configured shots across six platforms, found {total_shots}"
        )

    render_script = (TOOL / "scripts" / "render_marketing.py").read_text(encoding="utf-8")
    for snippet in [
        'locale == "ko"',
        "AppleSDGothicNeo.ttc",
        '6 if weight == "bold" else 0',
        'font(34, "bold", locale)',
        'font(35, "regular", locale)',
    ]:
        require(render_script, snippet, "render_marketing.py", failures)

    export_script = (TOOL / "scripts" / "export.sh").read_text(encoding="utf-8")
    require(export_script, "ko", "export.sh", failures)

    readme = (TOOL / "README.md").read_text(encoding="utf-8")
    for snippet in ["--locale ko", "output/raw/watch/ko/", "output/store/{platform}/ko/"]:
        require(readme, snippet, "screenshot README", failures)

    asc_metadata = (ROOT / "tools" / "asc-metadata" / "metadata.yml").read_text(encoding="utf-8")
    require(asc_metadata, "planned_locales:", "ASC metadata", failures)
    require(asc_metadata, '  - "ko"', "ASC metadata", failures)

    app_copy_sources = {
        "iOS screenshot copy": ROOT / "AutoLedger" / "AutoLedger" / "Screenshots" / "ScreenshotHostView.swift",
        "Watch screenshot copy": ROOT / "AutoLedger" / "AutoLedgerWatch Watch App" / "Screenshots" / "WatchScreenshotHostView.swift",
        "tvOS screenshot copy": ROOT / "AutoLedger" / "AutoLedgerTV" / "ContentView.swift",
        "visionOS screenshot copy": ROOT / "AutoLedger" / "AutoLedgerVision" / "ContentView.swift",
    }
    required_korean_markers = {
        "iOS screenshot copy": ["locale.hasPrefix(\"ko\")", "결제 스크린샷 인식", "손목에서 빠르게 기록"],
        "Watch screenshot copy": ["locale.hasPrefix(\"ko\")", "빠른 기록", "시계 페이스"],
        "tvOS screenshot copy": ["locale.hasPrefix(\"ko\")", 'case \"ko\": return \"ko_KR\"', "거실 대화면 읽기 전용 장부"],
        "visionOS screenshot copy": ["locale.hasPrefix(\"ko\")", 'case \"ko\": return \"ko_KR\"', "월간 지출 공간 대시보드"],
    }
    for label, path in app_copy_sources.items():
        source = path.read_text(encoding="utf-8")
        for snippet in required_korean_markers[label]:
            require(source, snippet, label, failures)

    if failures:
        print("Screenshot localization smoke failed:")
        for failure in failures:
            print(f" - {failure}")
        return 1

    print("Screenshot localization smoke passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
