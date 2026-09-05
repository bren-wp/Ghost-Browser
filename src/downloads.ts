import { listen } from "@tauri-apps/api/event";
import "./downloads.css";

interface DownloadRequestedEvent {
  tabId: string;
  url: string;
}

interface DownloadRecord {
  id: string;
  url: string;
  fileName: string;
  origin: string;
  startedAt: Date;
}

const downloads: DownloadRecord[] = [];
let panel: HTMLElement | null = null;
let list: HTMLElement | null = null;
let countBadge: HTMLElement | null = null;

function fileNameFromUrl(rawUrl: string): string {
  try {
    const url = new URL(rawUrl);
    const candidate = decodeURIComponent(url.pathname.split("/").filter(Boolean).at(-1) ?? "");
    return candidate || "Preuzimanje";
  } catch {
    return "Preuzimanje";
  }
}

function originFromUrl(rawUrl: string): string {
  try {
    return new URL(rawUrl).hostname || "Lokalni sadržaj";
  } catch {
    return "Lokalni sadržaj";
  }
}

function formatTime(date: Date): string {
  return new Intl.DateTimeFormat("hr-HR", {
    hour: "2-digit",
    minute: "2-digit",
  }).format(date);
}

function renderDownloads(): void {
  if (!list || !countBadge) return;
  countBadge.textContent = String(downloads.length);
  list.replaceChildren();

  if (downloads.length === 0) {
    const empty = document.createElement("div");
    empty.className = "download-empty";
    const title = document.createElement("strong");
    title.textContent = "Nema preuzimanja";
    const description = document.createElement("span");
    description.textContent = "Datoteke koje pokrenete s web-stranica pojavit će se ovdje.";
    empty.append(title, description);
    list.append(empty);
    return;
  }

  for (const item of downloads) {
    const row = document.createElement("article");
    row.className = "download-row";

    const icon = document.createElement("span");
    icon.className = "download-icon";
    icon.textContent = "↓";

    const details = document.createElement("div");
    details.className = "download-details";

    const title = document.createElement("strong");
    title.textContent = item.fileName;
    title.title = item.url;

    const meta = document.createElement("span");
    meta.textContent = `${item.origin} · ${formatTime(item.startedAt)}`;

    const status = document.createElement("small");
    status.textContent = "Preuzimanje pokrenuto";

    details.append(title, meta, status);
    row.append(icon, details);
    list.append(row);
  }
}

function setPanelOpen(open: boolean): void {
  if (!panel) return;
  panel.classList.toggle("open", open);
  panel.setAttribute("aria-hidden", String(!open));
}

function mountDownloadsUi(): void {
  if (panel) return;
  const shell = document.querySelector<HTMLElement>(".browser-shell");
  const menuButton = document.querySelector<HTMLButtonElement>("#menu");
  if (!shell || !menuButton) return;

  menuButton.title = "Preuzimanja (Ctrl+J)";
  menuButton.setAttribute("aria-label", "Preuzimanja");

  panel = document.createElement("aside");
  panel.id = "downloads-panel";
  panel.className = "panel downloads-panel";
  panel.setAttribute("aria-hidden", "true");

  const header = document.createElement("div");
  header.className = "panel-header";

  const heading = document.createElement("div");
  const eyebrow = document.createElement("small");
  eyebrow.textContent = "GHOST BROWSER";
  const title = document.createElement("h2");
  title.textContent = "Preuzimanja";
  heading.append(eyebrow, title);

  const close = document.createElement("button");
  close.className = "icon-button";
  close.type = "button";
  close.textContent = "×";
  close.setAttribute("aria-label", "Zatvori preuzimanja");
  close.addEventListener("click", () => setPanelOpen(false));

  header.append(heading, close);

  const summary = document.createElement("div");
  summary.className = "download-summary";
  const summaryLabel = document.createElement("span");
  summaryLabel.textContent = "Sesija";
  countBadge = document.createElement("strong");
  countBadge.textContent = "0";
  summary.append(summaryLabel, countBadge);

  list = document.createElement("div");
  list.className = "download-list";

  panel.append(header, summary, list);
  shell.append(panel);

  menuButton.addEventListener("click", () => {
    const shouldOpen = !panel?.classList.contains("open");
    setPanelOpen(Boolean(shouldOpen));
  });

  document.addEventListener("pointerdown", (event) => {
    if (!panel?.classList.contains("open")) return;
    const target = event.target as Node;
    if (panel.contains(target) || menuButton.contains(target)) return;
    setPanelOpen(false);
  });

  window.addEventListener("keydown", (event) => {
    if (event.ctrlKey && event.key.toLowerCase() === "j") {
      event.preventDefault();
      setPanelOpen(true);
    } else if (event.key === "Escape" && panel?.classList.contains("open")) {
      event.preventDefault();
      setPanelOpen(false);
    }
  });

  renderDownloads();
}

await listen<DownloadRequestedEvent>("ghost://download", (event) => {
  const payload = event.payload;
  downloads.unshift({
    id: crypto.randomUUID(),
    url: payload.url,
    fileName: fileNameFromUrl(payload.url),
    origin: originFromUrl(payload.url),
    startedAt: new Date(),
  });
  renderDownloads();
  setPanelOpen(true);
});

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", mountDownloadsUi, { once: true });
} else {
  mountDownloadsUi();
}
