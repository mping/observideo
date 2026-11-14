#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
bundle="$project_dir/build/linux/x64/release/bundle"
appdir="$project_dir/build/appimage/Observideo.AppDir"
linuxdeploy=${LINUXDEPLOY:?Set LINUXDEPLOY to a pinned linuxdeploy executable}

test -x "$bundle/observideo"
rm -rf "$appdir"
mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
cp -R "$bundle/." "$appdir/usr/bin/"
cp "$project_dir/packaging/linux/observideo.desktop" "$appdir/usr/share/applications/"
cp "$project_dir/macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png" \
  "$appdir/usr/share/icons/hicolor/256x256/apps/observideo.png"
"$linuxdeploy" --appdir "$appdir"
# linuxdeploy copies the bundle's libraries into usr/lib and points the
# executable there. Link the bundle's copies to those so the AppImage carries
# one of each; libapp.so and dlopen-only native assets have no copy and stay.
for library in "$appdir/usr/bin/lib"/*.so*; do
  [ -L "$library" ] && continue
  soname=$(objdump -p "$library" | awk '$1 == "SONAME" { print $2 }')
  [ -n "$soname" ] && [ -e "$appdir/usr/lib/$soname" ] || continue
  ln -sf "../../lib/$soname" "$library"
done
"$linuxdeploy" --appdir "$appdir" --output appimage
