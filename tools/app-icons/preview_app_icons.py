#!/usr/bin/env python3
"""Create a platform-shaped preview sheet for AutoLedger app icons."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = Path("/tmp/autoledger_full_platform_logo_preview.png")


@dataclass(frozen=True)
class PreviewItem:
    title: str
    shape: str
    image: Image.Image


def load(relative_path: str) -> Image.Image:
    return Image.open(ROOT / relative_path).convert("RGBA")


def composite_layers(relative_paths: list[str]) -> Image.Image:
    image = load(relative_paths[0])
    for relative_path in relative_paths[1:]:
        image.alpha_composite(load(relative_path))
    return image


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def circle_mask(size: tuple[int, int]) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, size[0] - 1, size[1] - 1), fill=255)
    return mask


def masked_icon(image: Image.Image, shape: str, max_size: tuple[int, int]) -> Image.Image:
    icon = image.copy()
    if icon.width > icon.height:
        icon.thumbnail(max_size, Image.Resampling.LANCZOS)
    else:
        square = min(max_size)
        icon.thumbnail((square, square), Image.Resampling.LANCZOS)

    if shape == "circle":
        side = min(icon.width, icon.height)
        cropped = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        cropped.alpha_composite(icon, ((side - icon.width) // 2, (side - icon.height) // 2))
        cropped.putalpha(circle_mask((side, side)))
        return cropped

    if shape == "rounded":
        radius = max(16, int(min(icon.size) * 0.22))
        icon.putalpha(rounded_mask(icon.size, radius))
        return icon

    if shape == "wide":
        radius = max(12, int(min(icon.size) * 0.10))
        icon.putalpha(rounded_mask(icon.size, radius))
        return icon

    return icon


def font(path: str, size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def preview_items() -> list[PreviewItem]:
    tv_icon = [
        "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Back.imagestacklayer/Content.imageset/Back-1x.png",
        "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Middle.imagestacklayer/Content.imageset/Middle-1x.png",
        "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon.imagestack/Front.imagestacklayer/Content.imageset/Front-1x.png",
    ]
    tv_store = [
        "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/Back-AppStore.png",
        "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Middle.imagestacklayer/Content.imageset/Middle-AppStore.png",
        "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/Front-AppStore.png",
    ]
    vision = [
        "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Back.solidimagestacklayer/Content.imageset/Back.png",
        "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Middle.solidimagestacklayer/Content.imageset/Middle.png",
        "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack/Front.solidimagestacklayer/Content.imageset/Front.png",
    ]

    return [
        PreviewItem("iOS Light", "rounded", load("AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png")),
        PreviewItem("iOS Dark", "rounded", load("AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png")),
        PreviewItem("iOS Tinted", "rounded", load("AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png")),
        PreviewItem("Mac Catalyst", "rounded", load("AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset/AppIcon-Light.png")),
        PreviewItem("Apple Watch", "circle", load("AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")),
        PreviewItem("tvOS 1x", "wide", composite_layers(tv_icon)),
        PreviewItem("tvOS App Store", "wide", composite_layers(tv_store)),
        PreviewItem("visionOS", "circle", composite_layers(vision)),
    ]


def draw_card(
    sheet: Image.Image,
    position: tuple[int, int],
    item: PreviewItem,
    title_font: ImageFont.ImageFont,
    meta_font: ImageFont.ImageFont,
) -> None:
    x, y = position
    card_w, card_h = 310, 300
    card = Image.new("RGBA", (card_w, card_h), (255, 255, 255, 255))
    shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((8, 10, card_w - 8, card_h - 6), radius=22, fill=(24, 36, 70, 28))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    sheet.paste(shadow.convert("RGB"), (x, y), shadow)

    draw = ImageDraw.Draw(card)
    draw.rounded_rectangle((0, 0, card_w - 1, card_h - 1), radius=20, fill=(255, 255, 255), outline=(218, 225, 236), width=1)

    stage = Image.new("RGBA", (260, 182), (246, 248, 251, 255))
    stage_draw = ImageDraw.Draw(stage)
    stage_draw.rounded_rectangle((0, 0, stage.width - 1, stage.height - 1), radius=18, fill=(246, 248, 251), outline=(228, 233, 241), width=1)

    preview = masked_icon(item.image, item.shape, (230, 154))
    if item.shape == "circle":
        preview = masked_icon(item.image, item.shape, (154, 154))
    stage.alpha_composite(preview, ((stage.width - preview.width) // 2, (stage.height - preview.height) // 2))
    card.alpha_composite(stage, (25, 24))

    draw.text((26, 222), item.title, fill=(24, 32, 48), font=title_font)
    shape_label = {
        "rounded": "rounded rectangle",
        "circle": "circle",
        "wide": "wide rectangle",
    }.get(item.shape, item.shape)
    draw.text((26, 248), shape_label, fill=(88, 101, 124), font=meta_font)
    draw.text((26, 268), f"source {item.image.width} x {item.image.height}", fill=(104, 116, 138), font=meta_font)

    sheet.paste(card.convert("RGB"), position)


def create_preview(output_path: Path) -> None:
    title_font = font("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 28)
    subtitle_font = font("/System/Library/Fonts/Supplemental/Arial.ttf", 16)
    card_title_font = font("/System/Library/Fonts/Supplemental/Arial.ttf", 20)
    card_meta_font = font("/System/Library/Fonts/Supplemental/Arial.ttf", 14)

    cols = 4
    rows = 2
    card_w, card_h = 310, 300
    pad = 28
    gap = 20
    header_h = 86
    width = pad * 2 + cols * card_w + (cols - 1) * gap
    height = header_h + pad + rows * card_h + (rows - 1) * gap
    sheet = Image.new("RGB", (width, height), (241, 244, 248))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 24), "AutoLedger App Icon Platform Shape Preview", fill=(18, 28, 45), font=title_font)
    draw.text(
        (pad, 58),
        "Rendered from current assets with platform masks: rounded rectangle, circle, and wide rectangle.",
        fill=(78, 89, 110),
        font=subtitle_font,
    )

    for index, item in enumerate(preview_items()):
        col = index % cols
        row = index // cols
        x = pad + col * (card_w + gap)
        y = header_h + pad + row * (card_h + gap)
        draw_card(sheet, (x, y), item, card_title_font, card_meta_font)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    create_preview(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
