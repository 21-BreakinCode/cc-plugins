// cc-plugins site — fetches generated plugins.json and renders the landing index
// + per-plugin subpage. No framework, no build step. `*Html` fields are pre-rendered
// and escaped by scripts/lib/markdown.mjs, so they are inserted as-is.

const CATEGORY_LABEL = {
  en: { memory: "Memory", improve: "Improve", review: "Review", workflow: "Workflow", media: "Media", content: "Content" },
  "zh-TW": { memory: "記憶", improve: "改進", review: "審查", workflow: "工作流程", media: "媒體", content: "內容" },
};

// Strings app.js builds itself. t() fills `{name}` placeholders; callers escape
// any value that lands inside HTML.
const UI_TEXT = {
  en: {
    "lang.toggle": "中文",
    "lang.toggleAria": "Switch to Chinese",
    "title.home": "21-breakincode — plugins for Claude Code",
    copy: "Copy",
    copied: "Copied",
    "copy.install": "Copy install command",
    "copy.installFor": "Copy install command for {name}",
    "filter.all": "All",
    "filter.aria": "Filter plugins by category",
    "section.install": "Install",
    "section.commands": "Commands",
    "section.skills": "Skills — activate automatically",
    "section.config": "Configuration",
    "config.variable": "Variable",
    "config.default": "Default",
    "config.description": "Description",
    "section.deps": "Depends on",
    "deps.external": "external",
    "section.changelog": "Changelog",
    "notFound.title": "Not found",
    "notFound.body": "No plugin named “{name}”.",
    "notFound.back": "Back to all plugins →",
    loadError: "Could not load plugin data ({error}). Serve over HTTP — try <code>./scripts/cicd.sh serve</code>.",
  },
  "zh-TW": {
    "lang.toggle": "EN",
    "lang.toggleAria": "切換為英文",
    "title.home": "21-breakincode：Claude Code 外掛",
    copy: "複製",
    copied: "已複製",
    "copy.install": "複製安裝指令",
    "copy.installFor": "複製 {name} 的安裝指令",
    "filter.all": "全部",
    "filter.aria": "依類別篩選外掛",
    "section.install": "安裝",
    "section.commands": "指令",
    "section.skills": "Skill（自動啟用）",
    "section.config": "設定",
    "config.variable": "變數",
    "config.default": "預設值",
    "config.description": "說明",
    "section.deps": "相依外掛",
    "deps.external": "外部",
    "section.changelog": "更新紀錄",
    "notFound.title": "找不到外掛",
    "notFound.body": "沒有名為「{name}」的外掛。",
    "notFound.back": "回到所有外掛 →",
    loadError: "無法載入外掛資料（{error}）。請透過 HTTP 提供網站，例如執行 <code>./scripts/cicd.sh serve</code>。",
  },
};

// zh-TW text for static markup marked `data-i18n` / `data-i18n-aria`. The English
// stays in the HTML itself. `{count}` is the live plugin count.
const STATIC_TEXT_ZH_TW = {
  "nav.plugins": "外掛",
  "nav.catalog": "目錄",
  "nav.portfolio": "作品集 ↗",
  "hero.eyebrow": "Claude Code 外掛市集",
  "hero.title": '<span id="count-head">{count}</span> 個專注的外掛，<span class="accent">一行指令</span>全部裝好。',
  "hero.sub": "Obsidian 筆記庫記憶與交接筆記、以評測驅動的改進循環、PR 審查、主張稽核，以及寫作工具。每個外掛只做一件事。",
  "hero.installAll": '一次安裝全部 <span id="count-cta">{count}</span> 個',
  "tabs.aria": "安裝或更新方式",
  "tab.update": "更新",
  copy: "複製",
  "copy.command": "複製指令",
  "plugins.title": "外掛列表",
  "plugins.sub": "依用途篩選外掛。",
  "back.all": "← 所有外掛",
  loading: "載入中…",
  "footer.note": "MIT · 21-breakincode 外掛市集",
};

