import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

interface Bookmark {
  id: string;
  title: string;
  url: string;
  createdAt: number;
}

interface HistoryEntry {
  id: string;
  title: string;
  url: string;
  visitedAt: number;
}

interface DownloadEntry {
  id: string;
  url: string;
  startedAt: number;
}

interface VaultEntry {
  id: string;
  origin: string;
  username: string;
  label: string;
  createdAt: number;
  updatedAt: number;
}

interface TabEvent {
  id: string;
  title?: string;
  url?: string;
  loading?: boolean;
}

interface PopupNavigation {
  tabId: string;
  url: string;
}

type Section = "favorites" | "history" | "downloads" | "vault";

const tabState = new Map<string, { title: string; url: string | null; loading: boolean }>();
let activeTabId: string | null = null;
let currentSection: Section = "favorites";
let drawer: HTMLElement | null = null;
let content: HTMLElement | null = null;
let titleEl: HTMLElement | null = null;
let initialized = false;

const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

function shortHost(url: string): string {
  try {
    return new URL(url).host;
  } catch {
    return url;
  }
}

function formatTime(epoch: number): string {
  return new Date(epoch * 1000).toLocaleString("hr-HR", {
    dateStyle: "short",
    timeStyle: "short",
  });
}

function activeTab() {
  return activeTabId ? tabState.get(activeTabId) : undefined;
}

async function setRendererHidden(hidden: boolean): Promise<void> {
  await invoke("set_overlay_open", { open: hidden });
}

function closeChromePanels(): void {
  document.querySelector("#privacy-panel")?.classList.remove("open");
  const menu = document.querySelector("#app-menu");
  menu?.classList.remove("open");
  menu?.setAttribute("aria-hidden", "true");
  document.querySelector("#menu")?.setAttribute("aria-expanded", "false");
}

async function closeDrawer(): Promise<void> {
  if (!drawer?.classList.contains("open")) return;
  drawer.classList.remove("open");
  drawer.setAttribute("aria-hidden", "true");
  await setRendererHidden(false);
}

async function openDrawer(section: Section): Promise<void> {
  if (!drawer || !content || !titleEl) return;
  closeChromePanels();
  currentSection = section;
  titleEl.textContent = {
    favorites: "Favoriti",
    history: "Povijest",
    downloads: "Preuzimanja",
    vault: "Password Vault",
  }[section];
  await setRendererHidden(true);
  drawer.classList.add("open");
  drawer.setAttribute("aria-hidden", "false");
  await renderSection();
}

function renderEmpty(message: string): void {
  if (!content) return;
  content.innerHTML = `<div class="library-empty">${escapeHtml(message)}</div>`;
}

async function renderFavorites(): Promise<void> {
  if (!content) return;
  const items = await invoke<Bookmark[]>("list_bookmarks");
  if (items.length === 0) {
    renderEmpty("Još nema spremljenih favorita.");
    return;
  }

  content.innerHTML = `<div class="library-list">${items.map((item) => `
    <article class="library-item">
      <button class="library-main" data-open-url="${escapeHtml(item.url)}">
        <strong>${escapeHtml(item.title)}</strong>
        <span>${escapeHtml(shortHost(item.url))}</span>
      </button>
      <button class="library-icon danger" data-remove-bookmark="${item.id}" title="Ukloni">×</button>
    </article>`).join("")}</div>`;
}

async function renderHistory(): Promise<void> {
  if (!content) return;
  const items = await invoke<HistoryEntry[]>("list_history", { limit: 250 });
  if (items.length === 0) {
    renderEmpty("Povijest je prazna.");
    return;
  }

  content.innerHTML = `
    <div class="library-actions"><button class="library-secondary" id="clear-history">Obriši povijest</button></div>
    <div class="library-list">${items.map((item) => `
      <article class="library-item">
        <button class="library-main" data-open-url="${escapeHtml(item.url)}">
          <strong>${escapeHtml(item.title || shortHost(item.url))}</strong>
          <span>${escapeHtml(shortHost(item.url))} · ${escapeHtml(formatTime(item.visitedAt))}</span>
        </button>
      </article>`).join("")}</div>`;
}

async function renderDownloads(): Promise<void> {
  if (!content) return;
  const items = await invoke<DownloadEntry[]>("list_downloads", { limit: 250 });
  if (items.length === 0) {
    renderEmpty("Nema zabilježenih preuzimanja.");
    return;
  }

  content.innerHTML = `
    <div class="library-actions"><button class="library-secondary" id="clear-downloads">Očisti popis</button></div>
    <div class="library-list">${items.map((item) => `
      <article class="library-item">
        <button class="library-main" data-open-url="${escapeHtml(item.url)}">
          <strong>${escapeHtml(shortHost(item.url))}</strong>
          <span>${escapeHtml(formatTime(item.startedAt))}</span>
        </button>
      </article>`).join("")}</div>`;
}

