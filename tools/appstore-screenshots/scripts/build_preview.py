#!/usr/bin/env python3
from __future__ import annotations

import html
import json
from datetime import datetime
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    Image = None


ROOT = Path(__file__).resolve().parents[3]
TOOL_DIR = ROOT / "tools" / "appstore-screenshots"
OUTPUT_DIR = TOOL_DIR / "output"
STORE_DIR = OUTPUT_DIR / "store"
CONFIG_PATH = TOOL_DIR / "config" / "screenshots.json"
WATCH_STATUS_PATH = OUTPUT_DIR / "watch_status.json"
MAC_STATUS_PATH = OUTPUT_DIR / "mac_status.json"
PREVIEW_PATH = OUTPUT_DIR / "preview.html"


def load_config() -> dict:
    with CONFIG_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def image_size(path: Path) -> str:
    if Image is None:
        return ""
    try:
        with Image.open(path) as image:
            return f"{image.width}x{image.height}"
    except OSError:
        return ""


def rel(path: Path) -> str:
    return path.relative_to(OUTPUT_DIR).as_posix()


def image_cards(platform: str, locale: str) -> str:
    folder = STORE_DIR / platform / locale
    if not folder.exists():
        return '<p class="empty">No rendered screenshots yet.</p>'
    images = sorted(folder.glob("*.png"))
    if not images:
        return '<p class="empty">No rendered screenshots yet.</p>'
    cards = []
    for path in images:
        cards.append(
            f"""
            <figure class="card {html.escape(platform)}">
              <img src="{html.escape(rel(path))}" alt="{html.escape(path.name)}">
              <figcaption>
                <strong>{html.escape(path.name)}</strong>
                <span>{html.escape(image_size(path))}</span>
              </figcaption>
            </figure>
            """
        )
    return "\n".join(cards)


def watch_status_html() -> str:
    if not WATCH_STATUS_PATH.exists():
        return ""
    try:
        status = json.loads(WATCH_STATUS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return ""
    if not status.get("watchSkipped"):
        reason = status.get("reason")
        if not reason:
            return ""
        return f'<p class="notice">Apple Watch: {html.escape(reason)}</p>'
    reason = status.get("reason") or "Watch export skipped."
    return f'<p class="notice skipped">Apple Watch skipped: {html.escape(reason)}</p>'


def mac_status_html() -> str:
    if not MAC_STATUS_PATH.exists():
        return ""
    try:
        status = json.loads(MAC_STATUS_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return ""
    if not status.get("macSkipped"):
        reason = status.get("reason")
        if not reason:
            return ""
        return f'<p class="notice">Mac: {html.escape(reason)}</p>'
    reason = status.get("reason") or "Mac export skipped."
    return f'<p class="notice skipped">Mac skipped: {html.escape(reason)}</p>'


def locale_section(platform: str, locale: str) -> str:
    return f"""
    <section>
      <h3>{html.escape(locale)}</h3>
      <div class="grid {html.escape(platform)}-grid">
        {image_cards(platform, locale)}
      </div>
    </section>
    """


def main() -> int:
    config = load_config()
    locales = list(config["locales"].keys())
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    ios_sections = "\n".join(locale_section("ios", locale) for locale in locales)
    watch_sections = "\n".join(locale_section("watch", locale) for locale in locales)
    ipad_sections = "\n".join(locale_section("ipad", locale) for locale in locales)
    mac_sections = "\n".join(locale_section("mac", locale) for locale in locales)
    tvos_sections = "\n".join(locale_section("tvos", locale) for locale in locales)
    visionos_sections = "\n".join(locale_section("visionos", locale) for locale in locales)
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    html_text = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <link rel="icon" href="data:,">
  <title>AutoLedger App Store Screenshots</title>
  <style>
    :root {{
      color-scheme: light;
      --bg: #f3f0e8;
      --ink: #222825;
      --muted: #65706a;
      --card: rgba(255,255,255,0.82);
      --accent: #2b7857;
      --line: rgba(34,40,37,0.12);
    }}
    body {{
      margin: 0;
      background: var(--bg);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Helvetica Neue", Arial, sans-serif;
    }}
    header {{
      padding: 32px 36px 18px;
      border-bottom: 1px solid var(--line);
    }}
    h1 {{
      margin: 0 0 8px;
      font-size: 30px;
    }}
    h2 {{
      margin: 36px 36px 8px;
      font-size: 24px;
    }}
    h3 {{
      margin: 22px 36px 14px;
      font-size: 18px;
      color: var(--muted);
    }}
    .meta {{
      margin: 0;
      color: var(--muted);
    }}
    .notice {{
      margin: 12px 36px 0;
      padding: 12px 14px;
      border: 1px solid var(--line);
      border-left: 5px solid var(--accent);
      background: var(--card);
      border-radius: 8px;
      color: var(--muted);
    }}
    .skipped {{
      border-left-color: #b36b1d;
    }}
    .grid {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 18px;
      padding: 0 36px 22px;
    }}
    .watch-grid {{
      grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    }}
    .card {{
      margin: 0;
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 8px;
      overflow: hidden;
      box-shadow: 0 10px 24px rgba(34,40,37,0.08);
    }}
    .card img {{
      display: block;
      width: 100%;
      height: auto;
      background: #111;
    }}
    .card.watch img {{
      object-fit: contain;
      padding: 10px;
      box-sizing: border-box;
    }}
    figcaption {{
      display: flex;
      justify-content: space-between;
      gap: 10px;
      padding: 10px 12px;
      font-size: 12px;
      color: var(--muted);
    }}
    figcaption strong {{
      color: var(--ink);
      overflow-wrap: anywhere;
    }}
    .empty {{
      margin: 0;
      padding: 18px 36px;
      color: var(--muted);
    }}
  </style>
</head>
<body>
  <header>
    <h1>AutoLedger App Store Screenshots</h1>
    <p class="meta">Generated at {html.escape(generated_at)}</p>
  </header>

  <h2>iPhone</h2>
  {ios_sections}

  <h2>Apple Watch</h2>
  {watch_status_html()}
  {watch_sections}

  <h2>iPad</h2>
  {ipad_sections}

  <h2>Mac</h2>
  {mac_status_html()}
  {mac_sections}

  <h2>Apple TV</h2>
  {tvos_sections}

  <h2>visionOS</h2>
  {visionos_sections}
</body>
</html>
"""
    PREVIEW_PATH.write_text(html_text, encoding="utf-8")
    print(f"wrote {PREVIEW_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
