#!/bin/sh
set -e

retry() {
  attempts="$1"
  shift
  attempt=1

  until "$@"; do
    status=$?
    if [ "$attempt" -ge "$attempts" ]; then
      return "$status"
    fi

    delay=$((attempt * 10))
    echo ">>> Command failed with exit code $status. Retrying in ${delay}s (${attempt}/${attempts})..."
    sleep "$delay"
    attempt=$((attempt + 1))
  done
}

if ! command -v pod >/dev/null 2>&1; then
  echo ">>> Installing CocoaPods..."
  retry 3 brew install cocoapods || retry 3 sudo gem install cocoapods
fi

export COCOAPODS_DISABLE_STATS=1
pod --version

echo ">>> Running pod install..."
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$REPO_ROOT/AutoLedger"

if retry 3 pod install --deployment; then
  echo ">>> CocoaPods setup complete."
  exit 0
fi

echo ">>> pod install --deployment failed. Retrying with --repo-update for stale CocoaPods spec cache..."
retry 3 pod install --deployment --repo-update

echo ">>> CocoaPods setup complete."