function vaultForm(defaultOrigin = ""): string {
  return `
    <form class="vault-form" id="vault-form" autocomplete="off">
      <label><span>Web-stranica</span><input id="vault-origin" type="url" required maxlength="8192" value="${escapeHtml(defaultOrigin)}" placeholder="https://example.com" /></label>
      <label><span>Korisničko ime</span><input id="vault-username" type="text" required maxlength="2048" autocomplete="off" /></label>
      <label><span>Lozinka</span><input id="vault-password" type="password" required maxlength="2048" autocomplete="new-password" /></label>
      <label><span>Naziv</span><input id="vault-label" type="text" maxlength="2048" placeholder="Opcionalno" /></label>
      <button class="library-primary" type="submit">Sigurno spremi</button>
      <p class="vault-note">Lozinka se sprema u Windows Credential Manager. Ghost profil sadrži samo metapodatke.</p>
    </form>`;
}

async function renderVault(): Promise<void> {
  if (!content) return;
  const items = await invoke<VaultEntry[]>("vault_list");
  const tab = activeTab();
  let origin = "";
  try {
    if (tab?.url) origin = new URL(tab.url).origin;
  } catch {
    origin = "";
  }

  content.innerHTML = `
    <details class="library-create" ${items.length === 0 ? "open" : ""}>
      <summary>Dodaj spremljenu prijavu</summary>
      ${vaultForm(origin)}
    </details>
    <div class="library-list vault-list">${items.map((item) => `
      <article class="library-item vault-item">
        <div class="library-main static">
          <strong>${escapeHtml(item.label)}</strong>
          <span>${escapeHtml(item.origin)}</span>
          <small>${escapeHtml(item.username)}</small>
        </div>
        <div class="vault-buttons">
          <button class="library-secondary" data-fill-vault="${item.id}">Ispuni</button>
          <button class="library-icon danger" data-delete-vault="${item.id}" title="Obriši">×</button>
        </div>
      </article>`).join("")}</div>`;
}

async function renderSection(): Promise<void> {
  if (currentSection === "favorites") await renderFavorites();
  if (currentSection === "history") await renderHistory();
  if (currentSection === "downloads") await renderDownloads();
  if (currentSection === "vault") await renderVault();
}

async function addCurrentFavorite(): Promise<void> {
  const tab = activeTab();
  if (!tab?.url) return;
  await invoke("add_bookmark", {
    title: tab.title || shortHost(tab.url),
    url: tab.url,
  });
  const button = document.querySelector<HTMLButtonElement>("#bookmark-current");
  if (button) button.textContent = "★";
  if (drawer?.classList.contains("open") && currentSection === "favorites") {
    await renderFavorites();
  }
}

async function navigate(url: string): Promise<void> {
  if (!activeTabId) return;
  await invoke("navigate_tab", { tabId: activeTabId, target: url });
  await closeDrawer();
}

async function handleContentClick(event: Event): Promise<void> {
  const target = event.target as HTMLElement;
  const open = target.closest<HTMLElement>("[data-open-url]");
  if (open?.dataset.openUrl) {
    await navigate(open.dataset.openUrl);
    return;
  }

  const remove = target.closest<HTMLElement>("[data-remove-bookmark]");
  if (remove?.dataset.removeBookmark) {
    await invoke("remove_bookmark", { id: remove.dataset.removeBookmark });
    await renderFavorites();
    return;
  }

  const fill = target.closest<HTMLElement>("[data-fill-vault]");
  if (fill?.dataset.fillVault) {
    if (!activeTabId) throw new Error("Otvorite web-stranicu prije ispune prijave.");
    await invoke("vault_fill", { id: fill.dataset.fillVault, tabId: activeTabId });
    await closeDrawer();
    return;
  }

  const removeVault = target.closest<HTMLElement>("[data-delete-vault]");
  if (removeVault?.dataset.deleteVault) {
    await invoke("vault_delete", { id: removeVault.dataset.deleteVault });
    await renderVault();
    return;
  }

  if (target.closest("#clear-history")) {
    await invoke("clear_history");
    await renderHistory();
    return;
  }

  if (target.closest("#clear-downloads")) {
    await invoke("clear_downloads");
    await renderDownloads();
  }
}

async function handleContentSubmit(event: SubmitEvent): Promise<void> {
  const form = event.target as HTMLFormElement;
  if (form.id !== "vault-form") return;
  event.preventDefault();

  const origin = (form.querySelector<HTMLInputElement>("#vault-origin")?.value ?? "").trim();
  const username = (form.querySelector<HTMLInputElement>("#vault-username")?.value ?? "").trim();
  const password = form.querySelector<HTMLInputElement>("#vault-password")?.value ?? "";
  const label = (form.querySelector<HTMLInputElement>("#vault-label")?.value ?? "").trim();
  await invoke("vault_save", { id: null, origin, username, password, label });
  form.reset();
  await renderVault();
}

