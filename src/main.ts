import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";

interface TabSnapshot {
  id: string;
  title: string;
  url: string | null;
  loading: boolean;
  blocked: number;
  hasWebview: boolean;
  discarded: boolean;
}

interface TabEvent {
  id: string;
  title?: string;
  url?: string;
  loading?: boolean;
  blocked?: number;
  discarded?: boolean;
}

interface BrowserStats {
  totalTabs: number;
  liveWebviews: number;
  discardedTabs: number;
  maxLiveWebviews: number;
  maxTabs: number;
}

interface PopupNavigation {
  tabId: string;
  url: string;
}

interface ClosedTab {
  title: string;
  url: string | null;
}

const MAX_INPUT_LENGTH = 8192;
const MAX_CLOSED_TABS = 25;
const appWindow = getCurrentWindow();
const app = document.querySelector<HTMLDivElement>("#app")!;

app.innerHTML = `
  <main class="browser-shell">
    <header class="browser-chrome" id="browser-chrome">
      <div class="tabstrip drag-region" id="drag-region">
        <div class="brand" aria-label="Ghost Browser"><span class="ghost-mark">G</span></div>
        <div class="tabs" id="tabs"></div>
        <button class="chrome-button new-tab-button no-drag" id="new-tab" title="Novi tab" aria-label="Novi tab">+</button>
        <div class="window-controls no-drag">
          <button id="minimize" class="window-button" aria-label="Minimiziraj">—</button>
          <button id="maximize" class="window-button" aria-label="Maksimiziraj">□</button>
          <button id="close-window" class="window-button close" aria-label="Zatvori">×</button>
        </div>
      </div>
      <div class="toolbar no-drag">
        <div class="nav-cluster">
          <button id="back" class="icon-button" title="Natrag" aria-label="Natrag">‹</button>
          <button id="forward" class="icon-button" title="Naprijed" aria-label="Naprijed">›</button>
          <button id="reload" class="icon-button" title="Osvježi" aria-label="Osvježi">↻</button>
        </div>
        <form id="omnibox-form" class="omnibox" autocomplete="off">
          <span id="connection-icon" class="connection-icon" aria-hidden="true">◈</span>
          <input id="omnibox" type="text" spellcheck="false" autocapitalize="off" autocomplete="off"
                 maxlength="8192" aria-label="Adresa i pretraživanje"
                 placeholder="Pretraži web ili upiši web-adresu" />
          <button type="button" id="shield" class="shield" title="Ghost zaštita" aria-label="Ghost zaštita">
            <span class="shield-icon">◆</span><span id="blocked-count">0</span>
          </button>
        </form>
        <button id="privacy" class="icon-button toolbar-action" title="Privatnost" aria-label="Privatnost">◌</button>
        <button id="menu" class="icon-button toolbar-action" title="Izbornik" aria-label="Izbornik" aria-expanded="false">⋯</button>
      </div>
    </header>

    <section class="newtab" id="newtab">
      <div class="newtab-inner">
        <div class="hero-mark">G</div>
        <h1>Ghost Browser</h1>
        <p>Brzo. Privatno. Pod vašom kontrolom.</p>
        <form id="newtab-search" class="newtab-search" autocomplete="off">
          <span aria-hidden="true">⌕</span>
          <input id="newtab-input" type="text" maxlength="8192"
                 placeholder="Pretraži web ili upiši adresu" spellcheck="false" autocomplete="off"
                 aria-label="Pretraživanje ili web-adresa" />
        </form>
        <div class="privacy-cards">
          <article><strong>Zaštita od praćenja</strong><span>Poznati trackeri i oglasne mreže blokiraju se prije prikaza.</span></article>
          <article><strong>Čiste adrese</strong><span>Parametri za praćenje uklanjaju se prije navigacije.</span></article>
          <article><strong>Memory Saver</strong><span>Neaktivni tabovi oslobađaju memoriju i obnavljaju se kada ih otvorite.</span></article>
        </div>
      </div>
    </section>

    <aside class="panel" id="privacy-panel" aria-hidden="true">
      <div class="panel-header">
        <div><small>GHOST ZAŠTITA</small><h2>Privatnost</h2></div>
        <button id="close-panel" class="icon-button" aria-label="Zatvori">×</button>
      </div>
      <div class="panel-status">
        <span class="status-dot"></span>
        <div><strong>Zaštita je uključena</strong><p>Ghost Browser nema vlastitu analitiku, oglase ni korisničke profile.</p></div>
      </div>
      <div class="setting"><div><strong>Reklame i trackeri</strong><span>Blokiranje poznatih mreža za oglašavanje i praćenje</span></div><span class="status-badge">Uključeno</span></div>
      <div class="setting"><div><strong>WebRTC zaštita</strong><span>Osjetljive mrežne i medijske dozvole blokirane su po zadanom</span></div><span class="status-badge">Uključeno</span></div>
      <div class="setting"><div><strong>Privacy signali</strong><span>Do Not Track i Global Privacy Control</span></div><span class="status-badge">Uključeno</span></div>
      <div class="panel-actions"><button id="clear-data" class="primary-button">Obriši podatke pregledavanja</button></div>
    </aside>

    <aside class="app-menu" id="app-menu" aria-hidden="true">
      <button class="menu-item" id="menu-new-tab"><span>Novi tab</span><kbd>Ctrl+T</kbd></button>
      <button class="menu-item" id="menu-reopen-tab"><span>Ponovno otvori zatvoreni tab</span><kbd>Ctrl+Shift+T</kbd></button>
      <div class="menu-separator"></div>
      <button class="menu-item" id="menu-memory-saver"><span>Oslobodi memoriju neaktivnih tabova</span></button>
      <div class="menu-status" id="memory-status">Memory Saver</div>
      <button class="menu-item" id="menu-clear-data"><span>Obriši podatke pregledavanja</span></button>
      <div class="menu-separator"></div>
      <div class="menu-footer"><strong>Ghost Browser</strong><span>Privatno pregledavanje za Windows</span></div>
    </aside>

    <div class="toast" id="toast" role="status" aria-live="polite"></div>
  </main>`;

