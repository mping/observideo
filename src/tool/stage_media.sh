#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$platform" in darwin) platform=macos ;; linux) exit 0 ;; *) exit 0 ;; esac
case "$arch" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=x64 ;; esac
media_root=${OBSERVIDEO_MEDIA_ROOT:-"$project_dir/native/media/out/$platform-$arch"}
framework="$project_dir/vendor/media_kit_libs_macos_video/macos/Frameworks/Mpv.framework"
framework_version="$framework/Versions/A"
libraries="$project_dir/vendor/media_kit_libs_macos_video/macos/Libraries"
mpv_search_root="$project_dir/vendor/media_kit_libs_macos_video/macos/Frameworks/.symlinks/mpv"

libmpv=$(find "$media_root/lib" -maxdepth 1 -name 'libmpv*.dylib' -type f | head -n 1)
if [ -z "$libmpv" ]; then
  echo "No controlled libmpv dylib found under $media_root/lib." >&2
  exit 1
fi

mkdir -p "$framework/Versions/A"
if [ -e "$framework/Mpv" ] && [ ! -L "$framework/Mpv" ]; then
  mv "$framework/Mpv" "$framework_version/Mpv"
fi
if [ -d "$framework/Headers" ] && [ ! -L "$framework/Headers" ]; then
  mv "$framework/Headers" "$framework_version/Headers"
fi
if [ -d "$framework/Resources" ] && [ ! -L "$framework/Resources" ]; then
  mv "$framework/Resources" "$framework_version/Resources"
fi
mkdir -p "$framework_version/Headers/mpv" "$framework_version/Resources" "$libraries"
mkdir -p "$mpv_search_root"
cp "$libmpv" "$framework_version/Mpv"
cp -R "$media_root/include/mpv/." "$framework_version/Headers/mpv/"
cp "$project_dir/native/media/Mpv.Info.plist" "$framework_version/Resources/Info.plist"
ln -sfn A "$framework/Versions/Current"
ln -sfn Versions/Current/Mpv "$framework/Mpv"
ln -sfn Versions/Current/Headers "$framework/Headers"
ln -sfn Versions/Current/Resources "$framework/Resources"
find "$media_root/lib" -maxdepth 1 -name '*.dylib' ! -name 'libmpv*.dylib' -exec cp {} "$libraries/" \;
install_name_tool -id '@rpath/Mpv.framework/Mpv' "$framework_version/Mpv"
if [ -L "$mpv_search_root/macos" ]; then
  unlink "$mpv_search_root/macos"
fi
mkdir -p "$mpv_search_root/macos"
ln -sfn ../../../Mpv.framework "$mpv_search_root/macos/Mpv.framework"

for dylib in "$libraries"/*.dylib; do
  [ -e "$dylib" ] || continue
  install_name_tool -id "@rpath/$(basename "$dylib")" "$dylib"
done
for binary in "$framework_version/Mpv" "$libraries"/*.dylib; do
  [ -e "$binary" ] || continue
  otool -L "$binary" | awk -v root="$media_root/lib/" 'index($1, root) == 1 { print $1 }' | while IFS= read -r dependency; do
    install_name_tool -change "$dependency" "@rpath/$(basename "$dependency")" "$binary"
  done
done
