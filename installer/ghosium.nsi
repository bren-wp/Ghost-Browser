Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!ifndef GHOSIUM_VERSION
  !define GHOSIUM_VERSION "0.0.0"
!endif
!ifndef GHOSIUM_STAGE
  !error "GHOSIUM_STAGE must point to the assembled Ghosium directory"
!endif
!ifndef GHOSIUM_ARTIFACTS
  !error "GHOSIUM_ARTIFACTS must point to the release artifact directory"
!endif
!ifndef GHOSIUM_ICON
  !define GHOSIUM_ICON "${__FILEDIR__}\..\ghosium.ico"
!endif

!define PRODUCT_NAME "Ghosium Browser"
!define PRODUCT_PUBLISHER "Brendigo"
!define PRODUCT_EXE "Ghosium-Browser.exe"
!define INSTALLED_SETUP "Installer\Ghosium-Browser-Setup.exe"
!define INSTALL_MARKER "ghosium-install.marker"
!define CLEANUP_DIR "$TEMP\Brendigo\Ghosium Browser Cleanup"
!define CLEANUP_SETUP "$TEMP\Brendigo\Ghosium Browser Cleanup\Ghosium-Browser-Setup.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\GhosiumBrowser"

Name "${PRODUCT_NAME} ${GHOSIUM_VERSION}"
OutFile "${GHOSIUM_ARTIFACTS}\Ghosium-Browser-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Ghosium Browser"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor zlib
ShowInstDetails show
BrandingText "Ghosium Browser · Brendigo"

VIProductVersion "${GHOSIUM_VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "Ghosium Browser"
VIAddVersionKey /LANG=1033 "CompanyName" "Brendigo"
VIAddVersionKey /LANG=1033 "FileDescription" "Ghosium Browser Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (c) 2026 Brendigo"

!define MUI_ABORTWARNING
!define MUI_ICON "${GHOSIUM_ICON}"
!define MUI_WELCOMEPAGE_TITLE "Ghosium Browser ${GHOSIUM_VERSION}"
!define MUI_WELCOMEPAGE_TEXT "Welcome to Ghosium Browser.$\r$\n$\r$\nChoose your language, review the Brendigo license, and install Ghosium Browser for your Windows account."
!define MUI_FINISHPAGE_LINK "Ghosium Support"
!define MUI_FINISHPAGE_LINK_LOCATION "https://ghosium.com/support"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Start Ghosium Browser"

!define MUI_LANGDLL_REGISTRY_ROOT "HKCU"
!define MUI_LANGDLL_REGISTRY_KEY "Software\Brendigo\Ghosium Browser"
!define MUI_LANGDLL_REGISTRY_VALUENAME "InstallerLanguage"

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${GHOSIUM_STAGE}\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Croatian"
!insertmacro MUI_LANGUAGE "German"
!insertmacro MUI_LANGUAGE "French"
!insertmacro MUI_LANGUAGE "Spanish"
!insertmacro MUI_LANGUAGE "Italian"
!insertmacro MUI_LANGUAGE "Portuguese"
!insertmacro MUI_LANGUAGE "PortugueseBR"
!insertmacro MUI_LANGUAGE "Dutch"
!insertmacro MUI_LANGUAGE "Polish"
!insertmacro MUI_LANGUAGE "Czech"
!insertmacro MUI_LANGUAGE "Slovak"
!insertmacro MUI_LANGUAGE "Slovenian"
!insertmacro MUI_LANGUAGE "Hungarian"
!insertmacro MUI_LANGUAGE "Romanian"
!insertmacro MUI_LANGUAGE "Bulgarian"
!insertmacro MUI_LANGUAGE "Greek"
!insertmacro MUI_LANGUAGE "Turkish"
!insertmacro MUI_LANGUAGE "Russian"
!insertmacro MUI_LANGUAGE "Ukrainian"
!insertmacro MUI_LANGUAGE "Swedish"
!insertmacro MUI_LANGUAGE "Danish"
!insertmacro MUI_LANGUAGE "Norwegian"
!insertmacro MUI_LANGUAGE "Finnish"
!insertmacro MUI_LANGUAGE "Japanese"
!insertmacro MUI_LANGUAGE "Korean"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "TradChinese"
!insertmacro MUI_LANGUAGE "Arabic"
!insertmacro MUI_LANGUAGE "Hebrew"

