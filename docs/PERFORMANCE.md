# Performance on weaker PCs

Ghosium aims to preserve Chromium compatibility and security while reducing unnecessary resource use.

## Automatic mode selection

The C++ launcher reads physical RAM with the Windows memory API.

- **8 GiB RAM or less:** Low Memory mode
- **more than 8 GiB:** Balanced mode

Low Memory mode adds upstream Chromium `--renderer-process-limit=6` and `--disk-cache-size=134217728`.

## Manual overrides

- `Ghosium-Browser.exe --ghosium-low-memory` forces Low Memory mode.
- `Ghosium-Browser.exe --ghosium-balanced` forces normal Chromium resource behavior.

## What is not disabled

Ghosium does not disable the Chromium sandbox, certificate validation, Site Isolation or web security to reduce memory. Those changes can appear faster in synthetic tests while materially weakening the browser.

## Practical recommendations

On 4–8 GiB systems keep the number of simultaneously active media-heavy tabs low and enable Chromium's built-in Memory Saver controls when available in the shipped revision. Removing unused extensions can also reduce background processes.
