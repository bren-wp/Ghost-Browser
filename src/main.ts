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
}

interface TabEvent {
  id: string;
  title?: string;
  url?: string;
  loading?: boolean;
  blocked?: number;
}

const appWindow = getCurrentWindow();
const app = document.querySelector<HTMLDivElement>("#app")!;

app.innerHTML = `
  <main class="browser-shell">
    <header class="browser-chrome" id="browser-chrome">
      <div class="tabstrip drag-region" id="drag-region">
        <div class="brand" aria-label="Ghost Browser"><span class="ghost-mark">G</span></div>
        <div class="tabs" id="tabs"></div>
        <button class="chrome-button new-tab-button no-drag" id="new-tab" title="Novi tab">+</button>
        <div class="window-controls no-drag">
          <button id="minimize" class="window-button" aria-label="Minimiziraj">—</button>
          <button id="maximize" class="window-button" aria-label="Maksimiziraj">□</button>
          <button id="close-window" class="window-button close" aria-label="Zatvori">×</button>
        </div>
      </div>
      <div class="toolbar no-drag">
        <div class="nav-cluster">
          <button id="back" class="icon-button" title="Natrag">‹</button>
          <button id="forward" class="icon-button" title="Naprijed">›</button>
          <button id="reload" class="icon-button" title="Osvježi">↻</button>
        </div>
        <form id="omnibox-form" class="omnibox" autocomplete="off">
          <span id="connection-icon" class="connection-icon">◈</span>
          <input id="omnibox" type="text" spellcheck="false" autocapitalize="off" autocomplete="off" placeholder="Pretraži ili upiši web-adresu" />
          <button type="button" id="shield" class="shield" title="Ghost Shields"><span class="shield-icon">◆</span><span id="blocked-count">0</span></button>
        </form>
        <button id="privacy" class="icon-button toolbar-action" title="Privatnost">◌</button>
        <button id="menu" class="icon-button toolbar-action" title="Izbornik">⋯</button>
      </div>
    </header>

    <section class="newtab" id="newtab">
      <div class="newtab-inner">
        <div class="hero-mark">G</div>
        <h1>Ghost Browser</h1>
        <p>Privatno pregledavanje bez telemetrije aplikacije.</p>
        <form id="newtab-search" class="newtab-search" autocomplete="off">
          <span>⌕</span><input id="newtab-input" type="text" placeholder="Pretraži ili upiši adresu" spellcheck="false" autocomplete="off" />
        </form>
        <div class="privacy-cards">
          <article><strong>AdBlock</strong><span>Blokiranje prije učitavanja</span></article>
          <article><strong>Anti-tracking</strong><span>Zaštita od poznatih trackera</span></article>
          <article><strong>WebRTC</strong><span>Ograničeno po zadanom</span></article>
        </div>
      </div>
    </section>

    <aside class="panel" id="privacy-panel" aria-hidden="true">
      <div class="panel-header"><div><small>GHOST SHIELDS</small><h2>Privatnost</h2></div><button id="close-panel" class="icon-button">×</button></div>
      <div class="panel-status"><span class="status-dot"></span><div><strong>Stroga zaštita uključena</strong><p>Ghost ne šalje vlastitu telemetriju ni analitiku.</p></div></div>
      <div class="setting"><div><strong>Blokiraj reklame i trackere</strong><span>Native request filtering</span></div><span class="toggle on"></span></div>
      <div class="setting"><div><strong>WebRTC zaštita</strong><span>Smanjuje rizik curenja lokalnog IP-a</span></div><span class="toggle on"></span></div>
      <div class="setting"><div><strong>Do Not Track / GPC</strong><span>Šalje privacy preference web-stranicama</span></div><span class="toggle on"></span></div>
      <div class="panel-actions"><button id="clear-data" class="primary-button">Obriši podatke pregledavanja</button></div>
    </aside>
  </main>`;

