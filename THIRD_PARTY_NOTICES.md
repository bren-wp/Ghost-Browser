# Third-Party Notices

## Chromium

Ghosium Browser redistributes an upstream open-source Chromium Windows build.

Chromium source: https://chromium.googlesource.com/chromium/src/

The exact Chromium snapshot revision and source revision included in a Ghosium release are recorded in `BUILD-INFO.json` and `CHROMIUM-REVISION.txt` inside that release.

Chromium is distributed under a BSD-style license and contains third-party components under their respective licenses. Ghosium release assembly downloads the Chromium license text corresponding to the resolved Chromium source revision when that metadata is available and includes it as `CHROMIUM-LICENSE.txt` in the distribution.

Chromium's built-in credits page remains part of the upstream runtime and provides third-party component notices for the shipped Chromium build.

Ghosium does not claim ownership of Chromium, Chromium project names, third-party code, codecs, trademarks or upstream artwork.

## Ghosium-authored code

The C++ launcher, Ghosium privacy rules and Ghosium presentation resources in this repository are covered by the repository `LICENSE` unless a file states otherwise.

## Search provider

The local new-tab form uses DuckDuckGo as a direct form target when the user explicitly submits that form. DuckDuckGo is not bundled software and is not part of Ghosium. Users can use Chromium's omnibox and configure another search provider through browser settings.
