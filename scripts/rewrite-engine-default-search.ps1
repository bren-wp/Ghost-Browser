param(
  [Parameter(Mandatory = $true)]
  [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$expectedRevision = (Get-Content (Join-Path $repoRoot 'ENGINE_SOURCE_REVISION') -Raw).Trim()
$sourceRootResolved = (Resolve-Path $SourceRoot).Path

$actualRevision = (& git -C $sourceRootResolved rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualRevision -ne $expectedRevision) {
  throw "Refusing to rewrite default search on an unpinned checkout. Expected $expectedRevision; found $actualRevision"
}

$target = Join-Path $sourceRootResolved 'components/search_engines/template_url_prepopulate_data.cc'
if (!(Test-Path $target -PathType Leaf)) {
  throw "Pinned Chromium search-engine source is missing: $target"
}

# Chromium reserves prepopulate IDs above 1000 for distribution custom engines.
# Ghosium uses a dedicated ID so Chromium can distinguish this product default
# from the upstream regional engine list without modifying third_party search
# engine data. User selections, enterprise policy and extension overrides remain
# higher priority in DefaultSearchManager than this fallback.
$ghosiumFallback = @'
std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(
    PrefService& prefs,
    const std::vector<raw_ptr<const PrepopulatedEngine>>&
        regional_prepopulated_engines) {
  // Ghosium Search is the distribution fallback only. Explicit user choices,
  // policy-managed search providers and extension-controlled providers are
  // resolved before this fallback by DefaultSearchManager.
  auto ghosium = std::make_unique<TemplateURLData>();
  ghosium->SetShortName(u"Ghosium Search");
  ghosium->SetKeyword(u"search.ghosium.com");
  ghosium->SetURL("https://search.ghosium.com/?q={searchTerms}");
  ghosium->suggestions_url =
      "https://search.ghosium.com/api/suggest.php?q={searchTerms}";
  ghosium->input_encodings.push_back("UTF-8");
  ghosium->prepopulate_id = 1101;
  ghosium->sync_guid = "9e993bd9-c256-42d7-a1b1-000000001101";
  ghosium->safe_for_autoreplace = true;
  ghosium->is_active = TemplateURLData::ActiveStatus::kTrue;

  // Keep the parameters named in the public function signature to minimize the
  // source delta from upstream. They are intentionally unused by this
  // distribution-specific fallback.
  static_cast<void>(prefs);
  static_cast<void>(regional_prepopulated_engines);
  return ghosium;
}
'@

$upstreamFallback = @'
std::unique_ptr<TemplateURLData> GetPrepopulatedFallbackSearch(
    PrefService& prefs,
    const std::vector<raw_ptr<const PrepopulatedEngine>>&
        regional_prepopulated_engines) {
  return FindPrepopulatedEngineInternal(prefs, regional_prepopulated_engines,
                                        google.id,
                                        /*use_first_as_fallback=*/true);
}
'@

$text = [IO.File]::ReadAllText($target)
if ($text.Contains($ghosiumFallback)) {
  Write-Host 'Ghosium Search engine fallback is already applied.'
} elseif ($text.Contains($upstreamFallback)) {
  $updated = $text.Replace($upstreamFallback, $ghosiumFallback)
  [IO.File]::WriteAllText($target, $updated, [Text.UTF8Encoding]::new($false))
  Write-Host 'Ghosium Search installed as the source-engine distribution fallback.'
} else {
  throw 'Pinned Chromium fallback-search implementation changed; refusing an unreviewed rewrite.'
}

$verify = [IO.File]::ReadAllText($target)
foreach ($required in @(
  'Ghosium Search',
  'u"search.ghosium.com"',
  'https://search.ghosium.com/?q={searchTerms}',
  'https://search.ghosium.com/api/suggest.php?q={searchTerms}',
  'prepopulate_id = 1101',
  '9e993bd9-c256-42d7-a1b1-000000001101',
  'send_x_geo_header'
)) {
  if ($required -eq 'send_x_geo_header') {
    # The default TemplateURLData constructor keeps this privacy-sensitive flag
    # false. Reject a future patch that explicitly enables it in our fallback.
    if ($verify -match '(?s)Ghosium Search.*?send_x_geo_header\s*=\s*true') {
      throw 'Ghosium Search fallback must not enable the X-Geo header.'
    }
    continue
  }
  if (!$verify.Contains($required)) {
    throw "Ghosium Search fallback verification failed: missing $required"
  }
}

$thirdPartyChanges = & git -C $sourceRootResolved status --porcelain=v1 -- third_party
if ($LASTEXITCODE -ne 0) {
  throw 'Unable to verify third_party source state after default-search integration.'
}
if ($thirdPartyChanges) {
  throw 'Default-search integration modified third_party sources; refusing to continue.'
}

Write-Host 'Ghosium Search source integration: OK'