const tabsEl = document.querySelector<HTMLDivElement>("#tabs")!;
const omnibox = document.querySelector<HTMLInputElement>("#omnibox")!;
const newtab = document.querySelector<HTMLElement>("#newtab")!;
const blockedCount = document.querySelector<HTMLSpanElement>("#blocked-count")!;
const connectionIcon = document.querySelector<HTMLSpanElement>("#connection-icon")!;
const privacyPanel = document.querySelector<HTMLElement>("#privacy-panel")!;
let tabs: TabSnapshot[] = [];
let activeTabId: string | null = null;

const activeTab = () => tabs.find((tab) => tab.id === activeTabId);
const escapeHtml = (value: string) => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;").replaceAll("'", "&#039;");

function renderTabs(): void {
  tabsEl.innerHTML = tabs.map((tab) => {
    const active = tab.id === activeTabId ? " active" : "";
    const loading = tab.loading ? " loading" : "";
    const title = tab.title || "Novi tab";
    return `<button class="tab${active}${loading}" data-tab="${tab.id}" title="${escapeHtml(title)}"><span class="tab-favicon">${tab.loading ? "◌" : "◇"}</span><span class="tab-title">${escapeHtml(title)}</span><span class="tab-close" data-close-tab="${tab.id}">×</span></button>`;
  }).join("");
}

function refreshChrome(): void {
  const tab = activeTab();
  const hasPage = Boolean(tab?.url);
  newtab.classList.toggle("hidden", Boolean(tab?.hasWebview));
  omnibox.value = tab?.url ?? "";
  blockedCount.textContent = String(tab?.blocked ?? 0);
  connectionIcon.textContent = tab?.url?.startsWith("https://") ? "◆" : tab?.url ? "!" : "◈";
  connectionIcon.classList.toggle("insecure", Boolean(tab?.url && !tab.url.startsWith("https://")));
  document.querySelector<HTMLButtonElement>("#back")!.disabled = !hasPage;
  document.querySelector<HTMLButtonElement>("#forward")!.disabled = !hasPage;
  document.querySelector<HTMLButtonElement>("#reload")!.disabled = !hasPage;
  renderTabs();
}

async function createTab(makeActive = true): Promise<void> {
  const tab = await invoke<TabSnapshot>("create_tab");
  tabs.push(tab);
  if (makeActive) {
    activeTabId = tab.id;
    await invoke("set_active_tab", { tabId: tab.id });
  }
  refreshChrome();
  setTimeout(() => omnibox.focus(), 0);
}

