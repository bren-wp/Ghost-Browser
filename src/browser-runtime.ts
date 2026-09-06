function browserTabs(): HTMLButtonElement[] {
  return Array.from(document.querySelectorAll<HTMLButtonElement>("#tabs .tab[data-tab]"));
}

function activeTabIndex(tabs: HTMLButtonElement[]): number {
  const active = tabs.findIndex((tab) => tab.classList.contains("active"));
  return active >= 0 ? active : 0;
}

function activateTabByIndex(index: number): void {
  const tabs = browserTabs();
  if (tabs.length === 0) return;
  const normalized = ((index % tabs.length) + tabs.length) % tabs.length;
  tabs[normalized]?.click();
}

function updatePermissionCopy(): void {
  const settings = Array.from(document.querySelectorAll<HTMLElement>("#privacy-panel .setting"));
  const permissionSetting = settings.find((setting) =>
    setting.querySelector("strong")?.textContent?.includes("WebRTC"),
  );
  if (!permissionSetting) return;

  const title = permissionSetting.querySelector("strong");
  const description = permissionSetting.querySelector<HTMLSpanElement>("div > span");
  const badge = permissionSetting.querySelector<HTMLElement>(".status-badge");

  if (title) title.textContent = "Dozvole web-stranice";
  if (description) {
    description.textContent = "Kamera, mikrofon i lokacija traže potvrdu nakon vaše radnje";
  }
  if (badge) badge.textContent = "Na zahtjev";
}

function installTabMouseControls(): void {
  const tabs = document.querySelector<HTMLElement>("#tabs");
  if (!tabs) return;

  tabs.addEventListener("auxclick", (event) => {
    if (event.button !== 1) return;
    const target = event.target as HTMLElement;
    const tab = target.closest<HTMLElement>(".tab[data-tab]");
    if (!tab) return;
    event.preventDefault();
    tab.querySelector<HTMLElement>("[data-close-tab]")?.click();
  });

  tabs.addEventListener(
    "wheel",
    (event) => {
      if (Math.abs(event.deltaY) <= Math.abs(event.deltaX)) return;
      if (tabs.scrollWidth <= tabs.clientWidth) return;
      event.preventDefault();
      tabs.scrollLeft += event.deltaY;
    },
    { passive: false },
  );
}

function installKeyboardControls(): void {
  window.addEventListener("keydown", (event) => {
    const key = event.key.toLowerCase();

    if (event.ctrlKey && !event.altKey && key === "r") {
      event.preventDefault();
      document.querySelector<HTMLButtonElement>("#reload")?.click();
      return;
    }

    if (event.ctrlKey && key === "tab") {
      event.preventDefault();
      const tabs = browserTabs();
      if (tabs.length === 0) return;
      const direction = event.shiftKey ? -1 : 1;
      activateTabByIndex(activeTabIndex(tabs) + direction);
      return;
    }

    if (event.ctrlKey && !event.altKey && !event.shiftKey && /^[1-9]$/.test(event.key)) {
      event.preventDefault();
      const tabs = browserTabs();
      if (tabs.length === 0) return;
      const requested = Number(event.key);
      const index = requested === 9 ? tabs.length - 1 : Math.min(requested - 1, tabs.length - 1);
      activateTabByIndex(index);
    }
  });
}

function initialize(): void {
  updatePermissionCopy();
  installTabMouseControls();
  installKeyboardControls();
}

if (document.readyState === "complete") {
  initialize();
} else {
  window.addEventListener("load", initialize, { once: true });
}
