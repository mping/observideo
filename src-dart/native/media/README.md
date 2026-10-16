# Controlled media runtime

Observideo release builds use the versions in `versions.env`. The resulting
prefix must contain `bin/ffprobe`, libmpv, its FFmpeg shared-library
dependencies, licenses, and `share/observideo/codec-manifest.json`.

The build enables GPLv3-compatible components and explicitly leaves nonfree
components disabled. Release CI should archive the source tarballs, build logs,
FFmpeg configuration, `ffmpeg -decoders`, and `mpv --version` beside each
artifact. Codec-patent review is separate from software-license compliance.

The scripts clone pinned tags because binary media artifacts are too large to
store in this repository. Production CI should additionally verify mirrored
source archives by organization-controlled SHA-256 checksums.

`build_unix.sh` builds and stages the pinned sources on macOS or Linux.
`build_windows_msys2.sh` performs the equivalent source build in an MSYS2
MINGW64 shell and stages its runtime dependencies and ANGLE artifacts under
`out/windows-x64`. Run `build_windows.ps1` afterward to validate the exact
version manifest before Flutter or NSIS packaging proceeds.