const PORTFOLIO_URL = { en: "https://21-breakincode.com/en/", "zh-TW": "https://21-breakincode.com/zh-TW/" };
const LANG_STORAGE_KEY = "lang";
const SUPPORTED_LANGS = ["en", "zh-TW"];

const reduceMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const currentLang = () => (document.documentElement.lang === "zh-TW" ? "zh-TW" : "en");
const categoryLabel = (id) => CATEGORY_LABEL[currentLang()][id] || CATEGORY_LABEL.en[id] || id;
const localized = (plugin, field) => (currentLang() === "zh-TW" && plugin.zhTW?.[field]) || plugin[field];

function t(key, vars = {}) {
  const template = UI_TEXT[currentLang()][key] ?? UI_TEXT.en[key] ?? key;
  return template.replace(/\{(\w+)\}/g, (_match, name) => vars[name] ?? "");
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function highlightCli(text) {
  let h = escapeHtml(text);
  h = h.replace(/(@[\w-]+)/g, '<span class="flag">$1</span>');
  h = h.replace(/(&amp;&amp;|\\)/g, '<span class="comment">$1</span>');
  h = h.replace(/\bclaude\b/g, '<span class="key">claude</span>');
  return `<span class="prompt">$</span> ${h}`;
}

function highlightJson(jsonText) {
  let h = escapeHtml(jsonText);
  h = h.replace(/&quot;([^&]+?)&quot;(\s*:)/g, '<span class="key">&quot;$1&quot;</span>$2');
  h = h.replace(/\b(true|false)\b/g, '<span class="flag">$1</span>');
  return h;
}

async function copyText(text, btn) {
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const ta = document.createElement("textarea");
    ta.value = text;
    document.body.appendChild(ta);
    ta.select();
    document.execCommand("copy");
    ta.remove();
  }
  if (!btn) return;
  const original = btn.textContent;
  btn.classList.add("is-copied");
  btn.textContent = t("copied");
  setTimeout(() => {
    btn.classList.remove("is-copied");
    btn.textContent = original;
  }, 1600);
}

function revealAll() {
  document.querySelectorAll("[data-reveal]").forEach((el) => el.classList.add("is-visible"));
}

function initReveal() {
  const els = document.querySelectorAll("[data-reveal]");
  if (!("IntersectionObserver" in window)) {
    revealAll();
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add("is-visible");
          io.unobserve(e.target);
        }
      });
    },
    { threshold: 0.1, rootMargin: "0px 0px -40px 0px" },
  );
  els.forEach((el) => io.observe(el));
}

/* -------------------------------- Language -------------------------------- */
function readSavedLang() {
  try {
    return localStorage.getItem(LANG_STORAGE_KEY);
  } catch {
    return null; // storage blocked (private mode): fall back to the browser language
  }
}

function saveLang(lang) {
  try {
    localStorage.setItem(LANG_STORAGE_KEY, lang);
  } catch {
    // storage blocked: the choice lasts until the page reloads
  }
}

function initialLang() {
  const saved = readSavedLang();
  if (SUPPORTED_LANGS.includes(saved)) return saved;
  return (navigator.language || "").toLowerCase().startsWith("zh") ? "zh-TW" : "en";
}

// First-seen English markup per element, so switching back restores it exactly.
const englishStaticText = new Map();
const englishStaticAria = new Map();

function applyStaticText(lang) {
  const count = document.getElementById("count-head")?.textContent ?? "";
  document.querySelectorAll("[data-i18n]").forEach((el) => {
    if (!englishStaticText.has(el)) englishStaticText.set(el, el.innerHTML);
    const zh = STATIC_TEXT_ZH_TW[el.dataset.i18n];
    el.innerHTML = lang === "zh-TW" && zh ? zh.replaceAll("{count}", count) : englishStaticText.get(el);
  });
  document.querySelectorAll("[data-i18n-aria]").forEach((el) => {
    if (!englishStaticAria.has(el)) englishStaticAria.set(el, el.getAttribute("aria-label"));
    const zh = STATIC_TEXT_ZH_TW[el.dataset.i18nAria];
    el.setAttribute("aria-label", lang === "zh-TW" && zh ? zh : englishStaticAria.get(el));
  });
}

