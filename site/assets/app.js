// cc-plugins site — fetches generated plugins.json and renders the landing
// grid + per-plugin subpage. No framework, no build step.

const CAT_COLOR = {
  memory: "var(--cat-memory)",
  improve: "var(--cat-improve)",
  review: "var(--cat-review)",
  workflow: "var(--cat-workflow)",
  media: "var(--cat-media)",
};

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
  btn.textContent = "Copied ✓";
  setTimeout(() => {
    btn.classList.remove("is-copied");
    btn.textContent = original;
  }, 1600);
}

function initReveal() {
  const els = document.querySelectorAll("[data-reveal]");
  if (!("IntersectionObserver" in window)) {
    els.forEach((el) => el.classList.add("is-visible"));
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
function initHero(data) {
  const cli = data.installAll.cli;
  const settings = `${JSON.stringify(data.installAll.settings, null, 2)}`;

  const panelCli = document.getElementById("panel-cli");
  const panelSettings = document.getElementById("panel-settings");
  panelCli.querySelector("pre").innerHTML = highlightCli(cli);
  panelCli.dataset.raw = cli;
  panelSettings.querySelector("pre").innerHTML = highlightJson(settings);
  panelSettings.dataset.raw = settings;

  const tabs = document.querySelectorAll(".tab[data-tab]");
  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      tabs.forEach((t) => t.setAttribute("aria-selected", String(t === tab)));
      panelCli.hidden = tab.dataset.tab !== "cli";
      panelSettings.hidden = tab.dataset.tab !== "settings";
    });
  });

  const copyBtn = document.getElementById("hero-copy");
  copyBtn.addEventListener("click", () => {
    const active = panelCli.hidden ? panelSettings : panelCli;
    copyText(active.dataset.raw, copyBtn);
  });
}

/* --------------------------------- Grid ----------------------------------- */
function cardHtml(p, delay) {
  return `
  <article class="plugin-card" data-reveal style="--cat-color:${CAT_COLOR[p.category] || "var(--accent)"}; --delay:${delay}ms">
    <a class="card-link" href="plugin.html?name=${encodeURIComponent(p.name)}" aria-label="${escapeHtml(p.name)} — ${escapeHtml(p.tagline)}"></a>
    <div class="card-top">
      <div class="plugin-icon">${p.icon || "📦"}</div>
      <div class="card-name-row">
        <span class="plugin-name">${escapeHtml(p.name)}</span>
        <span class="version">v${escapeHtml(p.version)}</span>
      </div>
    </div>
    <p class="plugin-tagline">${escapeHtml(p.tagline)}</p>
    <div class="card-install card-cta-row">
      <span class="prompt">$</span>
      <code>${escapeHtml(p.install)}</code>
      <button class="mini-copy" type="button" data-copy="${escapeHtml(p.install)}" aria-label="Copy install command for ${escapeHtml(p.name)}">Copy</button>
    </div>
  </article>`;
}

function renderGrid(data) {
  const root = document.getElementById("plugin-sections");
  const byName = new Map(data.plugins.map((p) => [p.name, p]));
  let delay = 0;
  const sections = data.categories
    .filter((c) => c.plugins.length)
    .map((c) => {
      const cards = c.plugins
        .map((name) => {
          const html = cardHtml(byName.get(name), (delay % 4) * 60);
          delay += 1;
          return html;
        })
        .join("");
      return `
      <div class="category" style="--cat-color:${CAT_COLOR[c.id] || "var(--accent)"}">
        <div class="category-label" data-reveal>${escapeHtml(c.label)}</div>
        <div class="plugin-grid">${cards}</div>
      </div>`;
    })
    .join("");
  root.innerHTML = sections;

  root.querySelectorAll(".mini-copy").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      copyText(btn.dataset.copy, btn);
    });
  });
}

function setCounts(data) {
  const n = String(data.plugins.length);
  ["count-eyebrow", "count-head"].forEach((id) => {
    const el = document.getElementById(id);
    if (el) el.textContent = n;
  });
}

/* -------------------------------- Subpage --------------------------------- */
function surfaceHtml(p) {
  const items = (list, isSkill) =>
    list
      .map(
        (x) => `
      <li class="cmd-item">
        <span class="cmd-name">${isSkill ? "" : ""}${escapeHtml(x.name)}</span>
        <span class="cmd-desc">${escapeHtml(x.description)}</span>
      </li>`,
      )
      .join("");

  if (p.commands.length) {
    return `<section class="subpage-section" data-reveal><h2>Commands</h2><ul class="cmd-list">${items(p.commands, false)}</ul></section>`;
  }
  if (p.skills.length) {
    return `<section class="subpage-section" data-reveal><h2>Skills</h2><p style="color:var(--text-muted);margin-bottom:var(--space-4)">Activates automatically — no slash commands.</p><ul class="cmd-list">${items(p.skills, true)}</ul></section>`;
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

function depsHtml(p, byName) {
  if (!p.dependsOn.length) return "";
  const chips = p.dependsOn
    .map((d) => {
      const target = byName.get(d);
      if (target) {
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
    root.innerHTML = `<h1>Plugin not found</h1><p style="margin-top:var(--space-4)">No plugin named “${escapeHtml(name || "")}”. <a style="color:var(--accent-hover)" href="index.html">Back to all plugins →</a></p>`;
    return;
  }

  document.title = `${p.name} — cc-plugins`;
  root.innerHTML = `
    <div class="subpage-head" data-reveal style="--cat-color:${CAT_COLOR[p.category] || "var(--accent)"}">
      <div class="plugin-icon">${p.icon || "📦"}</div>
      <div>
        <h1>${escapeHtml(p.name)} <span class="version">v${escapeHtml(p.version)}</span></h1>
      </div>
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
  `;

  const copyBtn = document.getElementById("sub-copy");
  copyBtn.addEventListener("click", () => copyText(p.install, copyBtn));
}

/* --------------------------------- Boot ----------------------------------- */
async function main() {
  let data;
  try {
    const res = await fetch("data/plugins.json", { cache: "no-cache" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
  } catch (err) {
    const target = document.getElementById("plugin-sections") || document.getElementById("plugin-detail");
    if (target) {
      target.innerHTML = `<p style="color:var(--color-error)">Could not load plugin data (${escapeHtml(err.message)}). Serve the site over HTTP — try <code>./scripts/cicd.sh serve</code>.</p>`;
    }
    return;
  }

  if (document.body.dataset.page === "home") {
    setCounts(data);
    initHero(data);
    renderGrid(data);
  } else {
    renderSubpage(data);
  }
  initReveal();
}

main();
