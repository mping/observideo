#!/usr/bin/env bash
set -euo pipefail

media_dir=$(cd -- "$(dirname -- "$0")" && pwd)
source "$media_dir/versions.env"

cache="$media_dir/cache"
prefix="$media_dir/out/windows-x64"
jobs=${NUMBER_OF_PROCESSORS:-2}
mkdir -p "$cache" "$prefix"

if [[ ! -d "$cache/ffmpeg/.git" ]]; then
  git clone --filter=blob:none --branch "$FFMPEG_TAG" --depth 1 \
    https://git.ffmpeg.org/ffmpeg.git "$cache/ffmpeg"
fi
if [[ ! -d "$cache/mpv/.git" ]]; then
  git clone --filter=blob:none --branch "$MPV_TAG" --depth 1 \
    https://github.com/mpv-player/mpv.git "$cache/mpv"
fi

cd "$cache/ffmpeg"
./configure \
  --prefix="$prefix" \
  --enable-shared \
  --disable-static \
  --enable-gpl \
  --enable-version3 \
  --disable-nonfree
make -j"$jobs"
make install

cd "$cache/mpv"
if [[ -d build/meson-private ]]; then
  PKG_CONFIG_PATH="$prefix/lib/pkgconfig:/mingw64/lib/pkgconfig" \
    meson setup build --wipe --prefix="$prefix" -Dlibmpv=true -Dcplayer=true
else
  PKG_CONFIG_PATH="$prefix/lib/pkgconfig:/mingw64/lib/pkgconfig" \
    meson setup build --prefix="$prefix" -Dlibmpv=true -Dcplayer=true
fi
PKG_CONFIG_PATH="$prefix/lib/pkgconfig:/mingw64/lib/pkgconfig" meson compile -C build
meson install -C build

# media_kit_video renders through ANGLE and expects MSVC-compatible import
# libraries alongside the headers. GNU dlltool emits compatible COFF import
# libraries when given the exported symbols from the controlled DLLs.
mkdir -p "$prefix/angle/include" "$prefix/angle/lib" "$prefix/bin"
cp -R /mingw64/include/EGL "$prefix/angle/include/"
cp -R /mingw64/include/GLES2 "$prefix/angle/include/"
cp /mingw64/bin/libEGL.dll /mingw64/bin/libGLESv2.dll "$prefix/bin/"
for library in libEGL libGLESv2; do
  cd "$prefix/angle/lib"
  gendef "$prefix/bin/$library.dll"
  dlltool -d "$library.def" -D "$library.dll" -l "$library.dll.lib"
done

# Bundle every MinGW runtime dependency rather than relying on an MSYS2
# installation on the destination machine.
changed=true
while $changed; do
  changed=false
  for binary in "$prefix"/bin/*.dll "$prefix"/bin/*.exe; do
    [[ -f "$binary" ]] || continue
    while IFS= read -r dependency; do
      target="$prefix/bin/$(basename "$dependency")"
      if [[ ! -f "$target" ]]; then
        cp "$dependency" "$target"
        changed=true
      fi
    done < <(ldd "$binary" | awk '$3 ~ /^\/mingw64\/bin\/.*\.dll$/ { print $3 }')
  done
done

mkdir -p "$prefix/share/observideo" "$prefix/share/licenses"
"$prefix/bin/ffmpeg.exe" -hide_banner -buildconf \
  > "$prefix/share/observideo/ffmpeg-build.txt" 2>&1
"$prefix/bin/ffmpeg.exe" -hide_banner -decoders \
  > "$prefix/share/observideo/ffmpeg-decoders.txt" 2>&1
"$prefix/bin/mpv.exe" --version > "$prefix/share/observideo/mpv-version.txt"
printf '{"ffmpeg":"%s","mpv":"%s","nonfree":false}\n' \
  "$FFMPEG_TAG" "$MPV_TAG" \
  > "$prefix/share/observideo/codec-manifest.json"
cp "$cache/ffmpeg/COPYING.GPLv3" "$prefix/share/licenses/FFmpeg-GPLv3.txt"
cp "$cache/mpv/Copyright" "$prefix/share/licenses/mpv-Copyright.txt"

echo "Controlled Windows media runtime built at $prefix"