function applyLang(lang) {
  document.documentElement.lang = lang;
  applyStaticText(lang);
  document.querySelectorAll("[data-lang-toggle]").forEach((btn) => {
    btn.textContent = t("lang.toggle");
    btn.lang = lang === "zh-TW" ? "en" : "zh-TW";
    btn.setAttribute("aria-label", t("lang.toggleAria"));
  });
  document.querySelectorAll("[data-portfolio-link]").forEach((link) => {
    link.href = PORTFOLIO_URL[lang];
  });
  if (document.body.dataset.page === "home") document.title = t("title.home");
}

function bindLangToggle() {
  document.querySelectorAll("[data-lang-toggle]").forEach((btn) => {
    btn.addEventListener("click", () => {
      const nextLang = currentLang() === "zh-TW" ? "en" : "zh-TW";
      saveLang(nextLang);
      applyLang(nextLang);
      document.dispatchEvent(new CustomEvent("langchange"));
    });
  });
}

/* ---------------------------------- Hero ---------------------------------- */
function initHeroEntrance() {
  const sequence = [
    [".hero h1", 0],
    [".hero-sub", 110],
    [".hero-terminal", 220],
  ];
  const reduced = reduceMotion();
  sequence.forEach(([selector, delay]) => {
    const el = document.querySelector(selector);
    if (!el) return;
    if (reduced) el.classList.add("is-visible");
    else setTimeout(() => el.classList.add("is-visible"), delay);
  });
}

function typeReveal(el, html) {
  const lines = html.split("\n");
  if (reduceMotion() || lines.length <= 1) {
    el.innerHTML = html;
    return;
  }
  const cursor = document.createElement("span");
  cursor.className = "terminal-cursor";
  let current = 0;
  const tick = () => {
    el.innerHTML = lines.slice(0, current + 1).join("\n");
    el.appendChild(cursor);
    current += 1;
    if (current < lines.length) {
      setTimeout(tick, 42);
    } else {
      setTimeout(() => cursor.remove(), 600);
    }
  };
  setTimeout(tick, 420);
}

function initHero(data) {
  const cli = data.installAll.cli;
  const settings = JSON.stringify(data.installAll.settings, null, 2);
  const update = data.installAll.update;

  // Map each tab key to its panel; the Copy button always copies the visible one.
  const panels = {
    cli: document.getElementById("panel-cli"),
    settings: document.getElementById("panel-settings"),
    update: document.getElementById("panel-update"),
  };
  panels.cli.dataset.raw = cli;
  panels.settings.dataset.raw = settings;
  panels.update.dataset.raw = update;
  panels.settings.querySelector("pre").innerHTML = highlightJson(settings);
  panels.update.querySelector("pre").innerHTML = highlightCli(update);
  typeReveal(panels.cli.querySelector("pre"), highlightCli(cli));

  const tabs = document.querySelectorAll(".tab[data-tab]");
  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      tabs.forEach((t) => t.setAttribute("aria-selected", String(t === tab)));
      Object.entries(panels).forEach(([key, panel]) => {
        panel.hidden = tab.dataset.tab !== key;
      });
    });
  });

  const copyBtn = document.getElementById("hero-copy");
  copyBtn.addEventListener("click", () => {
    const active = Object.values(panels).find((p) => !p.hidden) || panels.cli;
    copyText(active.dataset.raw, copyBtn);
  });
}

/* ------------------------------ Plugin index ------------------------------ */
function rowHtml(p, index, delay) {
  const number = String(index + 1).padStart(2, "0");
  return `
  <li class="plugin-row" data-reveal data-category="${escapeHtml(p.category)}" style="--delay:${delay}ms">
    <a class="row-link" href="plugin.html?name=${encodeURIComponent(p.name)}">
      <span class="row-num">${number}</span>
      <span>
        <span class="row-name">
          ${escapeHtml(p.name)}
          <span class="row-cat">${escapeHtml(categoryLabel(p.category))}</span>
        </span>
        <span class="row-tagline">${localized(p, "taglineHtml")}</span>
      </span>
      <span class="row-meta">
        <span>v${escapeHtml(p.version)}</span>
        <span class="row-arrow" aria-hidden="true">→</span>
      </span>
    </a>
    <div class="row-install">
      <span class="prompt">$</span>
      <code>${escapeHtml(p.install)}</code>
      <button class="mini-copy" type="button" data-copy="${escapeHtml(p.install)}" aria-label="${escapeHtml(t("copy.installFor", { name: p.name }))}">${escapeHtml(t("copy"))}</button>
    </div>
  </li>`;
}

