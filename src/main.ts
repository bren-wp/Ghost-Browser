import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { reapplyRendererOverlay, setRendererOverlay } from "./overlay";

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

interface OmniboxSuggestion {
  title: string;
  url: string;
  kind: "bookmark" | "history";
}

interface SuggestionChoice {
  title: string;
  value: string;
  kind: "input" | "tab" | "bookmark" | "history";
  detail: string;
  tabId?: string;
}

interface SuggestionState {
  input: HTMLInputElement;
  box: HTMLElement;
  items: SuggestionChoice[];
  selected: number;
  requestId: number;
  timer: number | undefined;
  clearAfterNavigate: boolean;
}

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
                 maxlength="8192" aria-label="Adresa i pretraživanje" aria-autocomplete="list"
                 aria-controls="omnibox-suggestions" aria-expanded="false"
                 placeholder="Pretraži web ili upiši web-adresu" />
          <button type="button" id="shield" class="shield" title="Ghost zaštita" aria-label="Ghost zaštita">
            <span class="shield-icon">◆</span><span id="blocked-count">0</span>
          </button>
          <div id="omnibox-suggestions" class="omnibox-suggestions" role="listbox" aria-label="Prijedlozi pretraživanja"></div>
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
        <form id="newtab-search" class="newtab-search suggestion-host" autocomplete="off">
          <span aria-hidden="true">⌕</span>
          <input id="newtab-input" type="text" maxlength="8192"
                 placeholder="Pretraži web ili upiši adresu" spellcheck="false" autocomplete="off"
                 aria-label="Pretraživanje ili web-adresa" aria-autocomplete="list"
                 aria-controls="newtab-suggestions" aria-expanded="false" />
          <div id="newtab-suggestions" class="omnibox-suggestions newtab-suggestions" role="listbox" aria-label="Prijedlozi pretraživanja"></div>
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
      <div class="setting"><div><strong>Dozvole web-stranice</strong><span>Kamera, mikrofon i lokacija traže dopuštenje nakon vaše radnje; Ghost odluku ne sprema trajno</span></div><span class="status-badge">Na zahtjev</span></div>
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
const omniboxSuggestionBox = document.querySelector<HTMLElement>("#omnibox-suggestions")!;
const newtabSuggestionBox = document.querySelector<HTMLElement>("#newtab-suggestions")!;
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
let memoryRefreshTimer: number | undefined;
let viewportFrame: number | null = null;

const omniboxSuggestionState: SuggestionState = {
  input: omnibox,
  box: omniboxSuggestionBox,
  items: [],
  selected: -1,
  requestId: 0,
  timer: undefined,
  clearAfterNavigate: false,
};

const newtabSuggestionState: SuggestionState = {
  input: newtabInput,
  box: newtabSuggestionBox,
  items: [],
  selected: -1,
  requestId: 0,
  timer: undefined,
  clearAfterNavigate: true,
};

const suggestionStates = [omniboxSuggestionState, newtabSuggestionState];
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

function syncSuggestionOverlay(): void {
  const open = suggestionStates.some((state) => state.box.classList.contains("open"));
  void safeAction(() => setRendererOverlay("suggestions", open));
}

function hideSuggestions(state?: SuggestionState): void {
  const states = state ? [state] : suggestionStates;
  for (const item of states) {
    if (item.timer !== undefined) {
      window.clearTimeout(item.timer);
      item.timer = undefined;
    }
    item.requestId += 1;
    item.items = [];
    item.selected = -1;
    item.box.innerHTML = "";
    item.box.classList.remove("open");
    item.input.setAttribute("aria-expanded", "false");
    item.input.removeAttribute("aria-activedescendant");
  }
  syncSuggestionOverlay();
}

function suggestionLabel(kind: SuggestionChoice["kind"]): string {
  if (kind === "tab") return "Prebaci na tab";
  if (kind === "bookmark") return "Favorit";
  if (kind === "history") return "Povijest";
  return "Pretraži ili otvori";
}

