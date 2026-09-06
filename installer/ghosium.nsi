Unicode true
!include "MUI2.nsh"

!ifndef GHOSIUM_VERSION
  !define GHOSIUM_VERSION "0.0.0"
!endif
!ifndef GHOSIUM_STAGE
  !error "GHOSIUM_STAGE must point to the assembled release directory"
!endif
!ifndef GHOSIUM_ARTIFACTS
  !error "GHOSIUM_ARTIFACTS must point to the release artifact directory"
!endif

!define PRODUCT_NAME "Ghosium Browser"
!define PRODUCT_PUBLISHER "Brendigo"
!define PRODUCT_EXE "Ghosium-Browser.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\GhosiumBrowser"

Name "${PRODUCT_NAME} ${GHOSIUM_VERSION}"
OutFile "${GHOSIUM_ARTIFACTS}\Ghosium-Browser-Setup-v${GHOSIUM_VERSION}.exe"
InstallDir "$LOCALAPPDATA\Programs\Ghosium Browser"
RequestExecutionLevel user

; zlib intentionally favors low-memory/faster installation on weaker PCs.
; Chromium already contains many internally compressed resources, so using a
; very large solid-LZMA dictionary gives poor build/install trade-offs here.
SetCompressor zlib

ShowInstDetails show
ShowUninstDetails show

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

Section "Ghosium Browser" SecMain
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  File /r "${GHOSIUM_STAGE}\*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\Ghosium Browser"
  CreateShortcut "$SMPROGRAMS\Ghosium Browser\Ghosium Browser.lnk" "$INSTDIR\${PRODUCT_EXE}"
  CreateShortcut "$DESKTOP\Ghosium Browser.lnk" "$INSTDIR\${PRODUCT_EXE}"

  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${GHOSIUM_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  Delete "$DESKTOP\Ghosium Browser.lnk"
  Delete "$SMPROGRAMS\Ghosium Browser\Ghosium Browser.lnk"
  RMDir "$SMPROGRAMS\Ghosium Browser"

  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  RMDir /r "$INSTDIR"
SectionEnd
