# Observideo Flutter Port

This directory contains the standalone Flutter/Dart desktop implementation.
It uses the version 1 JSON schema and does not read the Electron Transit
database.

## Prerequisites

- Flutter 3.47.3 with Dart 3.13.x
- CMake, Ninja, Meson, Python, pkg-config, and a native compiler
- macOS: Xcode and CocoaPods; Windows: Visual Studio 2022 and MSYS2 MINGW64;
  Linux: GTK 3 headers

## Bootstrap and run

```sh
./tool/bootstrap_platforms.sh
./native/media/build_unix.sh       # macOS or Linux
./tool/run_dev.sh
```

The development runner stays attached with Flutter hot reload enabled. Press
`r` in its terminal after editing Dart files (`R` performs a hot restart), or
trigger reload from another terminal with:

```sh
kill -USR1 "$(cat .dart_tool/observideo-flutter.pid)"
```

On Windows, run `native/media/build_windows_msys2.sh` in an MSYS2 MINGW64
shell, validate the result with `native/media/build_windows.ps1`, then run
`tool/build_windows.ps1`. Media artifacts use mpv 0.41.0 and FFmpeg 7.1.3 and
live under `native/media/out/<platform>-<architecture>`.

Useful checks:

```sh
flutter pub get
flutter analyze
flutter test
flutter test integration_test
./tool/build_release.sh
```

Native codec CI supplies `OBSERVIDEO_H264_MP4`, `OBSERVIDEO_HEVC_MP4`,
`OBSERVIDEO_AV1_MP4`, `OBSERVIDEO_VFR_MP4`, and
`OBSERVIDEO_UNUSUAL_TIMEBASE_MP4`. Set `OBSERVIDEO_SARA_MP4` to run the local
Sara regression. Every playable case asserts valid metadata and a decoded
non-black frame; damaged input must produce a probe error.

Set `OBSERVIDEO_MEDIA_ROOT` only to select a different controlled build tree.
Release scripts reject missing media artifacts rather than using an arbitrary
system libmpv. For local probing only, `OBSERVIDEO_FFPROBE` may point at a
specific compatible `ffprobe` executable.

The state file is stored in the platform application-data directory as
`observideo/state-v1.json`. A process-lifetime lock prevents two instances
from writing the same state.
