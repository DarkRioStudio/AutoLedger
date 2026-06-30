#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageDraw, ImageFilter, ImageFont
except ImportError:
    print("Pillow is required. Install with: python3 -m pip install Pillow", file=sys.stderr)
    raise


ROOT = Path(__file__).resolve().parents[3]
TOOL_DIR = ROOT / "tools" / "appstore-screenshots"
CONFIG_PATH = TOOL_DIR / "config" / "screenshots.json"
RAW_BASE_DIR = TOOL_DIR / "output" / "raw"
STORE_BASE_DIR = TOOL_DIR / "output" / "store"

BACKGROUND = (243, 240, 232)
INK = (34, 40, 37)
MUTED = (91, 101, 96)
ACCENT = (43, 120, 87)

PLATFORM_DEFS = {
    "ios": {"shotsKey": "iosShots", "targetKey": "ios_65", "label": "iPhone"},
    "ipad": {"shotsKey": "ipadShots", "targetKey": "ipad_13", "label": "iPad"},
    "mac": {"shotsKey": "macShots", "targetKey": "mac_desktop", "label": "Mac"},
    "tvos": {"shotsKey": "tvosShots", "targetKey": "tvos", "label": "Apple TV"},
    "visionos": {"shotsKey": "visionosShots", "targetKey": "visionos", "label": "visionOS"},
}


def load_config() -> dict:
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def target_size(config: dict, platform: str) -> tuple[int, int]:
    target_key = PLATFORM_DEFS[platform]["targetKey"]
    target = config["targets"][target_key]
    return int(target["width"]), int(target["height"])


def font(size: int, weight: str = "regular") -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates: list[str]
    if weight == "bold":
        candidates = [
            "/System/Library/Fonts/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/System/Library/Fonts/Supplemental/Songti.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf",
        ]
    else:
        candidates = [
            "/System/Library/Fonts/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/STHeiti Light.ttc",
            "/System/Library/Fonts/Supplemental/Songti.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/System/Library/Fonts/Supplemental/Helvetica.ttf",
        ]

    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    print("warning: system font not found; falling back to Pillow default", file=sys.stderr)
    return ImageFont.load_default()


def text_width(draw: ImageDraw.ImageDraw, text: str, font_obj: ImageFont.ImageFont) -> int:
    left, _, right, _ = draw.textbbox((0, 0), text, font=font_obj)
    return right - left


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font_obj: ImageFont.ImageFont, max_width: int) -> list[str]:
    if text_width(draw, text, font_obj) <= max_width:
        return [text]

    if " " in text:
        words = text.split()
        lines: list[str] = []
        current = ""
        for word in words:
            candidate = f"{current} {word}".strip()
            if text_width(draw, candidate, font_obj) <= max_width:
                current = candidate
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
        return lines

    lines = []
    current = ""
    for char in text:
        candidate = current + char
        if text_width(draw, candidate, font_obj) <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = char
    if current:
        lines.append(current)
    return lines


def draw_multiline(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    lines: Iterable[str],
    font_obj: ImageFont.ImageFont,
    fill: tuple[int, int, int],
    spacing: int,
) -> int:
    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=font_obj, fill=fill)
        _, top, _, bottom = draw.textbbox((x, y), line, font=font_obj)
        y += (bottom - top) + spacing
    return y