function renderSuggestions(state: SuggestionState): void {
  if (state.items.length === 0 || document.activeElement !== state.input) {
    state.box.innerHTML = "";
    state.box.classList.remove("open");
    state.input.setAttribute("aria-expanded", "false");
    state.input.removeAttribute("aria-activedescendant");
    syncSuggestionOverlay();
    return;
  }

  state.box.innerHTML = state.items.map((item, index) => {
    const selected = index === state.selected;
    const id = `${state.box.id}-item-${index}`;
    const glyph = item.kind === "tab" ? "▣" : item.kind === "bookmark" ? "★" : item.kind === "history" ? "↻" : "⌕";
    return `<button type="button" id="${id}" class="omnibox-suggestion${selected ? " selected" : ""}" role="option" aria-selected="${selected}" data-suggestion-index="${index}">
      <span class="suggestion-glyph" aria-hidden="true">${glyph}</span>
      <span class="suggestion-copy"><strong>${escapeHtml(item.title)}</strong><small>${escapeHtml(item.detail)}</small></span>
      <span class="suggestion-kind">${suggestionLabel(item.kind)}</span>
    </button>`;
  }).join("");

  state.box.classList.add("open");
  state.input.setAttribute("aria-expanded", "true");
  if (state.selected >= 0) {
    state.input.setAttribute("aria-activedescendant", `${state.box.id}-item-${state.selected}`);
  } else {
    state.input.removeAttribute("aria-activedescendant");
  }
  syncSuggestionOverlay();
}

function buildSuggestionChoices(raw: string, local: OmniboxSuggestion[]): SuggestionChoice[] {
  const value = raw.trim();
  if (!value) return [];

  const choices: SuggestionChoice[] = [{
    title: value,
    value,
    kind: "input",
    detail: "Pretraživanje ili izravna web-adresa",
  }];

  const needle = value.toLocaleLowerCase("hr-HR");
  let tabMatches = 0;
  for (const tab of tabs) {
    if (tab.id === activeTabId || !tab.url || tabMatches >= 3) continue;
    const title = tab.title || tab.url;
    if (!title.toLocaleLowerCase("hr-HR").includes(needle)
        && !tab.url.toLocaleLowerCase("hr-HR").includes(needle)) {
      continue;
    }
    choices.push({
      title,
      value: tab.url,
      kind: "tab",
      detail: tab.url,
      tabId: tab.id,
    });
    tabMatches += 1;
  }

  for (const item of local) {
    if (choices.some((choice) => choice.value === item.url && choice.kind !== "input")) continue;
    choices.push({
      title: item.title || item.url,
      value: item.url,
      kind: item.kind,
      detail: item.url,
    });
  }
  return choices.slice(0, 9);
}

function scheduleSuggestions(state: SuggestionState, delay = 55): void {
  if (state.timer !== undefined) window.clearTimeout(state.timer);
  const raw = state.input.value.trim();
  if (!raw) {
    hideSuggestions(state);
    return;
  }

  const requestId = ++state.requestId;
  state.timer = window.setTimeout(() => {
    state.timer = undefined;
    void safeAction(async () => {
      const local = await invoke<OmniboxSuggestion[]>("omnibox_suggestions", { input: raw });
      if (requestId !== state.requestId || state.input.value.trim() !== raw) return;
      state.items = buildSuggestionChoices(raw, local);
      state.selected = -1;
      renderSuggestions(state);
    });
  }, delay);
}

async function chooseSuggestion(state: SuggestionState, index: number): Promise<void> {
  const choice = state.items[index];
  if (!choice) return;
  hideSuggestions();

  if (choice.kind === "tab" && choice.tabId) {
    await activateTab(choice.tabId);
    return;
  }

  await navigateRaw(choice.value);
  if (state.clearAfterNavigate) state.input.value = "";
}

function moveSuggestionSelection(state: SuggestionState, direction: 1 | -1): void {
  if (state.items.length === 0) {
    scheduleSuggestions(state, 0);
    return;
  }
  const next = state.selected < 0
    ? (direction > 0 ? 0 : state.items.length - 1)
    : (state.selected + direction + state.items.length) % state.items.length;
  state.selected = next;
  renderSuggestions(state);
}