async function initialize(): Promise<void> {
  if (initialized) return;
  const shell = document.querySelector<HTMLElement>(".browser-shell");
  const menu = document.querySelector<HTMLElement>("#app-menu");
  const shield = document.querySelector<HTMLElement>("#shield");
  if (!shell || !menu || !shield) {
    window.setTimeout(() => void initialize(), 25);
    return;
  }
  initialized = true;

  const favorite = document.createElement("button");
  favorite.type = "button";
  favorite.id = "bookmark-current";
  favorite.className = "shield bookmark-button";
  favorite.title = "Dodaj u favorite";
  favorite.setAttribute("aria-label", "Dodaj u favorite");
  favorite.textContent = "☆";
  shield.before(favorite);
  favorite.addEventListener("click", () => void addCurrentFavorite().catch(console.error));

  const separator = document.createElement("div");
  separator.className = "menu-separator";
  const fragment = document.createDocumentFragment();
  fragment.append(separator);
  const sections: Array<[Section, string, string]> = [
    ["favorites", "Favoriti", "Ctrl+Shift+B"],
    ["history", "Povijest", "Ctrl+H"],
    ["downloads", "Preuzimanja", "Ctrl+J"],
    ["vault", "Password Vault", "Ctrl+Shift+P"],
  ];
  for (const [section, label, shortcut] of sections) {
    const button = document.createElement("button");
    button.className = "menu-item";
    button.type = "button";
    button.dataset.librarySection = section;
    button.innerHTML = `<span>${escapeHtml(label)}</span><kbd>${escapeHtml(shortcut)}</kbd>`;
    button.addEventListener("click", () => void openDrawer(section).catch(console.error));
    fragment.append(button);
  }
  menu.querySelector(".menu-footer")?.before(fragment);

  shell.insertAdjacentHTML("beforeend", `
    <aside class="library-drawer" id="library-drawer" aria-hidden="true">
      <header class="library-header">
        <div><small>GHOST LOKALNO</small><h2 id="library-title">Favoriti</h2></div>
        <button class="library-close" id="library-close" aria-label="Zatvori">×</button>
      </header>
      <div class="library-content" id="library-content"></div>
    </aside>`);

  drawer = document.querySelector("#library-drawer");
  content = document.querySelector("#library-content");
  titleEl = document.querySelector("#library-title");
  document.querySelector("#library-close")?.addEventListener("click", () => void closeDrawer().catch(console.error));
  content?.addEventListener("click", (event) => void handleContentClick(event).catch(console.error));
  content?.addEventListener("submit", (event) => void handleContentSubmit(event as SubmitEvent).catch(console.error));

  window.addEventListener("keydown", (event) => {
    const key = event.key.toLowerCase();
    if (event.ctrlKey && event.shiftKey && key === "b") {
      event.preventDefault();
      void openDrawer("favorites").catch(console.error);
    } else if (event.ctrlKey && !event.shiftKey && key === "h") {
      event.preventDefault();
      void openDrawer("history").catch(console.error);
    } else if (event.ctrlKey && !event.shiftKey && key === "j") {
      event.preventDefault();
      void openDrawer("downloads").catch(console.error);
    } else if (event.ctrlKey && event.shiftKey && key === "p") {
      event.preventDefault();
      void openDrawer("vault").catch(console.error);
    } else if (event.key === "Escape" && drawer?.classList.contains("open")) {
      event.preventDefault();
      void closeDrawer().catch(console.error);
    }
  }, true);
}

await listen<TabEvent>("ghost://tab-event", (event) => {
  const update = event.payload;
  const existing = tabState.get(update.id) ?? { title: "Novi tab", url: null, loading: false };
  if (update.title !== undefined) existing.title = update.title || "Novi tab";
  if (update.url !== undefined) existing.url = update.url;
  if (update.loading !== undefined) existing.loading = update.loading;
  tabState.set(update.id, existing);

  if (update.loading === false && existing.url) {
    void invoke("record_history", {
      title: existing.title || shortHost(existing.url),
      url: existing.url,
    }).catch(() => undefined);
  }
});

await listen<PopupNavigation>("ghost://open-current-tab", (event) => {
  if (event.payload?.tabId) activeTabId = event.payload.tabId;
});

await listen<{ tabId?: string; url?: string }>("ghost://download", (event) => {
  if (event.payload?.url) {
    void invoke("record_download", { url: event.payload.url }).catch(() => undefined);
  }
});

window.addEventListener("focus", () => {
  const active = document.querySelector<HTMLElement>(".tab.active[data-tab]")?.dataset.tab;
  if (active) activeTabId = active;
});

const activeObserver = new MutationObserver(() => {
  const active = document.querySelector<HTMLElement>(".tab.active[data-tab]")?.dataset.tab;
  if (active) activeTabId = active;
});
activeObserver.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["class"] });

void initialize();
