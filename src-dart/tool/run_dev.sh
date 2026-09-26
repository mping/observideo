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
if [ ! -x "$media_root/bin/ffprobe" ]; then
  echo "Missing controlled media build at $media_root; run native/media/build_unix.sh." >&2
  exit 1
fi

cd "$project_dir"
OBSERVIDEO_MEDIA_ROOT="$media_root" ./tool/stage_media.sh
mkdir -p "$project_dir/.dart_tool"
OBSERVIDEO_MEDIA_ROOT="$media_root" flutter run \
  --debug \
  --hot \
  --pid-file="$project_dir/.dart_tool/observideo-flutter.pid" \
  -d "$platform" \
  "$@"
