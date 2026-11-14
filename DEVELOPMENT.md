# Development

Observideo is a Flutter desktop application in `src/`.

## Flutter desktop app

Prerequisites: Flutter 3.47.3, the platform desktop toolchain, and the native
media build tools listed in [src/README.md](src/README.md).

```sh
cd src
./tool/bootstrap_platforms.sh
./native/media/build_unix.sh   # macOS or Linux
./tool/run_dev.sh              # attached process with hot reload
```

On Windows, build the media runtime as described in
[src/README.md](src/README.md), then run `.\tool\run_dev.ps1` from
`src\` in PowerShell.

Run `flutter analyze`, `flutter test`, and `flutter test integration_test`
from `src/` before submitting changes. Use `./tool/build_release.sh` for
a release build after the controlled media libraries have been staged.

## Data locations

The application stores its state in `observideo/state-v1.json` in the platform
application-data directory. Existing Electron projects in `observideo.db.transit`
are not migrated automatically.

## CI

- `.github/workflows/flutter-build-mac.yml`: macOS ARM64 build and DMG.
- `.github/workflows/flutter-build-win+linux.yml`: Windows x64 and Linux x64
  builds, NSIS/AppImage packages, and tagged-release artifacts.
- `.github/workflows/flutter-verify-dart.yml`: Flutter analysis and tests.
