#!/bin/sh
set -eu

media_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$media_dir/versions.env"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$os" in darwin) platform=macos ;; linux) platform=linux ;; *) exit 1 ;; esac
case "$arch" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=x64 ;; esac

cache="$media_dir/cache"
prefix="$media_dir/out/$platform-$arch"
mkdir -p "$cache" "$prefix"

if [ ! -d "$cache/ffmpeg/.git" ]; then
  git clone --filter=blob:none --branch "$FFMPEG_TAG" --depth 1 https://git.ffmpeg.org/ffmpeg.git "$cache/ffmpeg"
fi
if [ ! -d "$cache/mpv/.git" ]; then
  git clone --filter=blob:none --branch "$MPV_TAG" --depth 1 https://github.com/mpv-player/mpv.git "$cache/mpv"
fi

cd "$cache/ffmpeg"
./configure --prefix="$prefix" --enable-shared --disable-static --enable-gpl --enable-version3 --disable-nonfree
make -j4
make install

cd "$cache/mpv"
if [ -d build/meson-private ]; then
  PKG_CONFIG_PATH="$prefix/lib/pkgconfig" meson setup build --wipe --prefix="$prefix" -Dlibmpv=true -Dcplayer=true
else
  PKG_CONFIG_PATH="$prefix/lib/pkgconfig" meson setup build --prefix="$prefix" -Dlibmpv=true -Dcplayer=true
fi
PKG_CONFIG_PATH="$prefix/lib/pkgconfig" meson compile -C build
meson install -C build

mkdir -p "$prefix/share/observideo"
"$prefix/bin/ffmpeg" -hide_banner -buildconf > "$prefix/share/observideo/ffmpeg-build.txt" 2>&1
"$prefix/bin/ffmpeg" -hide_banner -decoders > "$prefix/share/observideo/ffmpeg-decoders.txt" 2>&1
"$prefix/bin/mpv" --version > "$prefix/share/observideo/mpv-version.txt"
printf '{"ffmpeg":"%s","mpv":"%s","nonfree":false}\n' "$FFMPEG_TAG" "$MPV_TAG" > "$prefix/share/observideo/codec-manifest.json"

echo "Controlled media runtime built at $prefix"
