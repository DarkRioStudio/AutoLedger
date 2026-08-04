#!/usr/bin/env python3
"""Generate platform-specific AutoLedger app icon PNG assets."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]

IOS_ICON_ROOT = ROOT / "AutoLedger/AutoLedger/Assets.xcassets/AppIcon.appiconset"
APPROVED_IOS_MASTER_PATH = ROOT / "tools/app-icons/sources/autoledger-locked-a-1024.png"
WATCH_ICON_ROOT = ROOT / "AutoLedger/AutoLedgerWatch Watch App/Assets.xcassets/AppIcon.appiconset"
TV_ICON_ROOT = ROOT / "AutoLedger/AutoLedgerTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
VISION_ICON_ROOT = ROOT / "AutoLedger/AutoLedgerVision/Assets.xcassets/AppIcon.solidimagestack"

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


def scaled(size: tuple[int, int], factor: int) -> tuple[int, int]:
    return (size[0] * factor, size[1] * factor)


def downsample(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.resize(size, Image.Resampling.LANCZOS)


def rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def add_layer(base: Image.Image, layer: Image.Image) -> None:
    base.alpha_composite(layer)


def draw_gradient_background(size: tuple[int, int], dark: bool = False, tinted: bool = False) -> Image.Image:
    width, height = size
    image = Image.new("RGBA", size)
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            nx = x / max(width - 1, 1)
            ny = y / max(height - 1, 1)
            if tinted:
                start = (230, 230, 230)
                end = (246, 246, 246)
                accent = (190, 190, 190)
            elif dark:
                start = (18, 23, 90)
                end = (0, 118, 140)
                accent = (0, 180, 160)
            else:
                start = (46, 63, 230)
                end = (15, 218, 185)
                accent = (35, 150, 238)
            mix = min(1.0, max(0.0, 0.68 * nx + 0.32 * ny))
            ring = 0.12 * math.sin((nx * 1.25 + ny * 0.85) * math.pi)
            r = int(start[0] * (1 - mix) + end[0] * mix + accent[0] * ring)
            g = int(start[1] * (1 - mix) + end[1] * mix + accent[1] * ring)
            b = int(start[2] * (1 - mix) + end[2] * mix + accent[2] * ring)
            pixels[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)), 255)
    return image


def draw_soft_orb(
    image: Image.Image,
    center: tuple[float, float],
    radius: float,
    color: tuple[int, int, int, int],
) -> None:
    width, height = image.size
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = overlay.load()
    cx, cy = center
    for y in range(max(0, int(cy - radius)), min(height, int(cy + radius))):
        for x in range(max(0, int(cx - radius)), min(width, int(cx + radius))):
            distance = math.hypot(x - cx, y - cy) / radius
            if distance <= 1:
                alpha = int(color[3] * (1 - distance) ** 2)
                pixels[x, y] = (color[0], color[1], color[2], alpha)
    image.alpha_composite(overlay)


def background_layer(size: tuple[int, int], dark: bool = False, tinted: bool = False, rounded: bool = False) -> Image.Image:
    scale = 3
    large_size = scaled(size, scale)
    image = draw_gradient_background(large_size, dark=dark, tinted=tinted)
    if not tinted:
        draw_soft_orb(image, (large_size[0] * 0.20, large_size[1] * 0.17), large_size[0] * 0.38, (255, 255, 255, 30))
        draw_soft_orb(image, (large_size[0] * 0.84, large_size[1] * 0.82), large_size[0] * 0.42, (0, 255, 210, 36))
    if rounded:
        mask = rounded_rect_mask(large_size, int(min(large_size) * 0.18))
        image.putalpha(mask)
    return downsample(image, size)


def wallet_layer(size: tuple[int, int], compact: bool = False, tinted: bool = False) -> Image.Image:
    scale = 4
    width, height = scaled(size, scale)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    unit = min(width, height)
    if width > height:
        wallet_w = width * (0.54 if compact else 0.62)
        wallet_h = height * (0.44 if compact else 0.46)
    else:
        wallet_w = unit * (0.68 if not compact else 0.58)
        wallet_h = wallet_w * 0.48
    wallet_x = width * 0.50 - wallet_w * 0.50
    wallet_y = height * (0.53 if width <= height else 0.55) - wallet_h * 0.50
    radius = wallet_h * 0.17

    shadow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (wallet_x + unit * 0.025, wallet_y + unit * 0.045, wallet_x + wallet_w + unit * 0.025, wallet_y + wallet_h + unit * 0.045),
        radius=radius,
        fill=(0, 24, 80, 70),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(unit * 0.018))
    image.alpha_composite(shadow)

    body = (245, 252, 255, 255) if not tinted else (245, 245, 245, 255)
    lower = (220, 247, 252, 255) if not tinted else (224, 224, 224, 255)
    stroke = (211, 239, 246, 255) if not tinted else (205, 205, 205, 255)
    draw.rounded_rectangle((wallet_x, wallet_y, wallet_x + wallet_w, wallet_y + wallet_h), radius=radius, fill=body)
    draw.rounded_rectangle(
        (wallet_x + wallet_w * 0.04, wallet_y + wallet_h * 0.40, wallet_x + wallet_w * 0.98, wallet_y + wallet_h * 0.99),
        radius=radius * 0.72,
        fill=lower,
    )
    draw.rounded_rectangle((wallet_x, wallet_y, wallet_x + wallet_w, wallet_y + wallet_h), radius=radius, outline=stroke, width=max(2, int(unit * 0.012)))

    clasp_w = wallet_w * 0.22
    clasp_h = wallet_h * 0.31
    clasp_x = wallet_x + wallet_w * 0.80
    clasp_y = wallet_y + wallet_h * 0.40
    draw.rounded_rectangle((clasp_x, clasp_y, clasp_x + clasp_w, clasp_y + clasp_h), radius=clasp_h * 0.45, fill=body)
    dot = (0, 141, 184, 255) if not tinted else (130, 130, 130, 255)
    draw.ellipse(
        (
            clasp_x + clasp_w * 0.52,
            clasp_y + clasp_h * 0.30,
            clasp_x + clasp_w * 0.80,
            clasp_y + clasp_h * 0.58,
        ),
        fill=dot,
    )

    tab = (45, 68, 238, 255) if not tinted else (145, 145, 145, 255)
    draw.rounded_rectangle(
        (
            wallet_x + wallet_w * 0.04,
            wallet_y + wallet_h * 0.04,
            wallet_x + wallet_w * 0.28,
            wallet_y + wallet_h * 0.15,
        ),
        radius=wallet_h * 0.05,
        fill=tab,
    )

    coin_r = unit * (0.15 if not compact else 0.115)
    coin_cx = wallet_x + wallet_w * 0.55
    coin_cy = wallet_y - coin_r * 0.02
    draw.ellipse((coin_cx - coin_r, coin_cy - coin_r, coin_cx + coin_r, coin_cy + coin_r), fill=(255, 207, 43, 255))
    draw.ellipse(
        (
            coin_cx - coin_r * 0.78,
            coin_cy - coin_r * 0.78,
            coin_cx + coin_r * 0.78,
            coin_cy + coin_r * 0.78,
        ),
        fill=(255, 224, 79, 255),
        outline=(255, 173, 24, 255),
        width=max(2, int(unit * 0.012)),
    )
    symbol_color = (230, 98, 34, 255) if not tinted else (120, 120, 120, 255)
    font_w = max(3, int(unit * 0.026))
    draw.line((coin_cx, coin_cy - coin_r * 0.34, coin_cx, coin_cy + coin_r * 0.36), fill=symbol_color, width=font_w)
    draw.line((coin_cx - coin_r * 0.30, coin_cy - coin_r * 0.02, coin_cx + coin_r * 0.30, coin_cy - coin_r * 0.02), fill=symbol_color, width=font_w)
    draw.line((coin_cx - coin_r * 0.24, coin_cy + coin_r * 0.19, coin_cx + coin_r * 0.24, coin_cy + coin_r * 0.19), fill=symbol_color, width=font_w)
    draw.line((coin_cx - coin_r * 0.26, coin_cy - coin_r * 0.30, coin_cx, coin_cy - coin_r * 0.06, coin_cx + coin_r * 0.26, coin_cy - coin_r * 0.30), fill=symbol_color, width=font_w)

    return downsample(image, size)


def lightning_polygon(size: tuple[int, int], square: bool) -> list[tuple[float, float]]:
    width, height = size
    if square:
        return [
            (width * 0.24, height * 0.80),
            (width * 0.43, height * 0.55),
            (width * 0.31, height * 0.55),
            (width * 0.67, height * 0.18),
            (width * 0.54, height * 0.45),
            (width * 0.68, height * 0.45),
            (width * 0.31, height * 0.89),
        ]
    return [
        (width * 0.25, height * 0.80),
        (width * 0.44, height * 0.56),
        (width * 0.34, height * 0.56),
        (width * 0.66, height * 0.20),
        (width * 0.55, height * 0.45),
        (width * 0.68, height * 0.45),
        (width * 0.34, height * 0.88),
    ]


def lightning_layer(size: tuple[int, int], square: bool = True, tinted: bool = False) -> Image.Image:
    scale = 4
    width, height = scaled(size, scale)
    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    polygon = [(x * scale, y * scale) for x, y in lightning_polygon(size, square=square)]
    unit = min(width, height)

    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.line(polygon + [polygon[0]], fill=(58, 42, 166, 85), width=max(8, int(unit * 0.056)), joint="curve")
    gd.polygon(polygon, fill=(58, 42, 166, 85))
    glow = glow.filter(ImageFilter.GaussianBlur(max(3, int(unit * 0.010))))
    image.alpha_composite(glow)

    draw = ImageDraw.Draw(image)
    outline = (78, 47, 196, 255) if not tinted else (115, 115, 115, 255)
    edge = (255, 102, 64, 255) if not tinted else (175, 175, 175, 255)
    fill = (255, 214, 53, 255) if not tinted else (245, 245, 245, 255)
    draw.line(polygon + [polygon[0]], fill=outline, width=max(5, int(unit * 0.032)), joint="curve")
    draw.polygon(polygon, fill=outline)
    inset = [
        (polygon[0][0] + unit * 0.016, polygon[0][1] - unit * 0.010),
        (polygon[1][0] + unit * 0.010, polygon[1][1] - unit * 0.012),
        (polygon[2][0] + unit * 0.022, polygon[2][1] - unit * 0.005),
        (polygon[3][0] - unit * 0.018, polygon[3][1] + unit * 0.010),
        (polygon[4][0] - unit * 0.003, polygon[4][1] + unit * 0.007),
        (polygon[5][0] - unit * 0.025, polygon[5][1] + unit * 0.010),
        (polygon[6][0] - unit * 0.014, polygon[6][1] - unit * 0.010),
    ]
    draw.polygon(inset, fill=edge)
    core = [
        (polygon[0][0] + unit * 0.041, polygon[0][1] - unit * 0.027),
        (polygon[1][0] + unit * 0.034, polygon[1][1] - unit * 0.027),
        (polygon[2][0] + unit * 0.055, polygon[2][1] - unit * 0.017),
        (polygon[3][0] - unit * 0.037, polygon[3][1] + unit * 0.022),
        (polygon[4][0] - unit * 0.022, polygon[4][1] + unit * 0.019),
        (polygon[5][0] - unit * 0.056, polygon[5][1] + unit * 0.025),
        (polygon[6][0] - unit * 0.034, polygon[6][1] - unit * 0.027),
    ]
    draw.polygon(core, fill=fill)

    if not tinted:
        sparkle = (255, 230, 64, 255)
        cyan = (75, 226, 234, 255)
        pink = (255, 117, 223, 255)
        points = [
            (width * 0.72, height * 0.15, unit * 0.040, sparkle),
            (width * 0.83, height * 0.24, unit * 0.015, cyan),
            (width * 0.65, height * 0.19, unit * 0.012, pink),
            (width * 0.78, height * 0.34, unit * 0.012, cyan),
        ]
        for cx, cy, r, color in points:
            draw.line((cx - r, cy, cx + r, cy), fill=color, width=max(2, int(r * 0.28)))
            draw.line((cx, cy - r, cx, cy + r), fill=color, width=max(2, int(r * 0.28)))
            if r > unit * 0.02:
                draw.line((cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55), fill=color, width=max(2, int(r * 0.18)))
                draw.line((cx - r * 0.55, cy + r * 0.55, cx + r * 0.55, cy - r * 0.55), fill=color, width=max(2, int(r * 0.18)))

    return downsample(image, size)


def compose_icon(size: tuple[int, int], dark: bool = False, tinted: bool = False, compact: bool = False) -> Image.Image:
    image = background_layer(size, dark=dark, tinted=tinted, rounded=False)
    add_layer(image, wallet_layer(size, compact=compact, tinted=tinted))
    add_layer(image, lightning_layer(size, square=True, tinted=tinted))
    return image


def emblem_layer(size: tuple[int, int], compact: bool = False) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    add_layer(image, wallet_layer(size, compact=compact))
    add_layer(image, lightning_layer(size, square=True))
    return image


def depth_shadow_layer(size: tuple[int, int], compact: bool = False) -> Image.Image:
    emblem = emblem_layer(size, compact=compact)
    alpha = emblem.getchannel("A").filter(ImageFilter.GaussianBlur(max(4, int(min(size) * 0.018))))
    shadow = Image.new("RGBA", size, (8, 28, 86, 0))
    shadow.putalpha(alpha.point(lambda value: int(value * 0.22)))

    offset = max(2, int(min(size) * 0.028))
    shifted = Image.new("RGBA", size, (0, 0, 0, 0))
    shifted.alpha_composite(shadow, (0, offset))
    return shifted


def resize_icon(master: Image.Image, size: tuple[int, int]) -> Image.Image:
    return master.resize(size, Image.Resampling.LANCZOS)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def generate_ios_icons() -> None:
    with Image.open(APPROVED_IOS_MASTER_PATH) as source:
        master = source.convert("RGB")
    if master.size != (1024, 1024):
        raise ValueError(f"Approved iOS app icon must be 1024x1024, got {master.size}")

    # Locked Concept A is the approved composition for both default appearances.
    # The tinted slot keeps the same geometry and uses luminance as the tint mask.
    save(master, IOS_ICON_ROOT / "AppIcon-Light.png")
    save(master.copy(), IOS_ICON_ROOT / "AppIcon-Dark.png")
    save(ImageOps.grayscale(master).convert("RGB"), IOS_ICON_ROOT / "AppIcon-Tinted.png")


def generate_watch_icons() -> None:
    master = compose_icon((1024, 1024), compact=True)
    for filename, size in WATCH_ICON_SIZES.items():
        save(resize_icon(master, size), WATCH_ICON_ROOT / filename)


def generate_tv_icons() -> None:
    sizes = {
        "1x": (400, 240),
        "2x": (800, 480),
        "AppStore": (1280, 768),
    }
    for suffix, size in sizes.items():
        back = background_layer(size, rounded=False)
        middle = wallet_layer(size, compact=True)
        front = lightning_layer(size, square=False)
        if suffix == "AppStore":
            save(back, TV_ICON_ROOT / "App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/Back-AppStore.png")
            save(middle, TV_ICON_ROOT / "App Icon - App Store.imagestack/Middle.imagestacklayer/Content.imageset/Middle-AppStore.png")
            save(front, TV_ICON_ROOT / "App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/Front-AppStore.png")
        else:
            save(back, TV_ICON_ROOT / f"App Icon.imagestack/Back.imagestacklayer/Content.imageset/Back-{suffix}.png")
            save(middle, TV_ICON_ROOT / f"App Icon.imagestack/Middle.imagestacklayer/Content.imageset/Middle-{suffix}.png")
            save(front, TV_ICON_ROOT / f"App Icon.imagestack/Front.imagestacklayer/Content.imageset/Front-{suffix}.png")


def generate_vision_icons() -> None:
    size = (1024, 1024)
    save(background_layer(size, rounded=False), VISION_ICON_ROOT / "Back.solidimagestacklayer/Content.imageset/Back.png")
    save(depth_shadow_layer(size, compact=True), VISION_ICON_ROOT / "Middle.solidimagestacklayer/Content.imageset/Middle.png")
    save(emblem_layer(size, compact=True), VISION_ICON_ROOT / "Front.solidimagestacklayer/Content.imageset/Front.png")


def main() -> None:
    generate_ios_icons()
    generate_watch_icons()
    generate_tv_icons()
    generate_vision_icons()
    print("Generated AutoLedger app icon assets.")


if __name__ == "__main__":
    main()