const tabsEl = document.querySelector<HTMLDivElement>("#tabs")!;
const omnibox = document.querySelector<HTMLInputElement>("#omnibox")!;
const newtabInput = document.querySelector<HTMLInputElement>("#newtab-input")!;
const newtab = document.querySelector<HTMLElement>("#newtab")!;
const blockedCount = document.querySelector<HTMLSpanElement>("#blocked-count")!;
const connectionIcon = document.querySelector<HTMLSpanElement>("#connection-icon")!;
const privacyPanel = document.querySelector<HTMLElement>("#privacy-panel")!;
const appMenu = document.querySelector<HTMLElement>("#app-menu")!;
const menuButton = document.querySelector<HTMLButtonElement>("#menu")!;
const toast = document.querySelector<HTMLElement>("#toast")!;
const memoryStatus = document.querySelector<HTMLElement>("#memory-status")!;
const reopenButton = document.querySelector<HTMLButtonElement>("#menu-reopen-tab")!;

let tabs: TabSnapshot[] = [];
let activeTabId: string | null = null;
let closedTabs: ClosedTab[] = [];
let toastTimer: number | undefined;
let overlayOpen = false;

const activeTab = () => tabs.find((tab) => tab.id === activeTabId);
const escapeHtml = (value: string) =>
  value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");

function showToast(message: string): void {
  toast.textContent = message;
  toast.classList.add("show");
  if (toastTimer !== undefined) window.clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => toast.classList.remove("show"), 2600);
}

function userError(error: unknown): string {
  if (typeof error === "string" && error.trim()) return error;
  if (error instanceof Error && error.message.trim()) return error.message;
  return "Radnja nije uspjela.";
}

async function safeAction(action: () => Promise<void>): Promise<void> {
  try {
    await action();
  } catch (error) {
    showToast(userError(error));
  }
}

function renderTabs(): void {
  tabsEl.innerHTML = tabs
    .map((tab) => {
      const active = tab.id === activeTabId ? " active" : "";
      const loading = tab.loading ? " loading" : "";
      const discarded = tab.discarded ? " discarded" : "";
      const title = tab.title || "Novi tab";
      const icon = tab.loading ? "◌" : tab.discarded ? "◫" : "◇";
      return `<button class="tab${active}${loading}${discarded}" data-tab="${tab.id}" title="${escapeHtml(title)}">
        <span class="tab-favicon">${icon}</span>
        <span class="tab-title">${escapeHtml(title)}</span>
        <span class="tab-close" data-close-tab="${tab.id}" aria-label="Zatvori tab">×</span>
      </button>`;
    })
    .join("");
}

