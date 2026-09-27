#!/bin/sh
set -eu

media_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$media_dir/versions.env"

os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$os" in darwin) platform=macos ;; linux) platform=linux ;; *) exit 1 ;; esac
case "$arch" in arm64|aarch64) arch=arm64 ;; x86_64|amd64) arch=x64 ;; esac

# Report every missing build dependency at once instead of failing mid-build.
missing=
for tool in git make cc pkg-config meson ninja; do
  command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
done
if [ "$arch" = x64 ] && ! command -v nasm >/dev/null 2>&1 && ! command -v yasm >/dev/null 2>&1; then
  missing="$missing nasm"
fi
if command -v pkg-config >/dev/null 2>&1; then
  pkg-config --exists libass || missing="$missing libass"
  pkg-config --exists 'libplacebo >= 6.338.2' || missing="$missing libplacebo>=6.338.2"
fi
if [ -n "$missing" ]; then
  echo "Missing build dependencies:$missing" >&2
  if [ "$platform" = linux ]; then
    echo "On Debian/Ubuntu: sudo apt-get install -y clang cmake libass-dev libplacebo-dev meson nasm ninja-build pkg-config" >&2
  else
    echo "On macOS: brew install meson ninja pkg-config nasm libass libplacebo" >&2
  fi
  exit 1
fi

cache="$media_dir/cache"
prefix="$media_dir/out/$platform-$arch"
mkdir -p "$cache" "$prefix"

if [ ! -d "$cache/ffmpeg/.git" ]; then
  git clone --filter=blob:none --branch "$FFMPEG_TAG" --depth 1 https://git.ffmpeg.org/ffmpeg.git "$cache/ffmpeg"
fi
if [ ! -d "$cache/mpv/.git" ]; then
  git clone --filter=blob:none --branch "$MPV_TAG" --depth 1 https://github.com/mpv-player/mpv.git "$cache/mpv"
fi

# On Linux an executable's RUNPATH does not apply to indirect dependencies
# (e.g. libavfilter -> libpostproc), so each library and binary gets a
# relative RUNPATH that keeps the prefix relocatable into the app bundle.
# FFmpeg's configure evals its flags and its Makefile expands `$`, so the
# rpath goes through linker response files, which nothing re-expands.
ffmpeg_rpath_flags=
mpv_ldflags=${LDFLAGS:-}
if [ "$platform" = linux ]; then
  printf '%s\n' '-rpath=$ORIGIN' > "$cache/rpath-lib.rsp"
  printf '%s\n' '-rpath=$ORIGIN/../lib' > "$cache/rpath-bin.rsp"
  ffmpeg_rpath_flags="--extra-ldsoflags=-Wl,@$cache/rpath-lib.rsp --extra-ldexeflags=-Wl,@$cache/rpath-bin.rsp"
  mpv_ldflags="$mpv_ldflags -Wl,@$cache/rpath-bin.rsp"
fi

cd "$cache/ffmpeg"
# shellcheck disable=SC2086 # ffmpeg_rpath_flags is intentionally split into two options.
./configure --prefix="$prefix" --enable-shared --disable-static --enable-gpl --enable-version3 --disable-nonfree --disable-doc $ffmpeg_rpath_flags
make -j4
make install

cd "$cache/mpv"
if [ -d build/meson-private ]; then
  LDFLAGS="$mpv_ldflags" PKG_CONFIG_PATH="$prefix/lib/pkgconfig" meson setup build --wipe --prefix="$prefix" --libdir=lib -Dlibmpv=true -Dcplayer=true
else
  LDFLAGS="$mpv_ldflags" PKG_CONFIG_PATH="$prefix/lib/pkgconfig" meson setup build --prefix="$prefix" --libdir=lib -Dlibmpv=true -Dcplayer=true
fi
PKG_CONFIG_PATH="$prefix/lib/pkgconfig" meson compile -C build
meson install -C build

mkdir -p "$prefix/share/observideo"
"$prefix/bin/ffmpeg" -hide_banner -buildconf > "$prefix/share/observideo/ffmpeg-build.txt" 2>&1
"$prefix/bin/ffmpeg" -hide_banner -decoders > "$prefix/share/observideo/ffmpeg-decoders.txt" 2>&1
"$prefix/bin/mpv" --version > "$prefix/share/observideo/mpv-version.txt"
printf '{"ffmpeg":"%s","mpv":"%s","nonfree":false}\n' "$FFMPEG_TAG" "$MPV_TAG" > "$prefix/share/observideo/codec-manifest.json"

echo "Controlled media runtime built at $prefix"
