# Development

Observideo contains the Electron app (`src/`) and a standalone Flutter desktop
implementation (`src-dart/`). They use separate source trees, build tools, and
data files (see [Data locations](#data-locations)); neither reads the other's
state.

## Electron app (`src/`)

Prerequisites: Node.js, `yarn` (or `npm`), and `electron`/`shadow-cljs`
installed globally or via `npm ci`.

```sh
npm ci

# terminal 1: watch-compile ClojureScript
npm run dev

# terminal 2: launch Electron once the first compile finishes
npm start
```

Press `Ctrl+H` in the app window for the `re-frame-10x` debug console.

**Package locally:**

```sh
npm run build      # one-time compile (equivalent to `npm run dev` finishing once)
npm run pack        # unpacked app under dist/ -- fastest way to sanity-check a build
npm run dist         # installers for the current OS under dist/
npm run dist-mwl     # installers for macOS + Windows + Linux (needs the toolchains for each)
```

`npm run pack`/`dist` use `electron-builder`, configured in the `build` key
of [package.json](package.json). Building Windows/Linux installers on
macOS (or vice versa) typically needs the Docker-based builder described in
[README.md](README.md#building-locally-on-winlinux).

## Flutter desktop app (`src-dart/`)

Prerequisites: Flutter 3.47.3, the platform desktop toolchain, and the native
media build tools listed in [src-dart/README.md](src-dart/README.md).

```sh
cd src-dart
./tool/bootstrap_platforms.sh
./native/media/build_unix.sh   # macOS or Linux
./tool/run_dev.sh              # attached process with hot reload
```

Run `flutter analyze`, `flutter test`, and `flutter test integration_test`
from `src-dart/` before submitting changes. Use `./tool/build_release.sh` for
a release build after the controlled media libraries have been staged.

## Data locations

- Electron: `observideo.db.transit` (Transit/JSON) in Electron's
  `userData` directory -- `~/Library/Application Support/observideo/` on
  macOS, `%APPDATA%\observideo\` on Windows, `~/.config/observideo/` on
  Linux.
- Flutter: `observideo/state-v1.json` in the platform application-data
  directory. It never reads or writes the Electron file, so existing Electron
  projects are not migrated automatically.

## CI

- `.github/workflows/flutter-build-mac.yml`: Flutter macOS ARM64 build and DMG.
- `.github/workflows/flutter-build-win+linux.yml`: Flutter Windows x64 and
  Linux x64 builds, NSIS/DEB/AppImage packages, and tagged-release artifacts.
- `.github/workflows/flutter-verify-dart.yml`: Flutter analysis and tests.