function attachSuggestionInteractions(state: SuggestionState): void {
  state.input.addEventListener("input", () => scheduleSuggestions(state));
  state.input.addEventListener("focus", () => scheduleSuggestions(state, 0));
  state.input.addEventListener("blur", () => {
    window.setTimeout(() => {
      if (!state.box.contains(document.activeElement)) hideSuggestions(state);
    }, 100);
  });
  state.input.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      moveSuggestionSelection(state, 1);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      moveSuggestionSelection(state, -1);
    } else if (event.key === "Enter" && state.selected >= 0) {
      event.preventDefault();
      void safeAction(() => chooseSuggestion(state, state.selected));
    } else if (event.key === "Escape" && state.box.classList.contains("open")) {
      event.preventDefault();
      event.stopPropagation();
      hideSuggestions(state);
    }
  });

  state.box.addEventListener("pointerdown", (event) => event.preventDefault());
  state.box.addEventListener("click", (event) => {
    const target = (event.target as HTMLElement).closest<HTMLElement>("[data-suggestion-index]");
    if (!target?.dataset.suggestionIndex) return;
    const index = Number(target.dataset.suggestionIndex);
    if (!Number.isInteger(index)) return;
    void safeAction(() => chooseSuggestion(state, index));
  });
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

function scheduleMemoryStatusRefresh(delay = 100): void {
  if (memoryRefreshTimer !== undefined) window.clearTimeout(memoryRefreshTimer);
  memoryRefreshTimer = window.setTimeout(() => {
    memoryRefreshTimer = undefined;
    void safeAction(refreshMemoryStatus);
  }, delay);
}

function refreshChrome(): void {
  const tab = activeTab();
  const hasPage = Boolean(tab?.url);
  newtab.classList.toggle("hidden", Boolean(tab?.hasWebview || tab?.url));

  if (document.activeElement !== omnibox) {
    omnibox.value = tab?.url ?? "";
  }

  blockedCount.textContent = String(tab?.blocked ?? 0);
  connectionIcon.textContent = tab?.url?.startsWith("https://") ? "◆" : tab?.url ? "!" : "◈";
  connectionIcon.classList.toggle("insecure", Boolean(tab?.url && !tab.url.startsWith("https://")));
  document.querySelector<HTMLButtonElement>("#back")!.disabled = !hasPage;
  document.querySelector<HTMLButtonElement>("#forward")!.disabled = !hasPage;
  document.querySelector<HTMLButtonElement>("#reload")!.disabled = !hasPage;
  renderTabs();
}

async function setOverlay(open: boolean): Promise<void> {
  await setRendererOverlay("chrome", open);
}

async function closeOverlays(): Promise<void> {
  hideSuggestions();
  privacyPanel.classList.remove("open");
  privacyPanel.setAttribute("aria-hidden", "true");
  appMenu.classList.remove("open");
  appMenu.setAttribute("aria-hidden", "true");
  menuButton.setAttribute("aria-expanded", "false");
  await setOverlay(false);
}

async function openPrivacyPanel(): Promise<void> {
  hideSuggestions();
  appMenu.classList.remove("open");
  appMenu.setAttribute("aria-hidden", "true");
  menuButton.setAttribute("aria-expanded", "false");
  privacyPanel.classList.add("open");
  privacyPanel.setAttribute("aria-hidden", "false");
  await setOverlay(true);
}

async function toggleMenu(): Promise<void> {
  hideSuggestions();
  const opening = !appMenu.classList.contains("open");
  privacyPanel.classList.remove("open");
  privacyPanel.setAttribute("aria-hidden", "true");
  appMenu.classList.toggle("open", opening);
  appMenu.setAttribute("aria-hidden", String(!opening));
  menuButton.setAttribute("aria-expanded", String(opening));
  await setOverlay(opening);
  if (opening) await refreshMemoryStatus();
}

async function createTab(makeActive = true): Promise<TabSnapshot> {
  const tab = await invoke<TabSnapshot>("create_tab");
  tabs.push(tab);

  if (makeActive) {
    try {
      await invoke("set_active_tab", { tabId: tab.id });
      activeTabId = tab.id;
      await reapplyRendererOverlay();
    } catch (error) {
      tabs = tabs.filter((item) => item.id !== tab.id);
      await invoke("close_tab", { tabId: tab.id }).catch(() => undefined);
      throw error;
    }
  }

  refreshChrome();
  scheduleMemoryStatusRefresh();
  if (makeActive) window.setTimeout(() => omnibox.focus(), 0);
  return tab;
}

