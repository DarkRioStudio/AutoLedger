#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG="$ROOT/tools/appstore-screenshots/config/screenshots.json"

LOCALE_FILTERS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --locale)
      LOCALE_FILTERS+=("${2:?missing locale after --locale}")
      shift 2
      ;;
    *)
      echo "Unknown export_visionos.sh argument: $1" >&2
      exit 2
      ;;
  esac
done

IFS=$'\t' read -r WORKSPACE SCHEME BUNDLE_ID PRODUCT_NAME DERIVED_REL WAIT_SECONDS < <(
  python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
app = cfg["app"]["visionos"]
print(
    cfg["app"]["workspace"],
    app["scheme"],
    app["bundleId"],
    app.get("productName", app["scheme"]),
    cfg.get("capture", {}).get("derivedDataPath", "tools/appstore-screenshots/.derivedData") + "-visionos",
    cfg.get("capture", {}).get("stabilizeSeconds", 2),
    sep="\t",
)
PY
)

DERIVED_PATH="$ROOT/$DERIVED_REL"
WORKSPACE_PATH="$ROOT/$WORKSPACE"

read -r DEVICE_UDID DEVICE_NAME < <(
  python3 - "$CONFIG" <<'PY'
import json, re, subprocess, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
text = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available"], text=True)
devices = []
for line in text.splitlines():
    m = re.match(r"\s+(.+?) \(([0-9A-F-]{36})\) \((Booted|Shutdown)\)", line)
    if m and m.group(1).startswith("Apple Vision"):
        devices.append((m.group(1), m.group(2)))
for candidate in cfg["app"]["visionos"].get("deviceCandidates", []):
    for name, udid in devices:
        if name == candidate:
            print(udid, name, sep="\t")
            raise SystemExit(0)
if devices:
    print(devices[0][1], devices[0][0], sep="\t")
    raise SystemExit(0)
print("No available Apple Vision Pro simulator found.", file=sys.stderr)
raise SystemExit(1)
PY
)

echo "==> Building visionOS app"
echo "workspace: $WORKSPACE"
echo "scheme: $SCHEME"
echo "bundle id: $BUNDLE_ID"
echo "device: $DEVICE_NAME ($DEVICE_UDID)"

xcodebuild \
  -workspace "$WORKSPACE_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED_PATH" \
  build

APP_PATH="$(
  find "$DERIVED_PATH/Build/Products" -type d -name "$PRODUCT_NAME.app" -print -quit 2>/dev/null || true
)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Could not find built visionOS app named $PRODUCT_NAME.app under $DERIVED_PATH/Build/Products" >&2
  exit 1
fi

echo "==> Booting and installing on $DEVICE_NAME"
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_UDID" -b
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

is_incomplete_png() {
  python3 - "$1" <<'PY'
import sys
from PIL import Image

path = sys.argv[1]
try:
    with Image.open(path) as image:
        image = image.convert("RGB")
        width = 120
        height = max(1, round(width * image.height / image.width))
        image = image.resize((width, height))
        data = image.tobytes()
except OSError:
    raise SystemExit(0)

pixel_count = len(data) // 3
dark_pixels = 0
light_pixels = 0
total = 0
for index in range(0, len(data), 3):
    red, green, blue = data[index], data[index + 1], data[index + 2]
    if red < 16 and green < 16 and blue < 16:
        dark_pixels += 1
    if red > 242 and green > 242 and blue > 242:
        light_pixels += 1
    total += red + green + blue
mean = total / (pixel_count * 3)
is_dark = dark_pixels / pixel_count > 0.94 and mean < 24
is_blank = light_pixels / pixel_count > 0.94 and mean > 240
raise SystemExit(0 if is_dark or is_blank else 1)
PY
}

capture_visionos_screenshot() {
  local locale="$1"
  local apple_lang="$2"
  local apple_locale="$3"
  local shot_id="$4"
  local scene="$5"
  local out_path="$6"
  local tmp_path="$out_path.tmp"
  local attempts=5

  for attempt in $(seq 1 "$attempts"); do
    xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    xcrun simctl launch --terminate-running-process "$DEVICE_UDID" "$BUNDLE_ID" \
      --screenshot-mode \
      --screenshot-platform visionos \
      --screenshot-scene "$scene" \
      -AppleLanguages "$apple_lang" \
      -AppleLocale "$apple_locale" \
      -UIPreferredContentSizeCategoryName UICTContentSizeCategoryL >/dev/null
    sleep "$WAIT_SECONDS"
    xcrun simctl io "$DEVICE_UDID" screenshot "$tmp_path" >/dev/null
    if ! is_incomplete_png "$tmp_path"; then
      mv "$tmp_path" "$out_path"
      return 0
    fi
    echo "warning: visionos/$locale/$shot_id captured incomplete frame; retry $attempt/$attempts" >&2
    sleep 1
  done

  mv "$tmp_path" "$out_path"
  echo "warning: visionos/$locale/$shot_id still looks incomplete after retries" >&2
}

echo "==> Capturing visionOS raw screenshots"
while IFS=$'\t' read -r LOCALE APPLE_LANG APPLE_LOCALE SHOT_ID SCENE; do
  OUT_DIR="$ROOT/tools/appstore-screenshots/output/raw/visionos/$LOCALE"
  mkdir -p "$OUT_DIR"
  OUT_PATH="$OUT_DIR/$SHOT_ID.png"
  echo "capture visionos/$LOCALE/$SHOT_ID ($SCENE)"
  capture_visionos_screenshot "$LOCALE" "$APPLE_LANG" "$APPLE_LOCALE" "$SHOT_ID" "$SCENE" "$OUT_PATH"
done < <(
  python3 - "$CONFIG" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"} <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
filters = set(sys.argv[2:])
for locale, locale_cfg in cfg["locales"].items():
    if filters and locale not in filters:
        continue
    for shot in cfg["visionosShots"]:
        print(locale, locale_cfg["appleLanguages"], locale_cfg["appleLocale"], shot["id"], shot["scene"], sep="\t")
PY
)

python3 "$SCRIPT_DIR/render_marketing.py" --platform visionos ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
