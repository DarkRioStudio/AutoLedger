#!/bin/sh
set -e

echo ">>> Installing CocoaPods..."
brew install cocoapods 2>/dev/null || true

echo ">>> Running pod install..."
cd "$CI_PRIMARY_REPOSITORY_PATH/AutoLedger"
pod install --repo-update

echo ">>> CocoaPods setup complete."
