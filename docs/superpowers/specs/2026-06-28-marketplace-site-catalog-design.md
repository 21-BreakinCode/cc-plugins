# Marketplace site + auto-generated CATALOG — design

**Date:** 2026-06-28
**Repo:** `21-BreakinCode/cc-plugins`
**Status:** approved (brainstorm) → implementation

## Goal

Promote the `cc-plugins` marketplace with a GitHub Pages site and keep every
piece of plugin documentation in sync from a **single source of truth**.

Three user requirements:

1. A GitHub Pages site (served from `main`) with a **hero** offering a one-shot
   "install everything" command, and a section below for **individual** installs.
   Every command is a **copyable code block** (one-click copy).
2. A **CATALOG.md**, auto-updated from `.claude-plugin/marketplace.json`, giving a
   high-level summary of each plugin.
3. Each plugin's **README.md** fully (re)generated: a clean, short intro + a
   `## Commands` section. The same content is presented on the site as a smooth
   **per-plugin subpage**.

## Key facts that shaped the design

- **No batch-install command exists** in Claude Code (verified against
  code.claude.com docs). Two real "install all" mechanisms:
  - **CLI one-liner** — `claude plugin marketplace add … && claude plugin install …`
    chained for all plugins. Terminal-native, no restart. → **hero default**.
  - **settings.json snippet** — `extraKnownMarketplaces` + `enabledPlugins` keys
    pasted into `~/.claude/settings.json`; requires a restart. → **secondary tab**.
- **Plugin names ≠ folder names.** `handover-handler/` is published as **`hh`**.
  Install commands must read the published `name` from the manifest — hand-writing
  them is error-prone. This is the core argument for generation.
- Every command file (`<plugin>/commands/*.md`) has frontmatter with a
  `description`; the filename is the command name. `uiux-optimizer` has **no**
  commands (skill-only) and **no** README today.
- GitHub Pages runs Jekyll by default, which ignores dotfolders like
  `.claude-plugin/`. We deploy via **GitHub Actions** (artifact upload, no Jekyll),
  and the site reads a generated `plugins.json` rather than the manifest directly.
  A `.nojekyll` file is included for safety.

## Architecture: one generator, three outputs

```
INPUTS (source of truth)                      GENERATOR                 OUTPUTS
.claude-plugin/marketplace.json  ┐
content/plugins.content.json     ├──►  scripts/generate-docs.mjs  ──►  CATALOG.md
<plugin>/commands/*.md (frontmatter)                                   <plugin>/README.md  (×7)
<plugin>/skills/*/SKILL.md (frontmatter)                               site/data/plugins.json
```

- **`marketplace.json`** — name, source, one-liner description, version (machine truth).
- **`content/plugins.content.json`** — the only file a human edits for prose:
  per-plugin `tagline`, `summary` (the short blurb), `category`, `icon`,
  `dependsOn`, optional `config` (env-var table). Keyed by published plugin name.
- **command / skill frontmatter** — harvested for the `## Commands` / `## Skills`
  sections. Commands whose description starts with `[DEPRECATED]` are skipped.

The site "references the CATALOG" via `plugins.json` — the structured form of the
same content. CATALOG.md is the human-readable form; both come from one run.

### Generator module layout (Node ESM, zero dependencies)

```
scripts/
├── generate-docs.mjs          # CLI: read FS → build model → write/--check
├── generate-docs.test.mjs     # node:test suite
└── lib/
    ├── frontmatter.mjs        # parseFrontmatter(text) → { description, name }
    ├── collect.mjs            # buildModel(marketplace, content, repoRoot)
    ├── install.mjs            # cliOneLiner(model), settingsSnippet(model)
    ├── render-catalog.mjs     # renderCatalog(model) → markdown
    ├── render-readme.mjs      # renderReadme(plugin, model) → markdown
    └── site-data.mjs          # buildSiteData(model) → JSON object
```

Pure functions (render/build/parse) are unit-tested; the CLI is a thin shell that
does I/O. `--check` regenerates in memory and diffs against on-disk files,
exiting non-zero on drift (for CI).

### Validation (fail fast at the boundary)

- Every plugin in `marketplace.json` must have a `content` entry → else error, exit 1.
- A content entry for an unknown plugin → warning.
- A plugin `source` folder that doesn't exist → error, exit 1.

## Data shapes

