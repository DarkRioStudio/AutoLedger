#!/usr/bin/env python3
"""Static contract checks for the ASC 1.6.0 five-locale App Preview project."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "tools/appstore-screenshots/app-preview/hyperframes-v003"
EXPECTED_LOCALES = ("en-US", "zh-Hans", "zh-Hant", "ja", "ko")
EXPECTED_SCENES = ("ocr", "voice", "hotel", "watch", "report", "pro")
EXPECTED_STARTS = (0.0, 3.15, 6.52, 9.88, 13.24, 16.62)


def require(condition: bool, message: str, failures: list[str]) -> None:
    if not condition:
        failures.append(message)


def inspect_optional_renders(failures: list[str]) -> None:
    ffprobe = shutil.which("ffprobe")
    final_dir = PROJECT / "renders/final"
    renders = [
        final_dir / f"app_preview_iphone_{locale}_asc1.6.0_v003.mp4"
        for locale in EXPECTED_LOCALES
    ]
    if not ffprobe or not all(path.exists() for path in renders):
        return

    for path in renders:
        result = subprocess.run(
            [
                ffprobe,
                "-v",
                "error",
                "-show_entries",
                "format=duration,size:stream=codec_name,profile,level,width,height,r_frame_rate,sample_rate,channels,bit_rate",
                "-of",
                "json",
                str(path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        payload = json.loads(result.stdout)
        video = next((item for item in payload["streams"] if item.get("codec_name") == "h264"), None)
        audio = next((item for item in payload["streams"] if item.get("codec_name") == "aac"), None)
        duration = float(payload["format"]["duration"])
        require(15 <= duration <= 30, f"{path.name}: duration must be 15-30 seconds", failures)
        require(video is not None, f"{path.name}: missing H.264 video", failures)
        require(audio is not None, f"{path.name}: missing AAC audio", failures)
        if video:
            require((video.get("width"), video.get("height")) == (886, 1920), f"{path.name}: wrong dimensions", failures)
            require(video.get("r_frame_rate") == "30/1", f"{path.name}: wrong frame rate", failures)
            require(video.get("profile") == "High" and video.get("level") == 40, f"{path.name}: wrong H.264 profile", failures)
            require(10_000_000 <= int(video.get("bit_rate", 0)) <= 12_000_000, f"{path.name}: video bitrate outside 10-12 Mbps", failures)
        if audio:
            require(audio.get("sample_rate") == "48000" and audio.get("channels") == 2, f"{path.name}: wrong audio layout", failures)
            require(int(audio.get("bit_rate", 0)) >= 240_000, f"{path.name}: audio bitrate below delivery target", failures)


def main() -> None:
    failures: list[str] = []
    manifest = json.loads((PROJECT / "preview-manifest.json").read_text(encoding="utf-8"))
    score = json.loads((PROJECT / "score-manifest.json").read_text(encoding="utf-8"))
    template = (PROJECT / "composition.template").read_text(encoding="utf-8")
    selector = (PROJECT / "scripts/select-locale.mjs").read_text(encoding="utf-8")
    sync_assets = (PROJECT / "scripts/sync-assets.mjs").read_text(encoding="utf-8")
    renderer = (PROJECT / "scripts/render-locale.mjs").read_text(encoding="utf-8")
    package = json.loads((PROJECT / "package.json").read_text(encoding="utf-8"))
    active = json.loads((PROJECT / "active-locale.json").read_text(encoding="utf-8"))

    require(manifest.get("version") == "asc1.6.0_v003", "wrong Preview version", failures)
    require(manifest.get("durationSeconds") == 22, "Preview duration must be 22 seconds", failures)
    require(tuple(manifest.get("locales", {}).keys()) == EXPECTED_LOCALES, "five-locale order or set drifted", failures)
    require(tuple(scene.get("key") for scene in manifest.get("scenes", [])) == EXPECTED_SCENES, "scene order drifted", failures)
    for locale, values in manifest.get("locales", {}).items():
        require(bool(values.get("proMaskLabel")), f"{locale}: missing localized price replacement", failures)
        require(bool(values.get("proDisclosure")), f"{locale}: missing Pro disclosure", failures)

    require(score.get("durationSeconds") == 22 and score.get("sampleRate") == 48000, "score delivery contract drifted", failures)
    score_scenes = score.get("scenes", [])
    require(tuple(scene.get("key") for scene in score_scenes) == EXPECTED_SCENES, "score scene order drifted", failures)
    require(tuple(float(scene.get("start")) for scene in score_scenes) == EXPECTED_STARTS, "score cues no longer match visual transitions", failures)
    for current, following in zip(score_scenes, score_scenes[1:]):
        require(float(current["end"]) == float(following["start"]), f"score gap between {current['key']} and {following['key']}", failures)
    require(float(score_scenes[-1]["end"]) == 22, "score must end at 22 seconds", failures)

    for start in EXPECTED_STARTS[1:]:
        require(f", {start});" in template, f"missing visual transition at {start}s", failures)
    require('src="assets/app_preview_bed_v003.m4a"' in template, "composition does not use the v003 score", failures)
    require("{{PRO_MASK_LABEL}}" in template and "price-mask" in template, "localized price replacement is not rendered", failures)
    require("PRO_MASK_LABEL: locale.proMaskLabel" in selector, "locale selector does not map the price replacement", failures)
    require("generate-score.py" in sync_assets and "loudnorm=I=-20:TP=-1.5:LRA=7" in sync_assets, "score generation/mastering contract drifted", failures)
    require("hyperframes-v002/assets/app_preview_bed_v002" not in sync_assets, "v003 must not reuse the v002 music bed", failures)
    for required in ("-profile:v", "-level:v", "-minrate", "-maxrate", "-b:a", "-ar", "-ac"):
        require(required in renderer, f"renderer missing {required}", failures)
    require(package.get("scripts", {}).get("render-all") == "node scripts/render-all.mjs", "render-all command drifted", failures)
    require(active.get("locale") == "en-US" and active.get("assetLocale") == "en", "default active Preview must be English", failures)

    inspect_optional_renders(failures)
    if failures:
        raise SystemExit("App Preview v003 smoke failed:\n- " + "\n- ".join(failures))
    print("App Preview v003 smoke passed (five locales, synchronized original score, delivery contract).")


if __name__ == "__main__":
    main()
