Unicode true
!include "MUI2.nsh"

!ifndef GHOSIUM_VERSION
  !define GHOSIUM_VERSION "0.0.0"
!endif
!ifndef GHOSIUM_STAGE
  !error "GHOSIUM_STAGE must point to the assembled Ghosium directory"
!endif
!ifndef GHOSIUM_ARTIFACTS
  !error "GHOSIUM_ARTIFACTS must point to the release artifact directory"
!endif

!define PRODUCT_NAME "Ghosium Browser"
!define PRODUCT_PUBLISHER "Brendigo"
!define PRODUCT_EXE "Ghosium-Browser.exe"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\GhosiumBrowser"

Name "${PRODUCT_NAME} ${GHOSIUM_VERSION}"
OutFile "${GHOSIUM_ARTIFACTS}\Ghosium-Browser-Setup.exe"
InstallDir "$LOCALAPPDATA\Programs\Ghosium Browser"
InstallDirRegKey HKCU "${UNINSTALL_KEY}" "InstallLocation"
RequestExecutionLevel user
SetCompressor zlib
ShowInstDetails show
ShowUninstDetails show

VIProductVersion "${GHOSIUM_VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "Ghosium Browser"
VIAddVersionKey /LANG=1033 "CompanyName" "Brendigo"
VIAddVersionKey /LANG=1033 "FileDescription" "Ghosium Browser Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (c) 2026 Brendigo"

!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"
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

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

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

Function .onInit
  StrCpy $LANGUAGE ${LANG_ENGLISH}
  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

Section "Ghosium Browser" SecMain
  SetShellVarContext current
  SetOutPath "$INSTDIR"
  SetOverwrite on
  File /r "${GHOSIUM_STAGE}\*"

  FileOpen $0 "$INSTDIR\ghosium-language.txt" w
  FileWrite $0 "$(GhosiumLocale)$\r$\n"
  FileClose $0

  WriteUninstaller "$INSTDIR\Uninstall.exe"

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
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLInfoAbout" "https://ghosium.com/"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "HelpLink" "https://ghosium.com/support"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "URLUpdateInfo" "https://ghosium.com/security"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLanguage" "$(GhosiumLocale)"
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  Delete "$DESKTOP\Ghosium Browser.lnk"
  RMDir /r "$SMPROGRAMS\Ghosium Browser"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  RMDir /r "$INSTDIR"
SectionEnd
