#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
bundle="$project_dir/build/linux/x64/release/bundle"
appdir="$project_dir/build/appimage/Observideo.AppDir"
linuxdeploy=${LINUXDEPLOY:?Set LINUXDEPLOY to a pinned linuxdeploy executable}

test -x "$bundle/observideo"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
cp -R "$bundle/." "$appdir/usr/bin/"
cp "$project_dir/packaging/linux/observideo.desktop" "$appdir/usr/share/applications/"
cp "$project_dir/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png" \
  "$appdir/usr/share/icons/hicolor/256x256/apps/observideo.png"
"$linuxdeploy" --appdir "$appdir" --output appimage