function renderIndex(data) {
  const root = document.getElementById("plugin-sections");
  const activeFilter = root.querySelector(".chip.active")?.dataset.filter ?? "all";
  const byName = new Map(data.plugins.map((p) => [p.name, p]));
  const active = data.categories.filter((c) => c.plugins.length);

  const chips = [
    `<button class="chip active" type="button" data-filter="all" aria-pressed="true">${escapeHtml(t("filter.all"))}</button>`,
    ...active.map(
      (c) =>
        `<button class="chip" type="button" data-filter="${escapeHtml(c.id)}" aria-pressed="false">${escapeHtml(categoryLabel(c.id))}</button>`,
    ),
  ].join("");

  // Flatten in category order so the single list stays coherent when filtered.
  const ordered = active.flatMap((c) => c.plugins.map((name) => byName.get(name)).filter(Boolean));
  const rows = ordered.map((p, idx) => rowHtml(p, idx, idx * 50)).join("");

  root.innerHTML = `
    <div class="chips" data-reveal role="group" aria-label="${escapeHtml(t("filter.aria"))}">${chips}</div>
    <ul class="plugin-index">${rows}</ul>`;

  bindCopy(root);
  bindFilters(root);
  applyFilter(root, activeFilter);
}

function bindCopy(root) {
  root.querySelectorAll(".mini-copy").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      copyText(btn.dataset.copy, btn);
    });
  });
}

function applyFilter(root, filter) {
  root.querySelectorAll(".chip").forEach((chip) => {
    const on = chip.dataset.filter === filter;
    chip.classList.toggle("active", on);
    chip.setAttribute("aria-pressed", String(on));
  });
  root.querySelectorAll(".plugin-row").forEach((row) => {
    row.hidden = !(filter === "all" || row.dataset.category === filter);
  });
}

function bindFilters(root) {
  root.querySelectorAll(".chip").forEach((chip) => {
    chip.addEventListener("click", () => applyFilter(root, chip.dataset.filter));
  });
}

function setCounts(data) {
  const n = String(data.plugins.length);
  for (const id of ["count-head", "count-cta"]) {
    const el = document.getElementById(id);
    if (el) el.textContent = n;
  }
}

/* -------------------------------- Subpage --------------------------------- */
function listHtml(list) {
  return list
    .map(
      (x) => `
      <li class="cmd-item">
        <span class="cmd-name">${escapeHtml(x.name)}</span>
        <span class="cmd-desc">${x.descriptionHtml}</span>
      </li>`,
    )
    .join("");
}

function surfaceHtml(p) {
  if (p.commands.length) {
    return `<section class="subpage-section" data-reveal><h2>${escapeHtml(t("section.commands"))}</h2><ul class="cmd-list">${listHtml(p.commands)}</ul></section>`;
  }
  if (p.skills.length) {
    return `<section class="subpage-section" data-reveal><h2>${escapeHtml(t("section.skills"))}</h2><ul class="cmd-list">${listHtml(p.skills)}</ul></section>`;
  }
  return "";
}

function configHtml(p) {
  if (!p.config.length) return "";
  const rows = p.config
    .map(
      (c) => `<tr><td>${escapeHtml(c.name)}</td><td>${escapeHtml(c.default)}</td><td>${c.descriptionHtml}</td></tr>`,
    )
    .join("");
  return `
  <section class="subpage-section" data-reveal>
    <h2>${escapeHtml(t("section.config"))}</h2>
    <table class="cfg-table">
      <thead><tr><th>${escapeHtml(t("config.variable"))}</th><th>${escapeHtml(t("config.default"))}</th><th>${escapeHtml(t("config.description"))}</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  </section>`;
}