def cover_resize(image: Image.Image, size: tuple[int, int], align_y: str = "center") -> Image.Image:
    target_w, target_h = size
    src_w, src_h = image.size
    scale = max(target_w / src_w, target_h / src_h)
    resized = image.resize((round(src_w * scale), round(src_h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    if align_y == "top":
        top = 0
    elif align_y == "bottom":
        top = max(0, resized.height - target_h)
    else:
        top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def fit_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    src_w, src_h = image.size
    scale = min(target_w / src_w, target_h / src_h)
    resized = image.resize((max(1, round(src_w * scale)), max(1, round(src_h * scale))), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (255, 255, 255, 0))
    left = (target_w - resized.width) // 2
    top = (target_h - resized.height) // 2
    canvas.alpha_composite(resized.convert("RGBA"), (left, top))
    return canvas


def trim_window_shadow(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    solid = alpha.point(lambda value: 255 if value > 200 else 0)
    bbox = solid.getbbox()
    if bbox is None:
        return rgba
    return rgba.crop(bbox)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_framed_capture(
    canvas: Image.Image,
    raw: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    inset: int,
    mode: str = "cover",
    align_y: str = "center",
) -> None:
    x, y, w, h = box
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(0, 0, 0, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(shadow, (0, 18))

    frame = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    target_size = (w - (inset * 2), h - (inset * 2))
    if mode == "fit":
        screenshot = fit_resize(raw.convert("RGBA"), target_size)
    else:
        screenshot = cover_resize(raw.convert("RGB"), target_size, align_y=align_y).convert("RGBA")
    frame.alpha_composite(screenshot, (inset, inset))
    frame.putalpha(rounded_mask((w, h), radius))
    canvas.alpha_composite(frame, (x, y))


def paste_window_capture(
    canvas: Image.Image,
    raw: Image.Image,
    box: tuple[int, int, int, int],
    radius: int,
    mode: str = "fit",
    align_y: str = "center",
) -> None:
    x, y, w, h = box
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(0, 0, 0, 62))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))
    canvas.alpha_composite(shadow, (0, 14))

    raw = trim_window_shadow(raw)
    if mode == "cover":
        screenshot = cover_resize(raw.convert("RGB"), (w, h), align_y=align_y).convert("RGBA")
    else:
        screenshot = fit_resize(raw.convert("RGBA"), (w, h))
    screenshot.putalpha(rounded_mask((w, h), radius))
    canvas.alpha_composite(screenshot, (x, y))


def platform_layout(platform: str, locale: str, canvas_w: int, canvas_h: int) -> dict:
    if platform == "ios":
        return {
            "brandPos": (110, 96),
            "brandFont": font(34, "bold"),
            "titleFont": font(74 if locale != "en" else 68, "bold"),
            "subtitleFont": font(35, "regular"),
            "textWidth": canvas_w - 220,
            "titlePos": (110, 205),
            "lineWidth": 98,
            "captureBox": (canvas_w // 2 - 470, 545, 940, min(canvas_h - 848, 1840)),
            "kind": "framed",
            "radius": 82,
            "inset": 10,
            "frameMode": "cover",
            "frameAlignY": "top",
        }

    if platform == "ipad":
        title_font_size = 68 if locale != "en" else 62
        capture_w = 2440
        capture_h = 1280
        return {
            "brandPos": (132, 84),
            "brandFont": font(40, "bold"),
            "titleFont": font(title_font_size, "bold"),
            "subtitleFont": font(30, "regular"),
            "textWidth": canvas_w - 264,
            "titlePos": (132, 170),
            "lineWidth": 112,
            "captureBox": ((canvas_w - capture_w) // 2, 480, capture_w, capture_h),
            "kind": "framed",
            "radius": 56,
            "inset": 16,
            "frameMode": "cover",
            "frameAlignY": "top",
        }

    if platform == "tvos":
        capture_w = 3300
        capture_h = 1856
        return {
            "brandPos": (164, 96),
            "brandFont": font(48, "bold"),
            "titleFont": font(112 if locale != "en" else 96, "bold"),
            "subtitleFont": font(48, "regular"),
            "textWidth": canvas_w - 328,
            "titlePos": (164, 190),
            "lineWidth": 148,
            "captureBox": ((canvas_w - capture_w) // 2, 650, capture_w, capture_h),
            "kind": "window",
            "radius": 58,
            "inset": 0,
            "frameMode": "cover",
            "frameAlignY": "top",
        }

    if platform == "visionos":
        capture_w = 3260
        capture_h = 1834
        return {
            "brandPos": (168, 90),
            "brandFont": font(48, "bold"),
            "titleFont": font(108 if locale != "en" else 94, "bold"),
            "subtitleFont": font(46, "regular"),
            "textWidth": canvas_w - 336,
            "titlePos": (168, 184),
            "lineWidth": 148,
            "captureBox": ((canvas_w - capture_w) // 2, 654, capture_w, capture_h),
            "kind": "window",
            "radius": 66,
            "inset": 0,
            "frameMode": "cover",
            "frameAlignY": "center",
        }

    capture_w = 1248
    capture_h = 780
    return {
        "brandPos": (54, 36),
        "brandFont": font(26, "bold"),
        "titleFont": font(50 if locale != "en" else 46, "bold"),
        "subtitleFont": font(22, "regular"),
        "textWidth": canvas_w - 108,
        "titlePos": (54, 72),
        "lineWidth": 72,
        "captureBox": ((canvas_w - capture_w) // 2, 232, capture_w, capture_h),
        "kind": "window",
        "radius": 24,
        "inset": 0,
        "frameMode": "fit",
        "frameAlignY": "center",
    }


def render_shot(config: dict, platform: str, locale: str, shot: dict) -> bool:
    raw_path = RAW_BASE_DIR / platform / locale / f"{shot['id']}.png"
    if not raw_path.exists():
        print(f"warning: missing raw {platform} screenshot: {raw_path}", file=sys.stderr)
        return False

    canvas_w, canvas_h = target_size(config, platform)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), BACKGROUND + (255,))
    draw = ImageDraw.Draw(canvas)
    layout = platform_layout(platform, locale, canvas_w, canvas_h)

    draw.text(layout["brandPos"], config["app"]["name"], font=layout["brandFont"], fill=ACCENT)

    title = shot["title"][locale]
    subtitle = shot["subtitle"][locale]
    title_lines = wrap_text(draw, title, layout["titleFont"], layout["textWidth"])
    title_bottom = draw_multiline(draw, layout["titlePos"], title_lines, layout["titleFont"], INK, 10)
    subtitle_lines = wrap_text(draw, subtitle, layout["subtitleFont"], layout["textWidth"])
    subtitle_bottom = draw_multiline(
        draw,
        (layout["titlePos"][0] + 2, title_bottom + 16),
        subtitle_lines,
        layout["subtitleFont"],
        MUTED,
        8,
    )

    line_y = subtitle_bottom + 24
    draw.rounded_rectangle(
        (layout["titlePos"][0] + 2, line_y, layout["titlePos"][0] + 2 + layout["lineWidth"], line_y + 8),
        radius=4,
        fill=ACCENT,
    )

    raw = Image.open(raw_path)
    if layout["kind"] == "window":
        paste_window_capture(
            canvas,
            raw,
            layout["captureBox"],
            layout["radius"],
            layout.get("frameMode", "fit"),
            layout.get("frameAlignY", "center"),
        )
    else:
        paste_framed_capture(
            canvas,
            raw,
            layout["captureBox"],
            layout["radius"],
            layout["inset"],
            layout.get("frameMode", "cover"),
            layout.get("frameAlignY", "center"),
        )

    out_dir = STORE_BASE_DIR / platform / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{shot['id']}.png"
    canvas.convert("RGB").save(out_path, "PNG")
    print(f"wrote {out_path.relative_to(ROOT)} ({canvas_w}x{canvas_h})")
    return True


def iter_platform_shots(config: dict, platform_filters: set[str]) -> list[tuple[str, list[dict]]]:
    items: list[tuple[str, list[dict]]] = []
    for platform, platform_def in PLATFORM_DEFS.items():
        if platform_filters and platform not in platform_filters:
            continue
        shots = config.get(platform_def["shotsKey"], [])
        if shots:
            items.append((platform, shots))
    return items


def parse_args(argv: list[str]) -> tuple[set[str], set[str]]:
    locales: set[str] = set()
    platforms: set[str] = set()
    index = 0
    while index < len(argv):
        arg = argv[index]
        if arg == "--platform":
            if index + 1 >= len(argv):
                raise SystemExit("--platform requires a value")
            platform = argv[index + 1]
            if platform not in PLATFORM_DEFS:
                raise SystemExit(f"unknown platform: {platform}")
            platforms.add(platform)
            index += 2
            continue
        if arg.startswith("--platform="):
            platform = arg.split("=", 1)[1]
            if platform not in PLATFORM_DEFS:
                raise SystemExit(f"unknown platform: {platform}")
            platforms.add(platform)
            index += 1
            continue
        locales.add(arg)
        index += 1
    return locales, platforms


def main() -> int:
    config = load_config()
    locale_filters, platform_filters = parse_args(sys.argv[1:])
    rendered = 0
    attempted = 0
    for locale in config["locales"]:
        if locale_filters and locale not in locale_filters:
            continue
        for platform, shots in iter_platform_shots(config, platform_filters):
            for shot in shots:
                attempted += 1
                if render_shot(config, platform, locale, shot):
                    rendered += 1
    if rendered == 0 and attempted:
        print("error: no raw screenshots were found for the requested marketing render", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
