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
# The controlled macOS media build contains only the host architecture.
# Flutter's release default is universal, so select its arm64-only build on
# Apple Silicon before linking the staged Mpv.framework.
if [ "$platform" = macos ] && [ "$arch" = arm64 ]; then
  export FLUTTER_MACOS_ARM64_ONLY=true
fi
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
if [ "$platform" = macos ]; then
  # Keep the manifest and build reports. Avoid copying shell completion
  # directories into the app, which codesign treats as bundles.
  rm -rf "$packaged_media/share"
  mkdir -p "$packaged_media/share/observideo"
  cp -R "$media_root/share/observideo/." "$packaged_media/share/observideo/"
else
  cp -R "$media_root/share/." "$packaged_media/share/"
fi
