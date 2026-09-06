/**
 * Presentation-only Ghosium website alignment.
 * No navigation, storage, privacy, Tauri IPC or browser-core behavior is changed here.
 */
function enhanceGhosiumWebsiteBrand(): boolean {
  const newtabInner = document.querySelector<HTMLElement>(".newtab-inner");
  if (!newtabInner) return false;
  if (newtabInner.dataset.websiteBrand === "true") return true;

  newtabInner.dataset.websiteBrand = "true";

  const eyebrow = newtabInner.querySelector<HTMLElement>(".newtab-eyebrow");
  const title = newtabInner.querySelector<HTMLHeadingElement>("h1");
  const subtitle = newtabInner.querySelector<HTMLParagraphElement>(".newtab-subtitle");
  const search = newtabInner.querySelector<HTMLFormElement>("#newtab-search");
  const cards = newtabInner.querySelector<HTMLElement>(".privacy-cards");

  if (eyebrow) eyebrow.textContent = "PRIVATE BY DESIGN";

  if (title) {
    title.innerHTML = 'Browse the web,<br>stay <span class="ghosium-gradient">unseen.</span>';
  }

  if (subtitle) {
    subtitle.textContent =
      "Ghosium je brz preglednik usmjeren na privatnost — manje praćenja, manje nepotrebnog šuma i više kontrole nad podacima koji ostaju na vašem uređaju.";
  }

  if (search && !newtabInner.querySelector(".ghosium-product-row")) {
    const products = document.createElement("div");
    products.className = "ghosium-product-row";
    products.setAttribute("aria-label", "Ghosium značajke");

    const items = [
      ["Ghosium Shield", "trackeri"],
      ["Ghosium Guard", "dozvole"],
      ["Ghosium Search", "pretraživanje"],
      ["Password Manager", "vault"],
      ["Memory Saver", "memorija"],
    ] as const;

    for (const [name, description] of items) {
      const pill = document.createElement("span");
      pill.className = "ghosium-product-pill";
      const strong = document.createElement("strong");
      strong.textContent = name;
      pill.append(strong, document.createTextNode(` · ${description}`));
      products.append(pill);
    }

    search.insertAdjacentElement("afterend", products);
  }

  if (cards) {
    const items = [
      {
        kicker: "● Aktivno",
        title: "Ghosium Shield",
        body: "Poznati trackeri i oglasni zahtjevi blokiraju se prije nego što dođu do stranice.",
      },
      {
        kicker: "● Kontrola",
        title: "Ghosium Guard",
        body: "Kamera, mikrofon i lokacija ostaju pod vašom kontrolom i traže se tek kada su potrebni.",
      },
      {
        kicker: "● Pametno",
        title: "Memory Saver",
        body: "Neaktivni tabovi oslobađaju resurse i vraćaju se kada ih ponovno otvorite.",
      },
    ] as const;

    cards.replaceChildren(
      ...items.map((item) => {
        const article = document.createElement("article");
        const kicker = document.createElement("span");
        const strong = document.createElement("strong");
        const body = document.createElement("span");
        kicker.className = "card-kicker";
        kicker.textContent = item.kicker;
        strong.textContent = item.title;
        body.textContent = item.body;
        article.append(kicker, strong, body);
        return article;
      }),
    );
  }

  const privacyHeader = document.querySelector<HTMLElement>("#privacy-panel .panel-header");
  const privacyEyebrow = privacyHeader?.querySelector<HTMLElement>("small");
  const privacyTitle = privacyHeader?.querySelector<HTMLHeadingElement>("h2");
  if (privacyEyebrow) privacyEyebrow.textContent = "GHOSIUM SHIELD";
  if (privacyTitle) privacyTitle.textContent = "Privacy control";

  return true;
}

if (!enhanceGhosiumWebsiteBrand()) {
  const observer = new MutationObserver(() => {
    if (enhanceGhosiumWebsiteBrand()) observer.disconnect();
  });
  observer.observe(document.documentElement, { childList: true, subtree: true });
  window.addEventListener("DOMContentLoaded", () => enhanceGhosiumWebsiteBrand(), { once: true });
}
