#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG="$ROOT/tools/appstore-screenshots/config/screenshots.json"
STATUS_PATH="$ROOT/tools/appstore-screenshots/output/watch_status.json"

LOCALE_FILTERS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --locale)
      LOCALE_FILTERS+=("${2:?missing locale after --locale}")
      shift 2
      ;;
    *)
      echo "Unknown export_watch.sh argument: $1" >&2
      exit 2
      ;;
  esac
done

write_watch_status() {
  local skipped="$1"
  local reason="$2"
  python3 - "$STATUS_PATH" "$skipped" "$reason" <<'PY'
import json, sys
from datetime import datetime
path, skipped, reason = sys.argv[1], sys.argv[2] == "true", sys.argv[3]
payload = {
    "watchSkipped": skipped,
    "reason": reason,
    "rendered": 0,
    "generatedAt": datetime.now().isoformat(timespec="seconds"),
}
from pathlib import Path
p = Path(path)
p.parent.mkdir(parents=True, exist_ok=True)
p.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
PY
}

IFS=$'\t' read -r WATCH_ENABLED WORKSPACE SCHEME BUNDLE_ID DERIVED_REL WAIT_SECONDS APP_NAME < <(
  python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
print(
    cfg["app"]["watch"].get("enabled", "auto"),
    cfg["app"]["workspace"],
    cfg["app"]["watch"].get("scheme", ""),
    cfg["app"]["watch"].get("bundleId", ""),
    cfg.get("capture", {}).get("derivedDataPath", "tools/appstore-screenshots/.derivedData"),
    cfg.get("capture", {}).get("stabilizeSeconds", 2),
    cfg["app"]["watch"].get("scheme", "AutoLedgerWatch Watch App"),
    sep="\t",
)
PY
)

if [[ "$WATCH_ENABLED" == "false" ]]; then
  REASON="Watch export disabled in screenshots.json."
  echo "==> $REASON"
  write_watch_status true "$REASON"
  python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
  exit 0
fi

WORKSPACE_PATH="$ROOT/$WORKSPACE"
DERIVED_PATH="$ROOT/$DERIVED_REL"

if ! xcodebuild -list -workspace "$WORKSPACE_PATH" 2>/dev/null | grep -Fqx "        $SCHEME"; then
  REASON="Watch scheme '$SCHEME' was not found in the workspace."
  echo "==> $REASON"
  write_watch_status true "$REASON"
  python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
  exit 0
fi

PAIR_INFO="$(
  python3 - "$CONFIG" <<'PY'
import json, re, subprocess, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
candidates = cfg["app"]["watch"].get("deviceCandidates", [])
text = subprocess.check_output(["xcrun", "simctl", "list", "pairs"], text=True)
pairs = []
current = None
for line in text.splitlines():
    m = re.match(r"([0-9A-F-]{36}) \(active, .*", line)
    if m:
        current = {"pair": m.group(1)}
        pairs.append(current)
        continue
    if current is None:
        continue
    wm = re.match(r"\s+Watch: (.+?) \(([0-9A-F-]{36})\) \((Booted|Shutdown)\)", line)
    if wm:
        current["watch_name"] = wm.group(1)
        current["watch_udid"] = wm.group(2)
        continue
    pm = re.match(r"\s+Phone: (.+?) \(([0-9A-F-]{36})\) \((Booted|Shutdown)\)", line)
    if pm:
        current["phone_name"] = pm.group(1)
        current["phone_udid"] = pm.group(2)
for candidate in candidates:
    for pair in pairs:
        if pair.get("watch_name") == candidate and pair.get("watch_udid") and pair.get("phone_udid"):
            print(pair["watch_udid"], pair["watch_name"], pair["phone_udid"], pair.get("phone_name", ""), sep="\t")
            raise SystemExit(0)
for pair in pairs:
    if pair.get("watch_udid") and pair.get("phone_udid"):
        print(pair["watch_udid"], pair.get("watch_name", "Apple Watch"), pair["phone_udid"], pair.get("phone_name", "iPhone"), sep="\t")
        raise SystemExit(0)
print("No available Apple Watch simulator pair found.", file=sys.stderr)
raise SystemExit(1)
PY
)" || {
  REASON="No available Apple Watch simulator pair found."
  echo "==> $REASON"
  write_watch_status true "$REASON"
  python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
  exit 0
}

IFS=$'\t' read -r WATCH_UDID WATCH_NAME PHONE_UDID PHONE_NAME <<< "$PAIR_INFO"

echo "==> Building Watch app"
echo "workspace: $WORKSPACE"
echo "scheme: $SCHEME"
echo "bundle id: $BUNDLE_ID"
echo "watch: $WATCH_NAME ($WATCH_UDID)"
echo "phone pair: $PHONE_NAME ($PHONE_UDID)"

