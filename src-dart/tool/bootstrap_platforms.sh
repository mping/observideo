#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
required_flutter='3.47.3'

actual_flutter=$(flutter --version --machine | sed -n 's/.*"frameworkVersion":"\([^"]*\)".*/\1/p')
if [ "$actual_flutter" != "$required_flutter" ]; then
  echo "Flutter $required_flutter is required; found ${actual_flutter:-unknown}." >&2
  exit 1
fi

cd "$project_dir"
flutter create --platforms=linux,macos,windows --project-name observideo --org org.observideo .

# The application must access arbitrary user-selected video folders.
if [ -f macos/Runner/DebugProfile.entitlements ]; then
  /usr/libexec/PlistBuddy -c 'Set :com.apple.security.app-sandbox false' macos/Runner/DebugProfile.entitlements 2>/dev/null || true
fi
if [ -f macos/Runner/Release.entitlements ]; then
  /usr/libexec/PlistBuddy -c 'Set :com.apple.security.app-sandbox false' macos/Runner/Release.entitlements 2>/dev/null || true
fi

echo "Desktop runners are ready. Generated platform directories are intentionally ignored."