LangString GhosiumLocale ${LANG_ENGLISH} "en-US"
LangString GhosiumLocale ${LANG_CROATIAN} "hr"
LangString GhosiumLocale ${LANG_GERMAN} "de"
LangString GhosiumLocale ${LANG_FRENCH} "fr"
LangString GhosiumLocale ${LANG_SPANISH} "es"
LangString GhosiumLocale ${LANG_ITALIAN} "it"
LangString GhosiumLocale ${LANG_PORTUGUESE} "pt-PT"
LangString GhosiumLocale ${LANG_PORTUGUESEBR} "pt-BR"
LangString GhosiumLocale ${LANG_DUTCH} "nl"
LangString GhosiumLocale ${LANG_POLISH} "pl"
LangString GhosiumLocale ${LANG_CZECH} "cs"
LangString GhosiumLocale ${LANG_SLOVAK} "sk"
LangString GhosiumLocale ${LANG_SLOVENIAN} "sl"
LangString GhosiumLocale ${LANG_HUNGARIAN} "hu"
LangString GhosiumLocale ${LANG_ROMANIAN} "ro"
LangString GhosiumLocale ${LANG_BULGARIAN} "bg"
LangString GhosiumLocale ${LANG_GREEK} "el"
LangString GhosiumLocale ${LANG_TURKISH} "tr"
LangString GhosiumLocale ${LANG_RUSSIAN} "ru"
LangString GhosiumLocale ${LANG_UKRAINIAN} "uk"
LangString GhosiumLocale ${LANG_SWEDISH} "sv"
LangString GhosiumLocale ${LANG_DANISH} "da"
LangString GhosiumLocale ${LANG_NORWEGIAN} "nb"
LangString GhosiumLocale ${LANG_FINNISH} "fi"
LangString GhosiumLocale ${LANG_JAPANESE} "ja"
LangString GhosiumLocale ${LANG_KOREAN} "ko"
LangString GhosiumLocale ${LANG_SIMPCHINESE} "zh-CN"
LangString GhosiumLocale ${LANG_TRADCHINESE} "zh-TW"
LangString GhosiumLocale ${LANG_ARABIC} "ar"
LangString GhosiumLocale ${LANG_HEBREW} "he"

Function LaunchCleanup
  StrCpy $R4 "0"
  CreateDirectory "$TEMP\Brendigo"
  CreateDirectory "${CLEANUP_DIR}"

  ClearErrors
  CopyFiles /SILENT "$EXEPATH" "${CLEANUP_SETUP}"
  IfErrors cleanup_copy_failed

  IfSilent cleanup_launch_silent
  ClearErrors
  Exec '"${CLEANUP_SETUP}" /CLEANUP'
  IfErrors cleanup_launch_failed
  StrCpy $R4 "1"
  Return

cleanup_launch_silent:
  ClearErrors
  ; NSIS must see /S before custom switches so the temp cleanup instance is
  ; already silent when .onInit evaluates IfSilent.
  Exec '"${CLEANUP_SETUP}" /S /CLEANUP'
  IfErrors cleanup_launch_failed
  StrCpy $R4 "1"
  Return

cleanup_copy_failed:
  DetailPrint "Unable to stage the Ghosium setup cleanup process."
  Return

cleanup_launch_failed:
  DetailPrint "Unable to launch the Ghosium setup cleanup process."
FunctionEnd

Function RemoveGhosium
  SetShellVarContext current

  ReadRegStr $R2 HKCU "${UNINSTALL_KEY}" "InstallLocation"
  StrCmp $R2 "" 0 remove_location_ready
    StrCpy $R2 "$LOCALAPPDATA\Programs\Ghosium Browser"
remove_location_ready:
  GetFullPathName $R2 $R2
  StrCpy $INSTDIR $R2

  ; Never recursively delete a directory based only on a mutable registry path.
  ; The directory must carry both the versioned Ghosium install marker and the
  ; same Setup executable that Windows Registered Apps invokes.
  IfFileExists "$INSTDIR\${INSTALL_MARKER}" 0 unsafe_install_location
  IfFileExists "$INSTDIR\${INSTALLED_SETUP}" 0 unsafe_install_location
  ClearErrors
  FileOpen $R5 "$INSTDIR\${INSTALL_MARKER}" r
  IfErrors unsafe_install_location
  FileRead $R5 $R6
  FileClose $R5
  StrCmp $R6 "Ghosium Browser|${GHOSIUM_VERSION}$\r$\n" install_location_verified unsafe_install_location

unsafe_install_location:
  DetailPrint "Refusing to remove an unverified Ghosium installation path: $INSTDIR"
  IfSilent +2
    MessageBox MB_ICONSTOP "Ghosium Browser could not verify the installation directory, so no files were removed."
  SetErrorLevel 3
  Quit

install_location_verified:
  IfSilent remove_now
  MessageBox MB_ICONQUESTION|MB_YESNO "Remove Ghosium Browser from this Windows account?" IDYES remove_now
  SetErrorLevel 2
  Quit

