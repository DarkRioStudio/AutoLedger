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
RAW_DIR = TOOL_DIR / "output" / "raw" / "ios"
STORE_DIR = TOOL_DIR / "output" / "store" / "ios"

BACKGROUND = (243, 240, 232)
INK = (34, 40, 37)
MUTED = (91, 101, 96)
ACCENT = (43, 120, 87)


def load_config() -> dict:
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def target_size(config: dict) -> tuple[int, int]:
    target = config["targets"]["ios_65"]
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


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    src_w, src_h = image.size
    scale = max(target_w / src_w, target_h / src_h)
    resized = image.resize((round(src_w * scale), round(src_h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_phone(canvas: Image.Image, raw: Image.Image, box: tuple[int, int, int, int], radius: int) -> None:
    x, y, w, h = box
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(0, 0, 0, 72))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(shadow, (0, 18))

    frame = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    screenshot = cover_resize(raw.convert("RGB"), (w - 22, h - 22)).convert("RGBA")
    inner_mask = rounded_mask(screenshot.size, max(radius - 18, 30))
    frame.alpha_composite(screenshot, (11, 11))
    frame.putalpha(rounded_mask((w, h), radius))
    canvas.alpha_composite(frame, (x, y))


def render_shot(config: dict, locale: str, shot: dict) -> bool:
    raw_path = RAW_DIR / locale / f"{shot['id']}.png"
    if not raw_path.exists():
        print(f"warning: missing raw iOS screenshot: {raw_path}", file=sys.stderr)
        return False

    canvas_w, canvas_h = target_size(config)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), BACKGROUND + (255,))
    draw = ImageDraw.Draw(canvas)

    brand_font = font(34, "bold")
    title_font = font(74 if locale != "en" else 68, "bold")
    subtitle_font = font(35, "regular")

    draw.text((110, 96), config["app"]["name"], font=brand_font, fill=ACCENT)
    title = shot["title"][locale]
    subtitle = shot["subtitle"][locale]
    max_text_width = canvas_w - 220
    title_lines = wrap_text(draw, title, title_font, max_text_width)
    title_bottom = draw_multiline(draw, (110, 235), title_lines, title_font, INK, 10)
    subtitle_lines = wrap_text(draw, subtitle, subtitle_font, max_text_width)
    subtitle_bottom = draw_multiline(draw, (112, title_bottom + 18), subtitle_lines, subtitle_font, MUTED, 8)

    line_y = subtitle_bottom + 28
    draw.rounded_rectangle((112, line_y, 210, line_y + 8), radius=4, fill=ACCENT)

    raw = Image.open(raw_path)
    phone_w = 900 if shot["id"] == "00_preview" else 840
    phone_h = min(canvas_h - 760, round(phone_w * raw.height / raw.width))
    phone_top = 735 if shot["id"] == "00_preview" else 835
    phone_top = max(phone_top, line_y + 82)
    if phone_top + phone_h > canvas_h - 92:
        phone_h = canvas_h - phone_top - 92
        phone_w = round(phone_h * raw.width / raw.height)
    phone_x = (canvas_w - phone_w) // 2
    paste_phone(canvas, raw, (phone_x, phone_top, phone_w, phone_h), 72)

    out_dir = STORE_DIR / locale
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{shot['id']}.png"
    canvas.convert("RGB").save(out_path, "PNG")
    print(f"wrote {out_path.relative_to(ROOT)} ({canvas_w}x{canvas_h})")
    return True


def main() -> int:
    config = load_config()
    filters = set(sys.argv[1:])
    rendered = 0
    attempted = 0
    for locale in config["locales"]:
        if filters and locale not in filters:
            continue
        for shot in config["iosShots"]:
            attempted += 1
            if render_shot(config, locale, shot):
                rendered += 1
    if rendered == 0 and attempted:
        print("error: no iOS raw screenshots were found; cannot render marketing images", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
