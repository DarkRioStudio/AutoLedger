#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG="$ROOT/tools/appstore-screenshots/config/screenshots.json"
STATUS_PATH="$ROOT/tools/appstore-screenshots/output/mac_status.json"

LOCALE_FILTERS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --locale)
      LOCALE_FILTERS+=("${2:?missing locale after --locale}")
      shift 2
      ;;
    *)
      echo "Unknown export_mac.sh argument: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p "$(dirname "$STATUS_PATH")"

write_status() {
  python3 - "$STATUS_PATH" "$1" "$2" <<'PY'
import json, sys
path, skipped, reason = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "w", encoding="utf-8") as handle:
    json.dump({"macSkipped": skipped == "true", "reason": reason}, handle, ensure_ascii=False, indent=2)
PY
}

if ! osascript -e 'tell application "System Events" to return UI elements enabled' >/dev/null 2>&1; then
  reason="System Events accessibility is unavailable; skipping Mac screenshot export."
  echo "warning: $reason" >&2
  write_status true "$reason"
  exit 0
fi

IFS=$'\t' read -r WORKSPACE SCHEME DERIVED_REL APP_NAME WINDOW_WIDTH WINDOW_HEIGHT WAIT_SECONDS < <(
  python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
print(
    cfg["app"]["workspace"],
    cfg["app"]["mac"]["scheme"],
    cfg.get("capture", {}).get("derivedDataPath", "tools/appstore-screenshots/.derivedData") + "-mac",
    cfg["app"]["name"],
    cfg["app"]["mac"].get("windowWidth", 1440),
    cfg["app"]["mac"].get("windowHeight", 900),
    cfg.get("capture", {}).get("stabilizeSeconds", 2),
    sep="\t",
)
PY
)

DERIVED_PATH="$ROOT/$DERIVED_REL"
WORKSPACE_PATH="$ROOT/$WORKSPACE"

echo "==> Building Mac Catalyst app"
echo "workspace: $WORKSPACE"
echo "scheme: $SCHEME"

if ! xcodebuild \
  -workspace "$WORKSPACE_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "platform=macOS,variant=Mac Catalyst" \
  -derivedDataPath "$DERIVED_PATH" \
  build; then
  reason="Mac Catalyst build failed; skipping Mac screenshot export."
  echo "warning: $reason" >&2
  write_status true "$reason"
  exit 0
fi

APP_PATH="$DERIVED_PATH/Build/Products/Debug-maccatalyst/$APP_NAME.app"
APP_EXECUTABLE="$APP_PATH/Contents/MacOS/$APP_NAME"
if [[ ! -x "$APP_EXECUTABLE" ]]; then
  reason="Built Mac Catalyst app executable was not found at $APP_EXECUTABLE."
  echo "warning: $reason" >&2
  write_status true "$reason"
  exit 0
fi

quit_existing_app() {
  osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
}

capture_mac_screenshot() {
  local locale="$1"
  local apple_lang="$2"
  local apple_locale="$3"
  local shot_id="$4"
  local scene="$5"
  local out_path="$6"
  local tmp_path="$out_path.tmp"

  quit_existing_app

  "$APP_EXECUTABLE" \
    --screenshot-mode \
    --screenshot-platform mac \
    --screenshot-scene "$scene" \
    -AppleLanguages "$apple_lang" \
    -AppleLocale "$apple_locale" \
    -UIPreferredContentSizeCategoryName UICTContentSizeCategoryL >/dev/null 2>&1 &
  local app_pid=$!
  sleep "$WAIT_SECONDS"

  local bounds
  if ! bounds=$(
    osascript <<OSA
tell application "$APP_NAME" to activate
delay 0.8
tell application "System Events"
  tell process "$APP_NAME"
    set frontmost to true
    delay 0.6
    try
      set position of front window to {80, 80}
      set size of front window to {$WINDOW_WIDTH, $WINDOW_HEIGHT}
    end try
    delay 0.6
    set {xPos, yPos} to position of front window
    set {winWidth, winHeight} to size of front window
    return (xPos as text) & "," & (yPos as text) & "," & (winWidth as text) & "," & (winHeight as text)
  end tell
end tell
OSA
  ); then
    kill "$app_pid" >/dev/null 2>&1 || true
    wait "$app_pid" >/dev/null 2>&1 || true
    return 1
  fi

  IFS=, read -r x_pos y_pos win_width win_height <<< "$bounds"
  local window_id
  window_id=$(
    swift - "$APP_NAME" <<'SWIFT'
import CoreGraphics
import Foundation

let appName = CommandLine.arguments[1]
guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

let candidates = windows.compactMap { info -> (id: Int, area: Double)? in
    guard
        let owner = info[kCGWindowOwnerName as String] as? String,
        owner == appName,
        let number = info[kCGWindowNumber as String] as? Int,
        let layer = info[kCGWindowLayer as String] as? Int,
        layer == 0,
        let bounds = info[kCGWindowBounds as String] as? [String: Any],
        let width = bounds["Width"] as? Double,
        let height = bounds["Height"] as? Double,
        width > 200,
        height > 200
    else {
        return nil
    }
    return (number, width * height)
}

guard let best = candidates.max(by: { $0.area < $1.area }) else {
    exit(1)
}
print(best.id)
SWIFT
  )
  if [[ -z "$window_id" ]]; then
    kill "$app_pid" >/dev/null 2>&1 || true
    wait "$app_pid" >/dev/null 2>&1 || true
    return 1
  fi

  screencapture -x -l "$window_id" "$tmp_path"
  mv "$tmp_path" "$out_path"

  kill "$app_pid" >/dev/null 2>&1 || true
  wait "$app_pid" >/dev/null 2>&1 || true
  return 0
}

echo "==> Capturing Mac raw screenshots"
while IFS=$'\t' read -r LOCALE APPLE_LANG APPLE_LOCALE SHOT_ID SCENE; do
  OUT_DIR="$ROOT/tools/appstore-screenshots/output/raw/mac/$LOCALE"
  mkdir -p "$OUT_DIR"
  OUT_PATH="$OUT_DIR/$SHOT_ID.png"
  echo "capture mac/$LOCALE/$SHOT_ID ($SCENE)"
  if ! capture_mac_screenshot "$LOCALE" "$APPLE_LANG" "$APPLE_LOCALE" "$SHOT_ID" "$SCENE" "$OUT_PATH"; then
    reason="Mac window capture failed. Check Accessibility permissions for System Events and rerun."
    echo "warning: $reason" >&2
    write_status true "$reason"
    exit 0
  fi
done < <(
  python3 - "$CONFIG" ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"} <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
filters = set(sys.argv[2:])
for locale, locale_cfg in cfg["locales"].items():
    if filters and locale not in filters:
        continue
    for shot in cfg["macShots"]:
        print(locale, locale_cfg["appleLanguages"], locale_cfg["appleLocale"], shot["id"], shot["scene"], sep="\t")
PY
)

write_status false ""
python3 "$SCRIPT_DIR/render_marketing.py" --platform mac ${LOCALE_FILTERS[@]+"${LOCALE_FILTERS[@]}"}