remove_now:
  ; Give the installed Setup process time to exit after it launched this same
  ; Setup from the temp directory, avoiding a locked-image cleanup race.
  Sleep 1200

  nsExec::ExecToLog '"$SYSDIR\taskkill.exe" /IM "Ghosium-Browser.exe" /T /F'
  nsExec::ExecToLog '"$SYSDIR\taskkill.exe" /IM "Ghosium-Engine.exe" /T /F'

  Delete "$DESKTOP\Ghosium Browser.lnk"
  RMDir /r "$SMPROGRAMS\Ghosium Browser"

  ; The cleanup process is another copy of this same Setup executable running
  ; from the user's temporary directory, so it can remove the installed Setup
  ; copy and the rest of the Ghosium directory without a shell command or a
  ; separately built uninstaller executable.
  RMDir /r /REBOOTOK "$INSTDIR"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "Software\Brendigo\Ghosium Browser"

  ; The temporary copy is not a product artifact. Schedule its own cleanup once
  ; Windows no longer has the current process image open.
  Delete /REBOOTOK "$EXEPATH"
  RMDir /REBOOTOK "${CLEANUP_DIR}"
  SetErrorLevel 0
FunctionEnd

Function .onInit
  ${GetParameters} $R0

  ClearErrors
  ${GetOptions} $R0 "/CLEANUP" $R1
  IfErrors check_uninstall
  Call RemoveGhosium
  Quit

check_uninstall:
  ClearErrors
  ${GetOptions} $R0 "/UNINSTALL" $R1
  IfErrors normal_install

  Call LaunchCleanup
  StrCmp $R4 "1" cleanup_launched cleanup_failed

cleanup_launched:
  SetErrorLevel 0
  Quit

cleanup_failed:
  IfSilent +2
    MessageBox MB_ICONSTOP "Ghosium Browser could not start the uninstall cleanup process. The installation was left unchanged."
  SetErrorLevel 1
  Quit

normal_install:
  StrCpy $LANGUAGE ${LANG_ENGLISH}
  IfSilent installer_init_done
  !insertmacro MUI_LANGDLL_DISPLAY
installer_init_done:
FunctionEnd

Section "Ghosium Browser" SecMain
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  SetOverwrite on
  File /r "${GHOSIUM_STAGE}\*"

  FileOpen $0 "$INSTDIR\ghosium-language.txt" w
  FileWrite $0 "$(GhosiumLocale)$\r$\n"
  FileClose $0

  ; Keep a copy of this same Setup executable inside the installation. Windows
  ; invokes it with /UNINSTALL from Installed apps; no separate uninstaller
  ; executable is generated or shipped.
  CreateDirectory "$INSTDIR\Installer"
  StrCmp "$EXEPATH" "$INSTDIR\${INSTALLED_SETUP}" setup_ready
  CopyFiles /SILENT "$EXEPATH" "$INSTDIR\${INSTALLED_SETUP}"
setup_ready:

  ; This marker lets the temp cleanup instance prove it is deleting a Ghosium
  ; installation built by the same Setup version rather than an arbitrary path.
  FileOpen $0 "$INSTDIR\${INSTALL_MARKER}" w
  FileWrite $0 "Ghosium Browser|${GHOSIUM_VERSION}$\r$\n"
  FileClose $0

  CreateDirectory "$SMPROGRAMS\Ghosium Browser"
  CreateShortcut "$SMPROGRAMS\Ghosium Browser\Ghosium Browser.lnk" "$INSTDIR\${PRODUCT_EXE}"
  CreateShortcut "$DESKTOP\Ghosium Browser.lnk" "$INSTDIR\${PRODUCT_EXE}"

  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Ghosium Home.url" "InternetShortcut" "URL" "https://ghosium.com/"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Ghosium Search.url" "InternetShortcut" "URL" "https://search.ghosium.com/"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Ghosium Store.url" "InternetShortcut" "URL" "https://store.ghosium.com/"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Support.url" "InternetShortcut" "URL" "https://ghosium.com/support"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Security.url" "InternetShortcut" "URL" "https://ghosium.com/security"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Terms.url" "InternetShortcut" "URL" "https://ghosium.com/legal/terms"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Privacy.url" "InternetShortcut" "URL" "https://ghosium.com/legal/privacy-policy"
  WriteINIStr "$SMPROGRAMS\Ghosium Browser\Licenses.url" "InternetShortcut" "URL" "https://ghosium.com/legal/licenses"

  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${GHOSIUM_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\${INSTALLED_SETUP}$\" /UNINSTALL'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '$\"$INSTDIR\${INSTALLED_SETUP}$\" /S /UNINSTALL'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://ghosium.com/"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "HelpLink" "https://ghosium.com/support"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLUpdateInfo" "https://ghosium.com/security"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLanguage" "$(GhosiumLocale)"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd
