#!/usr/bin/env python3
"""Verify Ghosium source-patch anchors against the exact pinned Chromium commit.

This is intentionally a lightweight network contract. It does not fetch the full
Chromium checkout or compile anything. Instead it reads only the source files and
directory listings that Ghosium's branding/search/Windows patch layer depends on
and fails closed when an expected path or anchor no longer matches the pinned
source revision.
"""

from __future__ import annotations

import argparse
import base64
import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
GITILES_ROOT = "https://chromium.googlesource.com/chromium/src/+"
USER_AGENT = "Ghosium-source-anchor-contract/1.0"


FILE_ANCHORS: dict[str, tuple[str, ...]] = {
    "chrome/app/chromium_strings.grd": (
        'name="IDS_PRODUCT_NAME"',
        'name="IDS_SHORT_PRODUCT_NAME"',
        'name="IDS_PRODUCT_DESCRIPTION"',
        'name="IDS_WELCOME_TO_CHROME"',
        'name="IDS_SIDE_PANEL_CUSTOMIZE_CHROME_TITLE"',
    ),
    "chrome/app/settings_chromium_strings.grdp": (
        'name="IDS_RELAUNCH_CONFIRMATION_DIALOG_TITLE"',
        'name="IDS_SETTINGS_ABOUT_PROGRAM"',
        'name="IDS_SETTINGS_GET_HELP_USING_CHROME"',
    ),
    "components/components_chromium_strings.grd": (
        'name="IDS_SHORT_PRODUCT_LOGO_ALT_TEXT"',
        'name="IDS_VERSION_UI_LICENSE"',
        'name="IDS_VERSION_UI_LICENSE_CHROMIUM"',
    ),
    "extensions/strings/extensions_chromium_strings.grdp": (),
    "chrome/common/url_constants.h": (
        '"https://support.google.com/chrome?p=help&ctx=keyboard"',
        '"https://support.google.com/chrome?p=help&ctx=menu"',
        '"https://support.google.com/chrome?p=help&ctx=settings"',
    ),
    "chrome/app/theme/chromium/BRANDING": (
        "COMPANY_FULLNAME=The Chromium Authors",
        "COMPANY_SHORTNAME=The Chromium Authors",
        "PRODUCT_FULLNAME=Chromium",
        "PRODUCT_SHORTNAME=Chromium",
        "PRODUCT_INSTALLER_FULLNAME=Chromium Installer",
        "PRODUCT_INSTALLER_SHORTNAME=Chromium Installer",
        "MAC_BUNDLE_ID=org.chromium.Chromium",
    ),
    "chrome/browser/resources/signin/managed_user_profile_notice/managed_user_profile_notice_value_prop.html.ts": (
        'alt="Chrome logo"',
        'src="chrome://theme/current-channel-logo@2x"',
    ),
    "chrome/browser/resources/contextual_tasks/top_toolbar_logo.html.ts": (
        'src="chrome://resources/cr_components/searchbox/icons/chrome_product.svg"',
        'src="chrome://resources/images/chrome_logo_dark.svg"',
    ),
    "components/search_engines/template_url_prepopulate_data.cc": (
        "std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(",
        "return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,",
        "google.id,",
        "/*use_first_as_fallback=*/true);",
    ),
    "chrome/install_static/chromium_install_modes.h": (
        'inline constexpr wchar_t kCompanyPathName[] = L"";',
        'inline constexpr wchar_t kProductPathName[] = L"Chromium";',
        'inline constexpr char kSafeBrowsingName[] = "chromium";',
        '.base_app_name = L"Chromium",',
        '.base_app_id = L"Chromium",',
        '.browser_prog_id_prefix = L"ChromiumHTM",',
        'L"Chromium HTML Document",',
        '.direct_launch_url_scheme = "chromium",',
        '.pdf_prog_id_prefix = L"ChromiumPDF",',
        'L"Chromium PDF Document",',
    ),
    "chrome/browser/ui/webui/side_panel/customize_chrome/customize_chrome_page_handler.cc": (
        'GURL("https://chromewebstore.google.com/category/themes")',
    ),
    "chrome/browser/ui/chrome_pages.cc": (
        "GURL webstore_url = extension_urls::GetNewWebstoreLaunchURL();",
        "browser, extension_urls::AppendUtmSource(webstore_url, utm_source_value));",
    ),
    "chrome/browser/ui/webui/extensions/extensions_ui.cc": (
        '"suspiciousInstallHelpUrl"',
        "chrome::kRemoveNonCWSExtensionURL",
        '"enhancedSafeBrowsingWarningHelpUrl"',
        "chrome::kCwsEnhancedSafeBrowsingLearnMoreURL",
        '"getMoreExtensionsUrl"',
        "extension_urls::GetWebstoreExtensionsCategoryURL()",
        '"modernWebGuidanceURL"',
        "extension_urls::GetModernWebGuidanceURL()",
        '"hostPermissionsLearnMoreLink"',
        "extension_permissions_constants::kRuntimeHostPermissionsHelpURL",
    ),
    "chrome/browser/resources/settings/about_page/about_page.ts": (
        "'https://policies.google.com/privacy'",
    ),
    "chrome/installer/setup/setup_main.cc": (
        "HasSwitch(installer::switches::kUninstall)",
        "UninstallProduct(",
    ),
    "chrome/installer/setup/uninstall.cc": (
        "InstallStatus UninstallProduct(",
    ),
    "chrome/installer/setup/install_worker.cc": (
        "installer::kUninstallStringField",
        "installer::kUninstallArgumentsField",
    ),
    "chrome/installer/util/util_constants.h": (
        'kSetupExe[] = L"setup.exe"',
        'kUninstallStringField[] = L"UninstallString"',
        'kUninstallArgumentsField[] = L"UninstallArguments"',
    ),
    "ui/webui/resources/images/chrome_logo_dark.svg": (),
    "chrome/app/theme/chromium/product_logo.svg": (),
    "components/vector_icons/chromium/product.icon": (),
    "components/vector_icons/chromium/product_refresh.icon": (),
}