async function refreshMemoryStatus(): Promise<void> {
  const stats = await invoke<BrowserStats>("browser_stats");
  const sleeping = stats.discardedTabs;
  memoryStatus.textContent = sleeping > 0
    ? `${stats.totalTabs} tabova · ${stats.liveWebviews} aktivnih · ${sleeping} uspavanih`
    : `${stats.totalTabs} tabova · ${stats.liveWebviews} aktivnih`;
  reopenButton.disabled = closedTabs.length === 0;
}

function refreshChrome(): void {
  const tab = activeTab();
  const hasPage = Boolean(tab?.url);
  newtab.classList.toggle("hidden", Boolean(tab?.hasWebview || tab?.url));
  omnibox.value = tab?.url ?? "";
  blockedCount.textContent = String(tab?.blocked ?? 0);
  connectionIcon.textContent = tab?.url?.startsWith("https://") ? "◆" : tab?.url ? "!" : "◈";
  connectionIcon.classList.toggle("insecure", Boolean(tab?.url && !tab.url.startsWith("https://")));
  document.querySelector<HTMLButtonElement>("#back")!.disabled = !hasPage;
  document.querySelector<HTMLButtonElement>("#forward")!.disabled = !hasPage;
  document.querySelector<HTMLButtonElement>("#reload")!.disabled = !hasPage;
  renderTabs();
  void safeAction(refreshMemoryStatus);
}

async function setOverlay(open: boolean): Promise<void> {
  if (overlayOpen === open) return;
  overlayOpen = open;
  await invoke("set_overlay_open", { open });
}

async function closeOverlays(): Promise<void> {
  privacyPanel.classList.remove("open");
  privacyPanel.setAttribute("aria-hidden", "true");
  appMenu.classList.remove("open");
  appMenu.setAttribute("aria-hidden", "true");
  menuButton.setAttribute("aria-expanded", "false");
  await setOverlay(false);
}

async function openPrivacyPanel(): Promise<void> {
  appMenu.classList.remove("open");
  appMenu.setAttribute("aria-hidden", "true");
  menuButton.setAttribute("aria-expanded", "false");
  privacyPanel.classList.add("open");
  privacyPanel.setAttribute("aria-hidden", "false");
  await setOverlay(true);
}

async function toggleMenu(): Promise<void> {
  const opening = !appMenu.classList.contains("open");
  privacyPanel.classList.remove("open");
  privacyPanel.setAttribute("aria-hidden", "true");
  appMenu.classList.toggle("open", opening);
  appMenu.setAttribute("aria-hidden", String(!opening));
  menuButton.setAttribute("aria-expanded", String(opening));
  if (opening) await refreshMemoryStatus();
  await setOverlay(opening);
}

async function createTab(makeActive = true): Promise<TabSnapshot> {
  const tab = await invoke<TabSnapshot>("create_tab");
  tabs.push(tab);
  if (makeActive) {
    activeTabId = tab.id;
    await invoke("set_active_tab", { tabId: tab.id });
  }
  refreshChrome();
  window.setTimeout(() => omnibox.focus(), 0);
  return tab;
}

