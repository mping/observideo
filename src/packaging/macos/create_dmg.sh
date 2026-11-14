#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
app="$project_dir/build/macos/Build/Products/Release/observideo.app"
output="$project_dir/build/Observideo-flutter-macos-arm64.dmg"
identity=${OBSERVIDEO_CODESIGN_IDENTITY:?Set OBSERVIDEO_CODESIGN_IDENTITY}
notary_profile=${OBSERVIDEO_NOTARY_PROFILE:?Set OBSERVIDEO_NOTARY_PROFILE}

test -d "$app"
find "$app/Contents/Frameworks" -type f \( -name '*.dylib' -o -name Mpv \) \
  -exec codesign --force --options runtime --timestamp --sign "$identity" {} \;
codesign --force --deep --options runtime --timestamp --sign "$identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
hdiutil create -volname Observideo -srcfolder "$app" -ov -format UDZO "$output"
xcrun notarytool submit "$output" --keychain-profile "$notary_profile" --wait
xcrun stapler staple "$output"