SEARCH_FALLBACK_BLOCK = """std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(
    PrefService& prefs,
    const std::vector<raw_ptr<const PrepopulatedEngine>>&
        regional_prepopulated_engines) {
  return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,
                                        google.id,
                                        /*use_first_as_fallback=*/true);
}"""


LOCALE_DIRECTORIES = (
    ("chrome/app/resources", "chromium_strings_"),
    ("components/strings", "components_chromium_strings_"),
    ("extensions/strings", "extensions_strings_"),
)


def _request_bytes(url: str, attempts: int = 5) -> bytes:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=45) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            last_error = error
            if attempt == attempts:
                break
            time.sleep(min(2**attempt, 10))
    raise RuntimeError(f"Unable to fetch pinned Chromium source after {attempts} attempts: {url}: {last_error}")


def fetch_file(revision: str, path: str) -> str:
    url = f"{GITILES_ROOT}/{revision}/{path}?format=TEXT"
    encoded = _request_bytes(url)
    try:
        decoded = base64.b64decode(encoded, validate=True)
    except Exception as error:  # noqa: BLE001 - surface a precise contract failure.
        preview = encoded[:120].decode("utf-8", errors="replace")
        raise RuntimeError(f"Gitiles returned non-base64 content for {path}: {preview!r}") from error
    return decoded.decode("utf-8")


def fetch_directory_names(revision: str, path: str) -> set[str]:
    url = f"{GITILES_ROOT}/{revision}/{path}/?format=JSON"
    raw = _request_bytes(url).decode("utf-8")
    if raw.startswith(")]}'"):
        raw = raw.split("\n", 1)[1]
    payload = json.loads(raw)
    entries = payload.get("entries")
    if not isinstance(entries, list):
        raise RuntimeError(f"Gitiles directory listing is malformed for {path}")
    return {str(entry.get("name")) for entry in entries if isinstance(entry, dict) and entry.get("name")}


def translation_locale(locale: str) -> str | None:
    if locale == "en-US":
        return None
    if locale == "nb":
        return "no"
    if locale == "he":
        return "iw"
    return locale


def verify_file_anchors(revision: str) -> None:
    for path, anchors in FILE_ANCHORS.items():
        text = fetch_file(revision, path)
        for anchor in anchors:
            if anchor not in text:
                raise RuntimeError(f"Pinned Chromium patch anchor changed: {path}: {anchor}")
        if path.endswith("template_url_prepopulate_data.cc") and SEARCH_FALLBACK_BLOCK not in text:
            raise RuntimeError("Pinned Chromium fallback-search implementation no longer matches the reviewed Ghosium rewrite block.")
        print(f"OK source anchors: {path} ({len(anchors)} required literal(s))")


def verify_locale_layout(revision: str) -> None:
    config = json.loads((REPO_ROOT / "engine/branding/product.json").read_text(encoding="utf-8"))
    locales = config.get("locales", {}).get("supported", [])
    if not isinstance(locales, list) or len(locales) != 30:
        raise RuntimeError("engine/branding/product.json must define exactly 30 supported locales before source layout validation.")

    expected_locales = [translation_locale(str(locale)) for locale in locales]
    expected_locales = [locale for locale in expected_locales if locale]

    for directory, prefix in LOCALE_DIRECTORIES:
        names = fetch_directory_names(revision, directory)
        missing = [f"{prefix}{locale}.xtb" for locale in expected_locales if f"{prefix}{locale}.xtb" not in names]
        if missing:
            raise RuntimeError(
                f"Pinned Chromium locale layout changed under {directory}; missing: {', '.join(missing)}"
            )
        print(f"OK locale layout: {directory} ({len(expected_locales)} translated locale bundle(s))")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--revision",
        help="Pinned Chromium Git commit. Defaults to ENGINE_SOURCE_REVISION.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    revision = args.revision or (REPO_ROOT / "ENGINE_SOURCE_REVISION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise RuntimeError(f"ENGINE_SOURCE_REVISION is not one lowercase 40-character Git commit: {revision!r}")

    verify_file_anchors(revision)
    verify_locale_layout(revision)
    print(f"Ghosium pinned Chromium source patch-anchor contract: OK ({revision})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
