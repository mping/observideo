$ErrorActionPreference = 'Stop'
$MediaDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Output = Join-Path $MediaDir 'out\windows-x64'
$VersionsFile = Join-Path $MediaDir 'versions.env'

$Versions = @{}
Get-Content $VersionsFile | ForEach-Object {
  if ($_ -match '^([^#=]+)=(.+)$') {
    $Versions[$Matches[1]] = $Matches[2]
  }
}

$Required = @(
  'bin\libmpv-2.dll',
  'bin\ffprobe.exe',
  'bin\libEGL.dll',
  'bin\libGLESv2.dll',
  'include\mpv\client.h',
  'lib\libmpv.dll.a',
  'angle\include\EGL\egl.h',
  'angle\lib\libEGL.dll.lib',
  'angle\lib\libGLESv2.dll.lib',
  'share\observideo\codec-manifest.json'
)
$Missing = @($Required | Where-Object {
  -not (Test-Path -LiteralPath (Join-Path $Output $_) -PathType Leaf)
})

if ($Missing.Count -gt 0) {
  $List = ($Missing | ForEach-Object { "  native\media\out\windows-x64\$_" }) -join "`n"
  throw @"
The controlled Windows media runtime is incomplete. Missing:
$List

Build MPV_TAG=$($Versions.MPV_TAG) and FFMPEG_TAG=$($Versions.FFMPEG_TAG) with a
reproducible x64 MSYS2/MinGW toolchain. Configure FFmpeg with --enable-gpl
--enable-version3 --disable-nonfree, stage the files above, and include every
dependent runtime DLL in bin. Unverified third-party binaries are not accepted.
"@
}

$ManifestPath = Join-Path $Output 'share\observideo\codec-manifest.json'
try {
  $Manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
} catch {
  throw "Invalid controlled media manifest at ${ManifestPath}: $_"
}
if ($Manifest.ffmpeg -ne $Versions.FFMPEG_TAG -or
    $Manifest.mpv -ne $Versions.MPV_TAG -or
    $Manifest.nonfree -ne $false) {
  throw "Media manifest must declare ffmpeg=$($Versions.FFMPEG_TAG), mpv=$($Versions.MPV_TAG), and nonfree=false."
}

$RuntimeDlls = @(Get-ChildItem -LiteralPath (Join-Path $Output 'bin') -Filter '*.dll' -File)
if ($RuntimeDlls.Count -lt 3) {
  throw 'The controlled runtime must contain libmpv, ANGLE, and all FFmpeg dependency DLLs in bin.'
}

Write-Host "Controlled Windows media runtime validated at $Output"
