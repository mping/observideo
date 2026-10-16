#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$platform" in
  darwin) platform=macos ;;
  linux) ;;
  *) echo "Use tool/build_windows.ps1 on Windows." >&2; exit 1 ;;
esac
case "$arch" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64) arch=x64 ;;
esac

media_root="$project_dir/native/media/out/$platform-$arch"
test -x "$media_root/bin/ffprobe"
test -f "$media_root/share/observideo/codec-manifest.json"

cd "$project_dir"
OBSERVIDEO_MEDIA_ROOT="$media_root" ./tool/stage_media.sh
PKG_CONFIG_PATH="$media_root/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
  OBSERVIDEO_MEDIA_ROOT="$media_root" flutter build "$platform" --release

if [ "$platform" = macos ]; then
  app="$project_dir/build/macos/Build/Products/Release/observideo.app"
  packaged_media="$app/Contents/MacOS/media"
else
  bundle="$project_dir/build/linux/x64/release/bundle"
  packaged_media="$bundle/media"
fi
mkdir -p "$packaged_media/bin" "$packaged_media/lib" "$packaged_media/share"
cp "$media_root/bin/ffprobe" "$packaged_media/bin/"
cp -R "$media_root/lib/." "$packaged_media/lib/"
cp -R "$media_root/share/." "$packaged_media/share/"