function changelogHtml(p) {
  if (!p.changelog || !p.changelog.length) return "";
  const entries = p.changelog
    .map((v) => {
      const items = v.changes
        .map((c) => `<li><span class="cl-type cl-type--${escapeHtml(c.type)}">${escapeHtml(c.type)}</span> ${c.html}</li>`)
        .join("");
      return `<div class="cl-version"><h3>${escapeHtml(v.version)} <span class="cl-date">${escapeHtml(v.date)}</span></h3><ul>${items}</ul></div>`;
    })
    .join("");
  return `<section class="subpage-section" data-reveal><h2>${escapeHtml(t("section.changelog"))}</h2><div class="changelog">${entries}</div></section>`;
}

function depsHtml(p, byName) {
  if (!p.dependsOn.length) return "";
  const chips = p.dependsOn
    .map((d) => {
      if (byName.has(d)) {
        return `<li><a class="dep-chip" href="plugin.html?name=${encodeURIComponent(d)}">${escapeHtml(d)}</a></li>`;
      }
      return `<li class="dep-chip external">${escapeHtml(d)} · ${escapeHtml(t("deps.external"))}</li>`;
    })
    .join("");
  return `<section class="subpage-section" data-reveal><h2>${escapeHtml(t("section.deps"))}</h2><ul class="dep-list">${chips}</ul></section>`;
}

function renderSubpage(data) {
  const root = document.getElementById("plugin-detail");
  const name = new URLSearchParams(location.search).get("name");
  const byName = new Map(data.plugins.map((p) => [p.name, p]));
  const p = byName.get(name);

  if (!p) {
    root.innerHTML = `<div class="subpage-head"><h1>${escapeHtml(t("notFound.title"))}</h1></div><p class="subpage-tagline">${escapeHtml(t("notFound.body", { name: name || "" }))} <a href="index.html">${escapeHtml(t("notFound.back"))}</a></p>`;
    revealAll();
    return;
  }

  document.title = `${p.name} — 21-breakincode`;
  root.innerHTML = `
    <div class="subpage-head" data-reveal>
      <h1>${escapeHtml(p.name)} <span class="version">v${escapeHtml(p.version)}</span></h1>
    </div>
    <p class="subpage-tagline" data-reveal>${localized(p, "taglineHtml")}</p>
    <div class="subpage-summary" data-reveal>${localized(p, "summaryHtml")}</div>

    <section class="subpage-section" data-reveal>
      <h2>${escapeHtml(t("section.install"))}</h2>
      <div class="terminal">
        <div class="terminal-body">
          <button class="copy-btn" type="button" id="sub-copy" aria-label="${escapeHtml(t("copy.install"))}">${escapeHtml(t("copy"))}</button>
          <pre>${highlightCli(p.install)}</pre>
        </div>
      </div>
    </section>

    ${surfaceHtml(p)}
    ${configHtml(p)}
    ${depsHtml(p, byName)}
    ${changelogHtml(p)}
  `;

  const copyBtn = document.getElementById("sub-copy");
  copyBtn.addEventListener("click", () => copyText(p.install, copyBtn));
}

/* --------------------------------- Boot ----------------------------------- */
async function main() {
  const isHome = document.body.dataset.page === "home";
  applyLang(initialLang());
  bindLangToggle();
  if (isHome) initHeroEntrance();

  let data;
  try {
    const res = await fetch("data/plugins.json", { cache: "no-cache" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
  } catch (err) {
    revealAll();
    const target = document.getElementById("plugin-sections") || document.getElementById("plugin-detail");
    if (target) {
      target.innerHTML = `<p class="load-error">${t("loadError", { error: escapeHtml(err.message) })}</p>`;
    }
    return;
  }

  const renderPage = () => {
    if (isHome) {
      setCounts(data);
      renderIndex(data);
    } else {
      renderSubpage(data);
    }
  };
  if (isHome) initHero(data);
  renderPage();
  initReveal();
  document.addEventListener("langchange", () => {
    renderPage();
    revealAll();
  });
}

main();
