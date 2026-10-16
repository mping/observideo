$ErrorActionPreference = 'Stop'
$ProjectDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$MediaRoot = Join-Path $ProjectDir 'native\media\out\windows-x64'

if (-not (Test-Path (Join-Path $MediaRoot 'bin\ffprobe.exe'))) {
  throw "Missing controlled media build at $MediaRoot; run native/media/build_windows.ps1."
}
$env:OBSERVIDEO_MEDIA_ROOT = $MediaRoot
Push-Location $ProjectDir
try {
  flutter build windows --release
  $BundleMedia = Join-Path $ProjectDir 'build\windows\x64\runner\Release\media'
  Copy-Item -Recurse -Force $MediaRoot $BundleMedia
} finally {
  Pop-Location
}
