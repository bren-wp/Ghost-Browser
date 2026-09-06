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

Name "Ghosium Browser Portable ${GHOSIUM_VERSION}"
OutFile "${GHOSIUM_ARTIFACTS}\Ghosium-Browser-Portable.exe"
RequestExecutionLevel user
SilentInstall silent
SetCompressor zlib

VIProductVersion "${GHOSIUM_VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "Ghosium Browser Portable"
VIAddVersionKey /LANG=1033 "CompanyName" "Brendigo"
VIAddVersionKey /LANG=1033 "FileDescription" "Ghosium Browser Portable"
VIAddVersionKey /LANG=1033 "FileVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "ProductVersion" "${GHOSIUM_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright (c) 2026 Brendigo"

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
  IfFileExists "$EXEDIR\Ghosium-Portable-Data\language.txt" done
  StrCpy $LANGUAGE ${LANG_ENGLISH}
  !insertmacro MUI_LANGDLL_DISPLAY

done:
FunctionEnd

Section
  CreateDirectory "$EXEDIR\Ghosium-Portable-Data"
  CreateDirectory "$EXEDIR\Ghosium-Portable-Data\User Data"

  IfFileExists "$EXEDIR\Ghosium-Portable-Data\language.txt" have_language
  FileOpen $0 "$EXEDIR\Ghosium-Portable-Data\language.txt" w
  FileWrite $0 "$(GhosiumLocale)$\r$\n"
  FileClose $0

have_language:
  ; A unique extraction directory prevents concurrent portable launches from
  ; deleting or overwriting the runtime used by another active invocation.
  GetTempFileName $R0 "$TEMP"
  Delete "$R0"
  CreateDirectory "$R0"
  SetOutPath "$R0"
  File /r "${GHOSIUM_STAGE}\*"
  CopyFiles /SILENT "$EXEDIR\Ghosium-Portable-Data\language.txt" "$R0\ghosium-language.txt"

  ; Preserve URLs, local files and supported browser switches supplied to the
  ; Portable EXE. The native launcher still filters protected Ghosium switches.
  ${GetParameters} $R1
  ExecWait '"$R0\Ghosium-Browser.exe" "--ghosium-portable-profile=$EXEDIR\Ghosium-Portable-Data\User Data" --ghosium-wait $R1' $1

  RMDir /r "$R0"
  SetErrorLevel $1
SectionEnd
