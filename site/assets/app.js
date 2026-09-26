// cc-plugins site — fetches generated plugins.json and renders the landing index
// + per-plugin subpage. No framework, no build step.

const CATEGORY_LABEL = {
  memory: "Memory",
  improve: "Improve",
  review: "Review",
  workflow: "Workflow",
  media: "Media",
  content: "Content",
};

const reduceMotion = () => window.matchMedia("(prefers-reduced-motion: reduce)").matches;
const categoryLabel = (id) => CATEGORY_LABEL[id] || id;

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
  btn.textContent = "Copied";
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
        <span class="row-tagline">${escapeHtml(p.tagline)}</span>
      </span>
      <span class="row-meta">
        <span>v${escapeHtml(p.version)}</span>
        <span class="row-arrow" aria-hidden="true">→</span>
      </span>
    </a>
    <div class="row-install">
      <span class="prompt">$</span>
      <code>${escapeHtml(p.install)}</code>
      <button class="mini-copy" type="button" data-copy="${escapeHtml(p.install)}" aria-label="Copy install command for ${escapeHtml(p.name)}">Copy</button>
    </div>
  </li>`;
}

function renderIndex(data) {
  const root = document.getElementById("plugin-sections");
  const byName = new Map(data.plugins.map((p) => [p.name, p]));
  const active = data.categories.filter((c) => c.plugins.length);

  const chips = [
    `<button class="chip active" type="button" data-filter="all" aria-pressed="true">All</button>`,
    ...active.map(
      (c) =>
        `<button class="chip" type="button" data-filter="${escapeHtml(c.id)}" aria-pressed="false">${escapeHtml(categoryLabel(c.id))}</button>`,
    ),
  ].join("");

  // Flatten in category order so the single list stays coherent when filtered.
  const ordered = active.flatMap((c) => c.plugins.map((name) => byName.get(name)).filter(Boolean));
  const rows = ordered.map((p, idx) => rowHtml(p, idx, idx * 50)).join("");

  root.innerHTML = `
    <div class="chips" data-reveal role="group" aria-label="Filter plugins by category">${chips}</div>
    <ul class="plugin-index">${rows}</ul>`;

  bindCopy(root);
  bindFilters(root);
}

function bindCopy(root) {
  root.querySelectorAll(".mini-copy").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      copyText(btn.dataset.copy, btn);
    });
  });
}

function bindFilters(root) {
  const chips = [...root.querySelectorAll(".chip")];
  const rows = [...root.querySelectorAll(".plugin-row")];
  chips.forEach((chip) => {
    chip.addEventListener("click", () => {
      const filter = chip.dataset.filter;
      chips.forEach((c) => {
        const on = c === chip;
        c.classList.toggle("active", on);
        c.setAttribute("aria-pressed", String(on));
      });
      rows.forEach((row) => {
        row.hidden = !(filter === "all" || row.dataset.category === filter);
      });
    });
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
        <span class="cmd-desc">${escapeHtml(x.description)}</span>
      </li>`,
    )
    .join("");
}

function surfaceHtml(p) {
  if (p.commands.length) {
    return `<section class="subpage-section" data-reveal><h2>Commands</h2><ul class="cmd-list">${listHtml(p.commands)}</ul></section>`;
  }
  if (p.skills.length) {
    return `<section class="subpage-section" data-reveal><h2>Skills — activate automatically</h2><ul class="cmd-list">${listHtml(p.skills)}</ul></section>`;
  }
  return "";
}

function configHtml(p) {
  if (!p.config.length) return "";
  const rows = p.config
    .map(
      (c) => `<tr><td>${escapeHtml(c.name)}</td><td>${escapeHtml(c.default)}</td><td>${escapeHtml(c.description)}</td></tr>`,
    )
    .join("");
  return `
  <section class="subpage-section" data-reveal>
    <h2>Configuration</h2>
    <table class="cfg-table">
      <thead><tr><th>Variable</th><th>Default</th><th>Description</th></tr></thead>
      <tbody>${rows}</tbody>
    </table>
  </section>`;
}

function changelogHtml(p) {
  if (!p.changelog || !p.changelog.length) return "";
  const entries = p.changelog
    .map((v) => {
      const items = v.changes
        .map((c) => `<li><span class="cl-type cl-type--${escapeHtml(c.type)}">${escapeHtml(c.type)}</span> ${escapeHtml(c.text)}</li>`)
        .join("");
      return `<div class="cl-version"><h3>${escapeHtml(v.version)} <span class="cl-date">${escapeHtml(v.date)}</span></h3><ul>${items}</ul></div>`;
    })
    .join("");
  return `<section class="subpage-section" data-reveal><h2>Changelog</h2><div class="changelog">${entries}</div></section>`;
}

function depsHtml(p, byName) {
  if (!p.dependsOn.length) return "";
  const chips = p.dependsOn
    .map((d) => {
      if (byName.has(d)) {
        return `<li><a class="dep-chip" href="plugin.html?name=${encodeURIComponent(d)}">${escapeHtml(d)}</a></li>`;
      }
      return `<li class="dep-chip external">${escapeHtml(d)} · external</li>`;
    })
    .join("");
  return `<section class="subpage-section" data-reveal><h2>Depends on</h2><ul class="dep-list">${chips}</ul></section>`;
}

function renderSubpage(data) {
  const root = document.getElementById("plugin-detail");
  const name = new URLSearchParams(location.search).get("name");
  const byName = new Map(data.plugins.map((p) => [p.name, p]));
  const p = byName.get(name);

  if (!p) {
    root.innerHTML = `<div class="subpage-head"><h1>Not found</h1></div><p class="subpage-tagline">No plugin named “${escapeHtml(name || "")}”. <a href="index.html">Back to all plugins →</a></p>`;
    revealAll();
    return;
  }

  document.title = `${p.name} — 21-breakincode`;
  root.innerHTML = `
    <div class="subpage-head" data-reveal>
      <h1>${escapeHtml(p.name)} <span class="version">v${escapeHtml(p.version)}</span></h1>
    </div>
    <p class="subpage-tagline" data-reveal>${escapeHtml(p.tagline)}</p>
    <p class="subpage-summary" data-reveal>${escapeHtml(p.summary)}</p>

    <section class="subpage-section" data-reveal>
      <h2>Install</h2>
      <div class="terminal">
        <div class="terminal-body">
          <button class="copy-btn" type="button" id="sub-copy" aria-label="Copy install command">Copy</button>
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
      target.innerHTML = `<p class="load-error">Could not load plugin data (${escapeHtml(err.message)}). Serve over HTTP — try <code>./scripts/cicd.sh serve</code>.</p>`;
    }
    return;
  }

  if (isHome) {
    setCounts(data);
    initHero(data);
    renderIndex(data);
  } else {
    renderSubpage(data);
  }
  initReveal();
}

main();