async function activateTab(tabId: string): Promise<void> {
  if (!tabs.some((tab) => tab.id === tabId)) return;
  await closeOverlays();
  await invoke("set_active_tab", { tabId });
  activeTabId = tabId;
  await reapplyRendererOverlay();

  const tab = activeTab();
  if (tab?.url) {
    tab.hasWebview = true;
    tab.discarded = false;
  }

  refreshChrome();
  scheduleMemoryStatusRefresh();
}

async function cycleTab(direction: 1 | -1): Promise<void> {
  if (tabs.length < 2) return;
  const current = Math.max(0, tabs.findIndex((tab) => tab.id === activeTabId));
  const next = (current + direction + tabs.length) % tabs.length;
  const target = tabs[next];
  if (target) await activateTab(target.id);
}

async function activateNumberedTab(number: number): Promise<void> {
  if (tabs.length === 0) return;
  const index = number === 9 ? tabs.length - 1 : number - 1;
  const target = tabs[index];
  if (target) await activateTab(target.id);
}

async function resolveTarget(raw: string): Promise<string> {
  return invoke<string>("resolve_omnibox_input", { input: raw });
}

async function navigateTab(tabId: string, raw: string): Promise<void> {
  const target = await resolveTarget(raw);
  const tab = tabs.find((item) => item.id === tabId);
  const previous = tab
    ? { url: tab.url, loading: tab.loading, hasWebview: tab.hasWebview, discarded: tab.discarded }
    : null;

  hideSuggestions();
  omnibox.blur();
  if (tab) {
    tab.url = target;
    tab.loading = true;
    tab.discarded = false;
    refreshChrome();
  }

  try {
    await invoke("navigate_tab", { tabId, target });
    if (tab) tab.hasWebview = true;
  } catch (error) {
    if (tab && previous) {
      tab.url = previous.url;
      tab.loading = previous.loading;
      tab.hasWebview = previous.hasWebview;
      tab.discarded = previous.discarded;
      refreshChrome();
    }
    throw error;
  }
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
  if (!closing) return;

  await invoke("close_tab", { tabId: id });
  closedTabs.push({ title: closing.title, url: closing.url });
  if (closedTabs.length > MAX_CLOSED_TABS) closedTabs.shift();
  tabs.splice(index, 1);

  if (activeTabId === id) {
    const next = tabs[Math.min(index, tabs.length - 1)];
    if (next) {
      await invoke("set_active_tab", { tabId: next.id });
      activeTabId = next.id;
      await reapplyRendererOverlay();
    } else {
      activeTabId = null;
    }
  }

  if (tabs.length === 0) await createTab(true);
  refreshChrome();
  scheduleMemoryStatusRefresh();
}

async function reopenClosedTab(): Promise<void> {
  const closed = closedTabs.pop();
  if (!closed) return;
  const tab = await createTab(true);
  if (closed.url) await navigateTab(tab.id, closed.url);
  scheduleMemoryStatusRefresh();
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
  showToast(discarded > 0
    ? `Oslobođena je memorija ${discarded} neaktivnih tabova.`
    : "Nema neaktivnih tabova za oslobađanje.");
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

function scheduleViewportSync(): void {
  if (viewportFrame !== null) return;
  viewportFrame = window.requestAnimationFrame(() => {
    viewportFrame = null;
    void safeAction(syncViewport);
  });
}

attachSuggestionInteractions(omniboxSuggestionState);
attachSuggestionInteractions(newtabSuggestionState);

document.querySelector("#new-tab")!.addEventListener("click", () => void safeAction(async () => {
  await closeOverlays();
  await createTab(true);
}));

document.querySelector<HTMLFormElement>("#omnibox-form")!.addEventListener("submit", (event) => {
  event.preventDefault();
  const value = omnibox.value;
  hideSuggestions();
  void safeAction(() => navigateRaw(value));
});

document.querySelector<HTMLFormElement>("#newtab-search")!.addEventListener("submit", (event) => {
  event.preventDefault();
  const value = newtabInput.value;
  hideSuggestions();
  void safeAction(async () => {
    await navigateRaw(value);
    newtabInput.value = "";
  });
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
    if (tabButton?.dataset.tab) await activateTab(tabButton.dataset.tab);
  });
});

