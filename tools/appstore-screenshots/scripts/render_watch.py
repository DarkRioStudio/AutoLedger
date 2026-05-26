#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow is required. Install with: python3 -m pip install Pillow", file=sys.stderr)
    raise


ROOT = Path(__file__).resolve().parents[3]
TOOL_DIR = ROOT / "tools" / "appstore-screenshots"
CONFIG_PATH = TOOL_DIR / "config" / "screenshots.json"
RAW_DIR = TOOL_DIR / "output" / "raw" / "watch"
STORE_DIR = TOOL_DIR / "output" / "store" / "watch"
STATUS_PATH = TOOL_DIR / "output" / "watch_status.json"


def load_config() -> dict:
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_status(skipped: bool, reason: str, rendered: int) -> None:
    STATUS_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "watchSkipped": skipped,
        "reason": reason,
        "rendered": rendered,
        "generatedAt": datetime.now().isoformat(timespec="seconds"),
    }
    STATUS_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def contain_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    src_w, src_h = image.size
    scale = min(target_w / src_w, target_h / src_h)
    resized = image.resize((round(src_w * scale), round(src_h * scale)), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, (0, 0, 0))
    canvas.paste(resized.convert("RGB"), ((target_w - resized.width) // 2, (target_h - resized.height) // 2))
    return canvas


def render_one(raw_path: Path, out_path: Path, size: tuple[int, int]) -> bool:
    image = Image.open(raw_path)
    if image.size == size:
        output = image.convert("RGB")
    else:
        print(f"watch resize: {raw_path.name} {image.width}x{image.height} -> {size[0]}x{size[1]}")
        output = contain_resize(image, size)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    output.save(out_path, "PNG")
    print(f"wrote {out_path.relative_to(ROOT)} ({size[0]}x{size[1]})")
    return True


def main() -> int:
    config = load_config()
    filters = set(sys.argv[1:])
    target = config["targets"]["watch"]
    size = (int(target["width"]), int(target["height"]))

    rendered = 0
    missing = 0
    for locale in config["locales"]:
        if filters and locale not in filters:
            continue
        for shot in config["watchShots"]:
            raw_path = RAW_DIR / locale / f"{shot['id']}.png"
            if not raw_path.exists():
                missing += 1
                print(f"warning: missing raw Watch screenshot: {raw_path}", file=sys.stderr)
                continue
            out_path = STORE_DIR / locale / f"{shot['id']}.png"
            if render_one(raw_path, out_path, size):
                rendered += 1

    if rendered == 0:
        reason = "No raw Watch screenshots found. Run export_watch.sh or capture Watch raw screenshots manually."
        if STATUS_PATH.exists():
            try:
                current = json.loads(STATUS_PATH.read_text(encoding="utf-8"))
                reason = current.get("reason") or reason
            except json.JSONDecodeError:
                pass
        write_status(True, reason, rendered)
        print(f"warning: Watch render skipped: {reason}", file=sys.stderr)
        return 0

    reason = "" if missing == 0 else f"Rendered {rendered} Watch screenshots; {missing} raw files were missing."
    write_status(False, reason, rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
