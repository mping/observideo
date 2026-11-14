Unicode True
Name "Observideo"
OutFile "Observideo-flutter-windows-x64.exe"
InstallDir "$PROGRAMFILES64\Observideo"
RequestExecutionLevel admin

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "..\..\build\windows\x64\runner\Release\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateShortcut "$DESKTOP\Observideo.lnk" "$INSTDIR\observideo.exe"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\Observideo.lnk"
  RMDir /r "$INSTDIR"
SectionEnd
