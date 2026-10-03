Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "x64.nsh"

Name "Charge Arena 3.44 - New Skin"
!ifndef PACKAGE_FILE
  !define PACKAGE_FILE "..\builds\Charge-Arena-3.44.0-Windows-Setup.exe"
!endif
OutFile "${PACKAGE_FILE}"
InstallDir "$LOCALAPPDATA\Programs\Charge Arena"
RequestExecutionLevel user
SetCompressor /SOLID lzma

Var TestMode

!define MUI_ABORTWARNING
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "Portuguese"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_OK "Esta versao requer Windows de 64 bits."
    Abort
  ${EndIf}
  ${GetParameters} $0
  ClearErrors
  ${GetOptions} $0 "/TEST" $1
  ${IfNot} ${Errors}
    StrCpy $TestMode "1"
  ${EndIf}
FunctionEnd

Section "Charge Arena"
  SetOutPath "$INSTDIR"
  File "..\builds\windows\ChargeArena.exe"
  !if /FileExists "..\builds\windows\ChargeArena.pck"
    File "..\builds\windows\ChargeArena.pck"
  !endif
  File "..\builds\windows\LEIA-ME.txt"
  File "..\builds\windows\GODOT-LICENSE.txt"
  File "..\builds\windows\GODOT-COPYRIGHT.txt"

  WriteUninstaller "$INSTDIR\Desinstalar.exe"

  ${If} $TestMode != "1"
    CreateDirectory "$SMPROGRAMS\Charge Arena"
    CreateShortcut "$SMPROGRAMS\Charge Arena\Charge Arena.lnk" "$INSTDIR\ChargeArena.exe"
    CreateShortcut "$SMPROGRAMS\Charge Arena\Desinstalar.lnk" "$INSTDIR\Desinstalar.exe"
    CreateShortcut "$DESKTOP\Charge Arena.lnk" "$INSTDIR\ChargeArena.exe"

    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "DisplayName" "Charge Arena"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "DisplayVersion" "3.44"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "Publisher" "Newtown Borges"
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "UninstallString" '$\"$INSTDIR\Desinstalar.exe$\"'
    WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "DisplayIcon" "$INSTDIR\ChargeArena.exe"
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "NoModify" 1
    WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena" "NoRepair" 1
  ${EndIf}
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\ChargeArena.exe"
  Delete "$INSTDIR\ChargeArena.pck"
  Delete "$INSTDIR\LEIA-ME.txt"
  Delete "$INSTDIR\GODOT-LICENSE.txt"
  Delete "$INSTDIR\GODOT-COPYRIGHT.txt"
  Delete "$INSTDIR\Desinstalar.exe"

  Delete "$DESKTOP\Charge Arena.lnk"
  Delete "$SMPROGRAMS\Charge Arena\Charge Arena.lnk"
  Delete "$SMPROGRAMS\Charge Arena\Desinstalar.lnk"
  RMDir "$SMPROGRAMS\Charge Arena"

  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ChargeArena"
  RMDir "$INSTDIR"
SectionEnd