function normalizeInput(raw: string): { type: "url" | "search"; value: string } {
  const value = raw.trim();
  if (!value) throw new Error("Upišite pojam za pretraživanje ili web-adresu.");
  if (value.length > MAX_INPUT_LENGTH) throw new Error("Unos je predugačak.");
  if (/[\u0000-\u001F\u007F]/.test(value)) throw new Error("Unos sadrži nedopuštene znakove.");
  if (/^https?:\/\//i.test(value)) return { type: "url", value };
  if (/^(localhost|\d{1,3}(?:\.\d{1,3}){3})(:\d+)?(\/.*)?$/i.test(value)) {
    return { type: "url", value: `http://${value}` };
  }
  if (/^[\w.-]+\.[a-z]{2,}(?::\d+)?(?:\/.*)?$/i.test(value)) {
    return { type: "url", value: `https://${value}` };
  }
  return { type: "search", value };
}

async function resolveTarget(raw: string): Promise<string> {
  const parsed = normalizeInput(raw);
  if (parsed.type === "url") return parsed.value;
  return invoke<string>("resolve_search_query", { query: parsed.value });
}

async function navigateTab(tabId: string, raw: string): Promise<void> {
  const target = await resolveTarget(raw);
  omnibox.blur();
  await invoke("navigate_tab", { tabId, target });
}

async function navigateRaw(raw: string): Promise<void> {
  let tab = activeTab();
  if (!tab) tab = await createTab(true);
  await navigateTab(tab.id, raw);
}

async function closeTab(id: string): Promise<void> {
  const index = tabs.findIndex((tab) => tab.id === id);
  if (index < 0) return;
  const closing = tabs[index];
  closedTabs.push({ title: closing.title, url: closing.url });
  if (closedTabs.length > MAX_CLOSED_TABS) closedTabs.shift();

  await invoke("close_tab", { tabId: id });
  tabs.splice(index, 1);
  if (activeTabId === id) {
    const next = tabs[Math.min(index, tabs.length - 1)];
    activeTabId = next?.id ?? null;
    if (next) await invoke("set_active_tab", { tabId: next.id });
  }
  if (tabs.length === 0) await createTab(true);
  refreshChrome();
}

async function reopenClosedTab(): Promise<void> {
  const closed = closedTabs.pop();
  if (!closed) return;
  const tab = await createTab(true);
  if (closed.url) await navigateTab(tab.id, closed.url);
  await refreshMemoryStatus();
}

async function clearBrowsingData(): Promise<void> {
  await invoke("clear_browsing_data");
  for (const tab of tabs) tab.blocked = 0;
  blockedCount.textContent = "0";
  showToast("Podaci pregledavanja su obrisani.");
}

async function freeInactiveMemory(): Promise<void> {
  const discarded = await invoke<number>("discard_inactive_tabs");
  await refreshMemoryStatus();
  showToast(discarded > 0 ? `Oslobođena je memorija ${discarded} neaktivnih tabova.` : "Nema neaktivnih tabova za oslobađanje.");
}

async function syncViewport(): Promise<void> {
  const chrome = document.querySelector<HTMLElement>("#browser-chrome")!;
  const height = chrome.getBoundingClientRect().height;
  await invoke("sync_viewport", {
    x: 0,
    y: height,
    width: window.innerWidth,
    height: Math.max(1, window.innerHeight - height),
  });
}

document.querySelector("#new-tab")!.addEventListener("click", () => void safeAction(async () => { await closeOverlays(); await createTab(true); }));
document.querySelector<HTMLFormElement>("#omnibox-form")!.addEventListener("submit", (event) => {
  event.preventDefault();
  void safeAction(() => navigateRaw(omnibox.value));
});
document.querySelector<HTMLFormElement>("#newtab-search")!.addEventListener("submit", (event) => {
  event.preventDefault();
  void safeAction(() => navigateRaw(newtabInput.value));
});

tabsEl.addEventListener("click", (event) => {
  void safeAction(async () => {
    const target = event.target as HTMLElement;
    const close = target.closest<HTMLElement>("[data-close-tab]");
    if (close) {
      event.stopPropagation();
      await closeTab(close.dataset.closeTab!);
      return;
    }
    const tabButton = target.closest<HTMLButtonElement>("[data-tab]");
    if (!tabButton) return;
    await closeOverlays();
    activeTabId = tabButton.dataset.tab!;
    await invoke("set_active_tab", { tabId: activeTabId });
    const tab = activeTab();
    if (tab) {
      tab.hasWebview = Boolean(tab.url);
      tab.discarded = false;
    }
    refreshChrome();
  });
});

document.querySelector("#back")!.addEventListener("click", () => activeTabId && void safeAction(() => invoke("go_back", { tabId: activeTabId! })));
document.querySelector("#forward")!.addEventListener("click", () => activeTabId && void safeAction(() => invoke("go_forward", { tabId: activeTabId! })));
document.querySelector("#reload")!.addEventListener("click", () => activeTabId && void safeAction(() => invoke("reload_tab", { tabId: activeTabId! })));
for (const selector of ["#shield", "#privacy"]) {
  document.querySelector(selector)!.addEventListener("click", () => void safeAction(openPrivacyPanel));
}
document.querySelector("#close-panel")!.addEventListener("click", () => void safeAction(closeOverlays));
document.querySelector("#clear-data")!.addEventListener("click", () => void safeAction(clearBrowsingData));
menuButton.addEventListener("click", () => void safeAction(toggleMenu));
document.querySelector("#menu-new-tab")!.addEventListener("click", () => void safeAction(async () => { await closeOverlays(); await createTab(true); }));
document.querySelector("#menu-reopen-tab")!.addEventListener("click", () => void safeAction(async () => { await closeOverlays(); await reopenClosedTab(); }));
document.querySelector("#menu-memory-saver")!.addEventListener("click", () => void safeAction(async () => { await freeInactiveMemory(); await closeOverlays(); }));
document.querySelector("#menu-clear-data")!.addEventListener("click", () => void safeAction(async () => { await clearBrowsingData(); await closeOverlays(); }));

document.querySelector("#minimize")!.addEventListener("click", () => void appWindow.minimize());
document.querySelector("#maximize")!.addEventListener("click", () => void appWindow.toggleMaximize());
document.querySelector("#close-window")!.addEventListener("click", () => void appWindow.close());
document.querySelector<HTMLElement>("#drag-region")!.addEventListener("pointerdown", (event: PointerEvent) => {
  if ((event.target as HTMLElement).closest(".no-drag, button, input, select")) return;
  if (event.button === 0) void appWindow.startDragging();
});
document.querySelector<HTMLElement>("#drag-region")!.addEventListener("dblclick", (event: MouseEvent) => {
  if ((event.target as HTMLElement).closest("button, input, select")) return;
  void appWindow.toggleMaximize();
});

window.addEventListener("resize", () => void safeAction(syncViewport));
window.addEventListener("keydown", (event) => {
  if (event.ctrlKey && event.key.toLowerCase() === "l") {
    event.preventDefault();
    void safeAction(closeOverlays);
    omnibox.focus();
    omnibox.select();
  } else if (event.ctrlKey && event.shiftKey && event.key.toLowerCase() === "t") {
    event.preventDefault();
    void safeAction(reopenClosedTab);
  } else if (event.ctrlKey && event.key.toLowerCase() === "t") {
    event.preventDefault();
    void safeAction(async () => { await closeOverlays(); await createTab(true); });
  } else if (event.ctrlKey && event.key.toLowerCase() === "w" && activeTabId) {
    event.preventDefault();
    void safeAction(() => closeTab(activeTabId!));
  } else if (event.ctrlKey && event.shiftKey && event.key === "Delete") {
    event.preventDefault();
    void safeAction(clearBrowsingData);
  } else if (event.altKey && event.key === "ArrowLeft" && activeTabId) {
    event.preventDefault();
    void safeAction(() => invoke("go_back", { tabId: activeTabId! }));
  } else if (event.altKey && event.key === "ArrowRight" && activeTabId) {
    event.preventDefault();
    void safeAction(() => invoke("go_forward", { tabId: activeTabId! }));
  } else if (event.key === "F5" && activeTabId) {
    event.preventDefault();
    void safeAction(() => invoke("reload_tab", { tabId: activeTabId! }));
  } else if (event.key === "Escape") {
    void safeAction(closeOverlays);
  }
});

await listen<TabEvent>("ghost://tab-event", (event) => {
  const update = event.payload;
  const tab = tabs.find((item) => item.id === update.id);
  if (!tab) return;
  if (update.title !== undefined) tab.title = update.title || "Novi tab";
  if (update.url !== undefined) tab.url = update.url;
  if (update.loading !== undefined) tab.loading = update.loading;
  if (update.blocked !== undefined) tab.blocked = update.blocked;
  if (update.discarded !== undefined) {
    tab.discarded = update.discarded;
    tab.hasWebview = !update.discarded && Boolean(tab.url);
  }
  if (tab.id === activeTabId) refreshChrome();
  else {
    renderTabs();
    void safeAction(refreshMemoryStatus);
  }
});

await listen<PopupNavigation>("ghost://open-current-tab", (event) => {
  const payload = event.payload;
  if (!payload?.tabId || !payload?.url) return;
  void safeAction(() => navigateTab(payload.tabId, payload.url));
});

await listen<{ url?: string }>("ghost://download", () => {
  showToast("Preuzimanje je pokrenuto.");
});

await safeAction(syncViewport);
await safeAction(async () => { await createTab(true); });
