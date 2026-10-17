$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MediaRoot = Join-Path $ProjectDir 'native\media\out\windows-x64'

if (-not (Test-Path (Join-Path $MediaRoot 'bin\ffprobe.exe'))) {
  throw "Missing controlled media build at $MediaRoot; run native/media/build_windows.ps1."
}
# The media_kit_libs_windows_video CMake build reads this; the app itself finds
# the media root relative to the working directory.
$env:OBSERVIDEO_MEDIA_ROOT = $MediaRoot
Push-Location $ProjectDir
try {
  flutter run --debug --hot -d windows @args
  $ExitCode = $LASTEXITCODE
} finally {
  Pop-Location
}
exit $ExitCode