`content/plugins.content.json`:

```json
{
  "categories": [
    { "id": "memory", "label": "Memory & Knowledge" },
    { "id": "improve", "label": "Measure & Improve" }
  ],
  "plugins": {
    "harness": {
      "tagline": "Build the feedback machinery around your agent",
      "summary": "Scans your project for missing feedback loops…",
      "category": "improve",
      "icon": "🔧",
      "dependsOn": ["autoresearch"],
      "config": []
    }
  }
}
```

`site/data/plugins.json` (generated):

```json
{
  "marketplace": { "name": "cc-plugins", "version": "1.7.4", "repo": "21-BreakinCode/cc-plugins" },
  "installAll": { "cli": "claude plugin marketplace add …", "settings": { } },
  "categories": [ { "id", "label", "plugins": ["…"] } ],
  "plugins": [
    { "name", "version", "tagline", "summary", "category", "icon",
      "install", "commands": [{ "name", "description" }], "skills": [],
      "dependsOn": [], "config": [] }
  ]
}
```

## Generated README template (clean + short)

```
# <name>
> <tagline>

<summary>

## Install
```bash
claude plugin install <name>@cc-plugins
```

## Commands            ← or ## Skills for skill-only plugins
- **`/<plugin>:<cmd>`** — <description>

## Configuration       ← only if config present
| Variable | Default | Description |

## Depends on          ← only if dependsOn present
- <dep>

---
Part of the cc-plugins marketplace · generated, do not edit by hand.
```

## Website (`site/`, bespoke static — no framework build)

```
site/
├── index.html        # hero (install-all CLI/settings tabs) + plugin grid + individual installs
├── plugin.html       # data-driven subpage; reads ?name=<plugin> from plugins.json
├── assets/styles.css # design tokens + components + motion (direction from uiux-optimizer)
├── assets/app.js     # fetch plugins.json, render, copy-to-clipboard, tab switch, scroll reveal
├── data/plugins.json # generated
└── .nojekyll
```

- **Hero:** tabbed copy block — *CLI one-liner* (default) and *settings.json*.
- **Grid:** plugin cards grouped by category; each links to `plugin.html?name=…`.
- **Subpage:** tagline, summary, install command, commands/skills, config, deps —
  rendered client-side with a smooth fade/slide; `prefers-reduced-motion` respected.
- Bespoke tokenized CSS (not Tailwind) for full control of the crafted look and
  motion. Visual direction comes from the **uiux-optimizer** skill.

## Sync mechanism

- **Pre-commit** (`.githooks/pre-commit`, enabled via `git config core.hooksPath .githooks`):
  runs the generator and `git add`s the outputs so commits never drift.
- **CI — `docs-check.yml`** (on pull_request): `node scripts/generate-docs.mjs --check`
  + `node --test`; fails on drift. The real safety net (independent of local hooks).
- **CI — `deploy-pages.yml`** (on push to `main` + manual): regenerate, upload
  `site/` artifact, deploy to GitHub Pages. `pages: write`, `id-token: write`.

Generated artifacts (CATALOG.md, READMEs, plugins.json) **are committed** so the
repo is browseable and the site previews locally.

## Decisions (locked with user)

| Decision | Choice |
|---|---|
| Install-all UX | CLI one-liner (hero default) + settings.json tab; copyable code blocks |
| Deploy | GitHub Actions → Pages, from `main` |
| Site stack | Bespoke static HTML/CSS/JS (no build); data-driven subpages |
| README ownership | **Full generation** from template + per-plugin blurb field |
| CATALOG sync | Generator + pre-commit + CI drift check |

## Out of scope

- No batch-install command (doesn't exist; we generate the chained one-liner).
- No CMS / framework build step. No server. No analytics.
- Root README stays hand-written except a pointer to CATALOG + the live site.

## Success criteria

1. `node scripts/generate-docs.mjs` produces CATALOG.md, 7 READMEs, plugins.json.
2. `node scripts/generate-docs.mjs --check` exits 0 right after a generate, non-zero
   after an unsynced manifest edit.
3. `node --test` passes (frontmatter parsing, deprecated-skip, hh-name, render shape).
4. `site/index.html` opens locally: hero copy works, grid lists all 7 plugins,
   a subpage renders commands for a command plugin and skills for `uiux-optimizer`.
5. Workflows are valid YAML with correct Pages permissions.
