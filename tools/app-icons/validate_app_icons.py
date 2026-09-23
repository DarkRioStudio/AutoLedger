#!/usr/bin/env python3
"""Validate AutoLedger app icon assets for platform-specific legibility."""

from __future__ import annotations

import sys
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]

EXPECTED_SIZES = {
    "AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png": (1024, 1024),
    "AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png": (1024, 1024),
    "AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png": (1024, 1024),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/Back-1x.png": (400, 240),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/Back-2x.png": (800, 480),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Middle.imagestacklayer/Content.imageset/Middle-1x.png": (400, 240),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Middle.imagestacklayer/Content.imageset/Middle-2x.png": (800, 480),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Front-1x.png": (400, 240),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Front-2x.png": (800, 480),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/Back-AppStore.png": (1280, 768),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Middle.imagestacklayer/Content.imageset/Middle-AppStore.png": (1280, 768),
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/Front-AppStore.png": (1280, 768),
    "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/Back.png": (1024, 1024),
    "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Middle.solidimagestacklayer/Content.imageset/Middle.png": (1024, 1024),
    "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/Front.png": (1024, 1024),
}

WATCH_ICON_SIZES = {
    "AppIcon-24x24@2x.png": (48, 48),
    "AppIcon-27.5x27.5@2x.png": (55, 55),
    "AppIcon-29x29@2x.png": (58, 58),
    "AppIcon-29x29@3x.png": (87, 87),
    "AppIcon-40x40@2x.png": (80, 80),
    "AppIcon-44x44@2x.png": (88, 88),
    "AppIcon-50x50@2x.png": (100, 100),
    "AppIcon-86x86@2x.png": (172, 172),
    "AppIcon-98x98@2x.png": (196, 196),
    "AppIcon-108x108@2x.png": (216, 216),
    "AppIcon.png": (1024, 1024),
}

# Locked A separates the white card into Middle; Front contains only marks.
# Its wide TV layout has about 8% occupied pixels, unlike the old lightning logo.
FRONT_LAYER_MIN_ALPHA_COVERAGE = {
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Front-1x.png": 0.06,
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Front-2x.png": 0.06,
    "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/Front-AppStore.png": 0.06,
    "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/Front.png": 0.06,
}


def image_size(path: Path) -> tuple[int, int]:
    with Image.open(path) as image:
        return image.size


def alpha_coverage(path: Path) -> float:
    with Image.open(path).convert("RGBA") as image:
        alpha = image.getchannel("A")
        histogram = alpha.histogram()
        opaque_pixels = sum(histogram[21:])
        return opaque_pixels / float(image.width * image.height)


def main() -> int:
    failures: list[str] = []

    # Verify every catalog reference, including Mac size/scale slots and TV shelf.
    for catalog in (ROOT / "AutoLedger").rglob("Contents.json"):
        if "AppIcon" not in str(catalog) and "App Icon & Top Shelf" not in str(catalog):
            continue
        for item in json.loads(catalog.read_text()).get("images", []):
            if "filename" not in item:
                continue
            path = catalog.parent / item["filename"]
            if not path.exists():
                failures.append(f"catalog references missing file: {path}")
                continue
            with Image.open(path) as image:
                if item.get("idiom") == "mac":
                    points = int(item["size"].split("x")[0])
                    factor = int(item["scale"].rstrip("x"))
                    if image.size != (points * factor, points * factor):
                        failures.append(f"incorrect Mac icon size: {path}")
                if "Back" in path.name or "AppIcon" in path.name or "TopShelf" in path.name:
                    if image.convert("RGBA").getchannel("A").getextrema() != (255, 255):
                        failures.append(f"base icon must be opaque: {path}")
    master = Image.open(ROOT / "tools/app-icons/sources/autoledger-locked-a-1024.png").convert("RGB")
    for appearance in ("Light", "Dark"):
        actual = Image.open(ROOT / f"AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-{appearance}.png").convert("RGB")
        if actual.tobytes() != master.tobytes():
            failures.append(f"approved iPhone {appearance} artwork changed")

    for relative_path, expected_size in EXPECTED_SIZES.items():
        path = ROOT / relative_path
        if not path.exists():
            failures.append(f"missing icon asset: {relative_path}")
            continue
        actual_size = image_size(path)
        if actual_size != expected_size:
            failures.append(f"{relative_path}: expected {expected_size}, got {actual_size}")

    watch_root = ROOT / "AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset"
    for filename, expected_size in WATCH_ICON_SIZES.items():
        path = watch_root / filename
        if not path.exists():
            failures.append(f"missing watch icon asset: {path.relative_to(ROOT)}")
            continue
        actual_size = image_size(path)
        if actual_size != expected_size:
            failures.append(f"{path.relative_to(ROOT)}: expected {expected_size}, got {actual_size}")

    for relative_path, minimum_coverage in FRONT_LAYER_MIN_ALPHA_COVERAGE.items():
        coverage = alpha_coverage(ROOT / relative_path)
        if coverage < minimum_coverage:
            failures.append(
                f"{relative_path}: foreground coverage {coverage:.3f} is below {minimum_coverage:.3f}"
            )

    if failures:
        print("App icon validation failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("App icon validation passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
