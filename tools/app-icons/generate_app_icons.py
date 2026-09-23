#!/usr/bin/env python3
"""Generate every platform icon from the approved Locked A artwork."""
from __future__ import annotations

import copy
import io
import json
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
IOS_ICON_ROOT = ROOT / "AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset"
APPROVED_IOS_MASTER_PATH = ROOT / "tools/app-icons/sources/autoledger-locked-a-1024.png"
SVG_PATH = ROOT / "tools/app-icons/sources/autoledger-locked-a.svg"
WATCH_ICON_ROOT = ROOT / "AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset"
TV_ICON_ROOT = ROOT / "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
VISION_ICON_ROOT = ROOT / "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack"
NS = "http://www.w3.org/2000/svg"
ET.register_namespace("", NS)

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



def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def render_layer(size: tuple[int, int], layer: str, scale: float = 1.0) -> Image.Image:
    source = ET.parse(SVG_PATH).getroot()
    width, height = size
    svg = ET.Element(f"{{{NS}}}svg", width=str(width), height=str(height),
                     viewBox=f"0 0 {width} {height}")
    svg.append(copy.deepcopy(source.find(f"{{{NS}}}defs")))
    if layer == "Back":
        canvas = ET.SubElement(svg, f"{{{NS}}}g", transform=f"scale({width / 1024} {height / 1024})")
        for rect in source.findall(f"{{{NS}}}rect"):
            canvas.append(copy.deepcopy(rect))
    else:
        factor = min(size) / 1024 * scale
        placement = ET.SubElement(svg, f"{{{NS}}}g", transform=
            f"translate({width / 2} {height / 2}) scale({factor}) translate(-512 -512)")
        artwork = copy.deepcopy(source.find(f"{{{NS}}}g"))
        # Keep the approved vector geometry. Separate the card and its contents
        # for Apple's depth stacks instead of inventing a second platform logo.
        for i, child in enumerate(list(artwork)):
            if (layer == "Middle" and i != 0) or (layer == "Front" and i == 0):
                artwork.remove(child)
        placement.append(artwork)
    result = subprocess.run(["node", str(ROOT / "tools/app-icons/render_svg.cjs")],
                            input=ET.tostring(svg), capture_output=True, check=True)
    return Image.open(io.BytesIO(result.stdout)).convert("RGBA")


def composite(size: tuple[int, int], scale: float) -> Image.Image:
    result = render_layer(size, "Back")
    for layer in ("Middle", "Front"):
        result.alpha_composite(render_layer(size, layer, scale))
    return result.convert("RGB")


def generate_ios_and_mac_icons() -> None:
    with Image.open(APPROVED_IOS_MASTER_PATH) as source:
        master = source.convert("RGB")
    if master.size != (1024, 1024):
        raise ValueError("Approved master must be 1024x1024")
    save(master, IOS_ICON_ROOT / "AppIcon-Light.png")
    save(master.copy(), IOS_ICON_ROOT / "AppIcon-Dark.png")
    save(ImageOps.grayscale(master).convert("RGB"), IOS_ICON_ROOT / "AppIcon-Tinted.png")
    catalog_path = IOS_ICON_ROOT / "Contents.json"
    catalog = json.loads(catalog_path.read_text())
    catalog["images"] = [item for item in catalog["images"] if item["idiom"] != "mac"]
    for points in (16, 32, 128, 256, 512):
        for factor in (1, 2):
            filename = f"AppIcon-Mac-{points}@{factor}x.png"
            save(master.resize((points * factor, points * factor), Image.Resampling.LANCZOS), IOS_ICON_ROOT / filename)
            catalog["images"].append({"filename": filename, "idiom": "mac", "size": f"{points}x{points}", "scale": f"{factor}x"})
    catalog_path.write_text(json.dumps(catalog, indent=2) + "\n")


def generate_watch_icons() -> None:
    master = composite((1024, 1024), 0.82)
    for filename, size in WATCH_ICON_SIZES.items():
        save(master.resize(size, Image.Resampling.LANCZOS), WATCH_ICON_ROOT / filename)


def generate_tv_icons() -> None:
    for suffix, size in {"1x": (400, 240), "2x": (800, 480), "AppStore": (1280, 768)}.items():
        stack = "App Icon - App Store.imagestack" if suffix == "AppStore" else "App Icon.imagestack"
        for layer in ("Back", "Middle", "Front"):
            image = render_layer(size, layer, 0.92)
            if layer == "Back":
                image = image.convert("RGB")
            save(image, TV_ICON_ROOT / stack / f"{layer}.imagestacklayer/Content.imageset/{layer}-{suffix}.png")
    for directory in ("Top Shelf Image.imageset", "Top Shelf Image Wide.imageset"):
        catalog = json.loads((TV_ICON_ROOT / directory / "Contents.json").read_text())
        for item in catalog["images"]:
            path = TV_ICON_ROOT / directory / item["filename"]
            with Image.open(path) as existing:
                size = existing.size
            save(composite(size, 0.82), path)


def generate_vision_icons() -> None:
    for layer in ("Back", "Middle", "Front"):
        image = render_layer((1024, 1024), layer, 0.82)
        if layer == "Back":
            image = image.convert("RGB")
        save(image, VISION_ICON_ROOT / f"{layer}.solidimagestacklayer/Content.imageset/{layer}.png")


def main() -> None:
    generate_ios_and_mac_icons()
    generate_watch_icons()
    generate_tv_icons()
    generate_vision_icons()
    print("Generated all platform icons from approved Locked A artwork.")


if __name__ == "__main__":
    main()
