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
      echo "Unknown export_ipad.sh argument: $1" >&2
      exit 2
      ;;
  esac
done

IFS=$'\t' read -r WORKSPACE SCHEME BUNDLE_ID DERIVED_REL WAIT_SECONDS APP_NAME < <(
  python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
print(
    cfg["app"]["workspace"],
    cfg["app"]["ipad"]["scheme"],
    cfg["app"]["ipad"]["bundleId"],
    cfg.get("capture", {}).get("derivedDataPath", "tools/appstore-screenshots/.derivedData"),
    cfg.get("capture", {}).get("stabilizeSeconds", 2),
    cfg["app"]["name"],
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
    if m and m.group(1).startswith("iPad"):
        devices.append((m.group(1), m.group(2)))
for candidate in cfg["app"]["ipad"].get("deviceCandidates", []):
    for name, udid in devices:
        if name == candidate:
            print(udid, name, sep="\t")
            raise SystemExit(0)
if devices:
    print(devices[0][1], devices[0][0], sep="\t")
    raise SystemExit(0)
print("No available iPad simulator found.", file=sys.stderr)
raise SystemExit(1)
PY
)

echo "==> Building iPad app"
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

APP_PATH="$DERIVED_PATH/Build/Products/Debug-iphonesimulator/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Could not find built iPad app at: $APP_PATH" >&2
  exit 1
fi

echo "==> Booting and installing on $DEVICE_NAME"
xcrun simctl boot "$DEVICE_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_UDID" -b
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
xcrun simctl status_bar "$DEVICE_UDID" override \
  --time 9:41 \
  --dataNetwork wifi \
  --wifiBars 3 \
  --cellularBars 4 \
  --batteryState charged \
  --batteryLevel 100 >/dev/null 2>&1 || true

is_incomplete_png() {
  python3 - "$1" <<'PY'
import sys
try:
    from PIL import Image
except ImportError:
    raise SystemExit(1)

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
    if red < 24 and green < 24 and blue < 24:
        dark_pixels += 1
    if red > 242 and green > 242 and blue > 242:
        light_pixels += 1
    total += red + green + blue
mean = total / (pixel_count * 3)
is_dark = dark_pixels / pixel_count > 0.92 and mean < 32
is_blank = light_pixels / pixel_count > 0.92 and mean > 240
raise SystemExit(0 if is_dark or is_blank else 1)
PY
}

capture_ipad_screenshot() {
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
      --screenshot-platform ipad \
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
    echo "warning: ipad/$locale/$shot_id captured incomplete frame; retry $attempt/$attempts" >&2
    sleep 1
  done

  mv "$tmp_path" "$out_path"
  echo "warning: ipad/$locale/$shot_id still looks incomplete after retries" >&2
}

echo "==> Capturing iPad raw screenshots"
while IFS=$'\t' read -r LOCALE APPLE_LANG APPLE_LOCALE SHOT_ID SCENE; do
  OUT_DIR="$ROOT/tools/appstore-screenshots/output/raw/ipad/$LOCALE"
  mkdir -p "$OUT_DIR"
  OUT_PATH="$OUT_DIR/$SHOT_ID.png"
  echo "capture ipad/$LOCALE/$SHOT_ID ($SCENE)"
  capture_ipad_screenshot "$LOCALE" "$APPLE_LANG" "$APPLE_LOCALE" "$SHOT_ID" "$SCENE" "$OUT_PATH"
done < <(
  python3 - "$CONFIG" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"} <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
filters = set(sys.argv[2:])
for locale, locale_cfg in cfg["locales"].items():
    if filters and locale not in filters:
        continue
    for shot in cfg["ipadShots"]:
        print(locale, locale_cfg["appleLanguages"], locale_cfg["appleLocale"], shot["id"], shot["scene"], sep="\t")
PY
)

python3 "$SCRIPT_DIR/render_marketing.py" --platform ipad ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
