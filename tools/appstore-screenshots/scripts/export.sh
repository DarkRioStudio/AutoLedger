#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG="$ROOT/tools/appstore-screenshots/config/screenshots.json"
OUTPUT_DIR="$ROOT/tools/appstore-screenshots/output"

IOS_ONLY=false
WATCH_ONLY=false
RENDER_ONLY=false
LOCALE_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ios-only)
      IOS_ONLY=true
      shift
      ;;
    --watch-only)
      WATCH_ONLY=true
      shift
      ;;
    --render-only)
      RENDER_ONLY=true
      shift
      ;;
    --locale)
      LOCALE_ARGS+=(--locale "${2:?missing locale after --locale}")
      shift 2
      ;;
    -h|--help)
      cat <<'EOF'
Usage: bash tools/appstore-screenshots/scripts/export.sh [options]

Options:
  --ios-only       Capture and render iPhone screenshots only.
  --watch-only     Capture and render Apple Watch screenshots only.
  --render-only    Re-render store images and preview.html from existing raw screenshots.
  --locale LOCALE  Limit capture to zh-Hans or en. Can be repeated.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

cd "$ROOT"

for bin in python3 xcodebuild xcrun; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "Missing required command: $bin" >&2
    exit 1
  fi
done

if ! python3 - <<'PY'
import PIL
PY
then
  echo "Pillow is required. Install with: python3 -m pip install Pillow" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing config: $CONFIG" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

if [[ "$RENDER_ONLY" == true ]]; then
  python3 "$SCRIPT_DIR/render_marketing.py"
  python3 "$SCRIPT_DIR/render_watch.py"
  python3 "$SCRIPT_DIR/build_preview.py"
  echo "Output: $OUTPUT_DIR"
  echo "Preview: $OUTPUT_DIR/preview.html"
  exit 0
fi

if [[ "$IOS_ONLY" == true && "$WATCH_ONLY" == true ]]; then
  echo "--ios-only and --watch-only cannot be used together." >&2
  exit 2
fi

if [[ "$WATCH_ONLY" != true ]]; then
  bash "$SCRIPT_DIR/export_ios.sh" ${LOCALE_ARGS[@]+"${LOCALE_ARGS[@]}"}
fi

if [[ "$IOS_ONLY" != true ]]; then
  bash "$SCRIPT_DIR/export_watch.sh" ${LOCALE_ARGS[@]+"${LOCALE_ARGS[@]}"}
fi

python3 "$SCRIPT_DIR/build_preview.py"

echo "Output: $OUTPUT_DIR"
echo "Preview: $OUTPUT_DIR/preview.html"