function normalizeInput(raw: string): { type: "url" | "search"; value: string } {
  const value = raw.trim();
  if (!value) throw new Error("Prazan unos");
  if (/^https?:\/\//i.test(value)) return { type: "url", value };
  if (/^(localhost|\d{1,3}(?:\.\d{1,3}){3})(:\d+)?(\/.*)?$/i.test(value)) return { type: "url", value: `http://${value}` };
  if (/^[\w.-]+\.[a-z]{2,}(?::\d+)?(?:\/.*)?$/i.test(value)) return { type: "url", value: `https://${value}` };
  return { type: "search", value };
}

async function navigateRaw(raw: string): Promise<void> {
  let tab = activeTab();
  if (!tab) { await createTab(true); tab = activeTab(); }
  if (!tab) return;
  const parsed = normalizeInput(raw);
  const target = parsed.type === "url" ? parsed.value : `https://duckduckgo.com/?q=${encodeURIComponent(parsed.value)}`;
  omnibox.blur();
  await invoke("navigate_tab", { tabId: tab.id, target });
}

async function closeTab(id: string): Promise<void> {
  const index = tabs.findIndex((tab) => tab.id === id);
  if (index < 0) return;
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

async function syncViewport(): Promise<void> {
  const chrome = document.querySelector<HTMLElement>("#browser-chrome")!;
  const height = chrome.getBoundingClientRect().height;
  await invoke("sync_viewport", { x: 0, y: height, width: window.innerWidth, height: Math.max(1, window.innerHeight - height) });
}

document.querySelector("#new-tab")!.addEventListener("click", () => void createTab(true));
document.querySelector<HTMLFormElement>("#omnibox-form")!.addEventListener("submit", (event) => { event.preventDefault(); void navigateRaw(omnibox.value); });
document.querySelector<HTMLFormElement>("#newtab-search")!.addEventListener("submit", (event) => { event.preventDefault(); void navigateRaw(document.querySelector<HTMLInputElement>("#newtab-input")!.value); });

tabsEl.addEventListener("click", async (event) => {
  const target = event.target as HTMLElement;
  const close = target.closest<HTMLElement>("[data-close-tab]");
  if (close) { event.stopPropagation(); await closeTab(close.dataset.closeTab!); return; }
  const tabButton = target.closest<HTMLButtonElement>("[data-tab]");
  if (!tabButton) return;
  activeTabId = tabButton.dataset.tab!;
  await invoke("set_active_tab", { tabId: activeTabId });
  refreshChrome();
});

document.querySelector("#back")!.addEventListener("click", () => activeTabId && void invoke("go_back", { tabId: activeTabId }));
document.querySelector("#forward")!.addEventListener("click", () => activeTabId && void invoke("go_forward", { tabId: activeTabId }));
document.querySelector("#reload")!.addEventListener("click", () => activeTabId && void invoke("reload_tab", { tabId: activeTabId }));
for (const selector of ["#shield", "#privacy"]) document.querySelector(selector)!.addEventListener("click", () => { privacyPanel.classList.add("open"); privacyPanel.setAttribute("aria-hidden", "false"); });
document.querySelector("#close-panel")!.addEventListener("click", () => { privacyPanel.classList.remove("open"); privacyPanel.setAttribute("aria-hidden", "true"); });
document.querySelector("#clear-data")!.addEventListener("click", async () => { await invoke("clear_browsing_data"); blockedCount.textContent = "0"; });
document.querySelector("#minimize")!.addEventListener("click", () => void appWindow.minimize());
document.querySelector("#maximize")!.addEventListener("click", () => void appWindow.toggleMaximize());
document.querySelector("#close-window")!.addEventListener("click", () => void appWindow.close());
document.querySelector<HTMLElement>("#drag-region")!.addEventListener("pointerdown", (event: PointerEvent) => { if ((event.target as HTMLElement).closest(".no-drag, button, input")) return; if (event.button === 0) void appWindow.startDragging(); });
document.querySelector<HTMLElement>("#drag-region")!.addEventListener("dblclick", (event: MouseEvent) => { if ((event.target as HTMLElement).closest("button, input")) return; void appWindow.toggleMaximize(); });
window.addEventListener("resize", () => void syncViewport());
window.addEventListener("keydown", (event) => {
  if (event.ctrlKey && event.key.toLowerCase() === "l") { event.preventDefault(); omnibox.focus(); omnibox.select(); }
  else if (event.ctrlKey && event.key.toLowerCase() === "t") { event.preventDefault(); void createTab(true); }
  else if (event.ctrlKey && event.key.toLowerCase() === "w" && activeTabId) { event.preventDefault(); void closeTab(activeTabId); }
  else if (event.key === "F5" && activeTabId) { event.preventDefault(); void invoke("reload_tab", { tabId: activeTabId }); }
});

await listen<TabEvent>("ghost://tab-event", (event) => {
  const update = event.payload;
  const tab = tabs.find((item) => item.id === update.id);
  if (!tab) return;
  if (update.title !== undefined) tab.title = update.title || "Novi tab";
  if (update.url !== undefined) tab.url = update.url;
  if (update.loading !== undefined) tab.loading = update.loading;
  if (update.blocked !== undefined) tab.blocked = update.blocked;
  tab.hasWebview = true;
  if (tab.id === activeTabId) refreshChrome(); else renderTabs();
});

await syncViewport();
await createTab(true);