if ! xcodebuild \
  -workspace "$WORKSPACE_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$WATCH_UDID" \
  -derivedDataPath "$DERIVED_PATH" \
  build; then
  REASON="Watch scheme build failed; iPhone screenshots are still usable."
  echo "==> $REASON"
  write_watch_status true "$REASON"
  python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
  exit 0
fi

APP_PATH="$DERIVED_PATH/Build/Products/Debug-watchsimulator/$APP_NAME.app"
if [[ ! -d "$APP_PATH" ]]; then
  REASON="Built Watch app was not found at $APP_PATH."
  echo "==> $REASON"
  write_watch_status true "$REASON"
  python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
  exit 0
fi

echo "==> Booting Watch simulator pair"
xcrun simctl boot "$PHONE_UDID" 2>/dev/null || true
xcrun simctl boot "$WATCH_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$WATCH_UDID" -b || true

if ! xcrun simctl install "$WATCH_UDID" "$APP_PATH"; then
  REASON="Could not install Watch app on $WATCH_NAME. Use manual capture mode described in README."
  echo "==> $REASON"
  write_watch_status true "$REASON"
  python3 "$SCRIPT_DIR/render_watch.py"
  exit 0
fi

is_mostly_black_png() {
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
        width = 80
        height = max(1, round(width * image.height / image.width))
        image = image.resize((width, height))
        data = image.tobytes()
except OSError:
    raise SystemExit(0)

pixel_count = len(data) // 3
dark_pixels = 0
total = 0
for index in range(0, len(data), 3):
    red, green, blue = data[index], data[index + 1], data[index + 2]
    if red < 10 and green < 10 and blue < 10:
        dark_pixels += 1
    total += red + green + blue
mean = total / (pixel_count * 3)
raise SystemExit(0 if dark_pixels / pixel_count > 0.98 and mean < 8 else 1)
PY
}

capture_watch_screenshot() {
  local locale="$1"
  local apple_lang="$2"
  local apple_locale="$3"
  local shot_id="$4"
  local scene="$5"
  local out_path="$6"
  local tmp_path="$out_path.tmp"
  local attempts=5

  for attempt in $(seq 1 "$attempts"); do
    xcrun simctl terminate "$WATCH_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
    if ! xcrun simctl launch --terminate-running-process "$WATCH_UDID" "$BUNDLE_ID" \
      --screenshot-mode \
      --screenshot-platform watch \
      --screenshot-scene "$scene" \
      -AppleLanguages "$apple_lang" \
      -AppleLocale "$apple_locale" \
      -UIPreferredContentSizeCategoryName UICTContentSizeCategoryL >/dev/null; then
      return 2
    fi
    sleep "$WAIT_SECONDS"
    xcrun simctl io "$WATCH_UDID" screenshot "$tmp_path" >/dev/null
    if ! is_mostly_black_png "$tmp_path"; then
      mv "$tmp_path" "$out_path"
      return 0
    fi
    echo "warning: watch/$locale/$shot_id captured mostly black frame; retry $attempt/$attempts" >&2
    sleep 1
  done

  mv "$tmp_path" "$out_path"
  echo "warning: watch/$locale/$shot_id still looks mostly black after retries" >&2
}

echo "==> Capturing Watch raw screenshots"
CAPTURED=0
while IFS=$'\t' read -r LOCALE APPLE_LANG APPLE_LOCALE SHOT_ID SCENE; do
  OUT_DIR="$ROOT/tools/appstore-screenshots/output/raw/watch/$LOCALE"
  mkdir -p "$OUT_DIR"
  OUT_PATH="$OUT_DIR/$SHOT_ID.png"
  echo "capture watch/$LOCALE/$SHOT_ID ($SCENE)"
  if ! capture_watch_screenshot "$LOCALE" "$APPLE_LANG" "$APPLE_LOCALE" "$SHOT_ID" "$SCENE" "$OUT_PATH"; then
    REASON="Could not launch Watch app in screenshot mode. Use manual capture mode described in README."
    echo "==> $REASON"
    write_watch_status true "$REASON"
    python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
    exit 0
  fi
  CAPTURED=$((CAPTURED + 1))
done < <(
  python3 - "$CONFIG" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"} <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
filters = set(sys.argv[2:])
for locale, locale_cfg in cfg["locales"].items():
    if filters and locale not in filters:
        continue
    for shot in cfg["watchShots"]:
        print(locale, locale_cfg["appleLanguages"], locale_cfg["appleLocale"], shot["id"], shot["scene"], sep="\t")
PY
)

if [[ "$CAPTURED" -eq 0 ]]; then
  write_watch_status true "No Watch screenshots were captured."
else
  write_watch_status false ""
fi

python3 "$SCRIPT_DIR/render_watch.py" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