tabsEl.addEventListener("auxclick", (event) => {
  if (event.button !== 1) return;
  const target = event.target as HTMLElement;
  const tabButton = target.closest<HTMLButtonElement>("[data-tab]");
  if (!tabButton?.dataset.tab) return;
  event.preventDefault();
  void safeAction(() => closeTab(tabButton.dataset.tab!));
});

tabsEl.addEventListener("wheel", (event) => {
  if (tabsEl.scrollWidth <= tabsEl.clientWidth) return;
  if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return;
  tabsEl.scrollLeft += event.deltaY;
  event.preventDefault();
}, { passive: false });

document.querySelector("#back")!.addEventListener("click", () => {
  if (activeTabId) void safeAction(() => invoke("go_back", { tabId: activeTabId! }));
});

document.querySelector("#forward")!.addEventListener("click", () => {
  if (activeTabId) void safeAction(() => invoke("go_forward", { tabId: activeTabId! }));
});

document.querySelector("#reload")!.addEventListener("click", () => {
  if (activeTabId) void safeAction(() => invoke("reload_tab", { tabId: activeTabId! }));
});

for (const selector of ["#shield", "#privacy"]) {
  document.querySelector(selector)!.addEventListener("click", () => void safeAction(openPrivacyPanel));
}

document.querySelector("#close-panel")!.addEventListener("click", () => void safeAction(closeOverlays));
document.querySelector("#clear-data")!.addEventListener("click", () => void safeAction(clearBrowsingData));
menuButton.addEventListener("click", () => void safeAction(toggleMenu));
document.querySelector("#menu-new-tab")!.addEventListener("click", () => void safeAction(async () => {
  await closeOverlays();
  await createTab(true);
}));
document.querySelector("#menu-reopen-tab")!.addEventListener("click", () => void safeAction(async () => {
  await closeOverlays();
  await reopenClosedTab();
}));
document.querySelector("#menu-memory-saver")!.addEventListener("click", () => void safeAction(async () => {
  await freeInactiveMemory();
  await closeOverlays();
}));
document.querySelector("#menu-clear-data")!.addEventListener("click", () => void safeAction(async () => {
  await clearBrowsingData();
  await closeOverlays();
}));

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

window.addEventListener("resize", scheduleViewportSync);
window.addEventListener("keydown", (event) => {
  const key = event.key.toLowerCase();

  if (event.ctrlKey && !event.altKey && key === "l") {
    event.preventDefault();
    void safeAction(closeOverlays);
    omnibox.focus();
    omnibox.select();
    scheduleSuggestions(omniboxSuggestionState, 0);
  } else if (event.ctrlKey && event.shiftKey && key === "t") {
    event.preventDefault();
    void safeAction(reopenClosedTab);
  } else if (event.ctrlKey && !event.shiftKey && key === "t") {
    event.preventDefault();
    void safeAction(async () => {
      await closeOverlays();
      await createTab(true);
    });
  } else if (event.ctrlKey && key === "w" && activeTabId) {
    event.preventDefault();
    void safeAction(() => closeTab(activeTabId!));
  } else if (event.ctrlKey && event.shiftKey && event.key === "Delete") {
    event.preventDefault();
    void safeAction(clearBrowsingData);
  } else if (event.ctrlKey && key === "r" && activeTabId) {
    event.preventDefault();
    void safeAction(() => invoke("reload_tab", { tabId: activeTabId! }));
  } else if (event.ctrlKey && event.key === "Tab") {
    event.preventDefault();
    void safeAction(() => cycleTab(event.shiftKey ? -1 : 1));
  } else if (event.ctrlKey && /^[1-9]$/.test(event.key)) {
    event.preventDefault();
    void safeAction(() => activateNumberedTab(Number(event.key)));
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
    hideSuggestions();
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
  else renderTabs();
  scheduleMemoryStatusRefresh();
});

await listen<PopupNavigation>("ghost://open-current-tab", (event) => {
  const payload = event.payload;
  if (!payload?.tabId || !payload?.url) return;
  if (!tabs.some((tab) => tab.id === payload.tabId)) return;
  void safeAction(() => navigateTab(payload.tabId, payload.url));
});

await listen<{ url?: string }>("ghost://download", () => {
  showToast("Preuzimanje je pokrenuto.");
});

await safeAction(syncViewport);
await safeAction(async () => {
  await createTab(true);
});
