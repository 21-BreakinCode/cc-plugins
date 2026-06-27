# 21-breakincode

Knowledge management and workflow automation plugins for Claude Code, distributed as a single monorepo marketplace.

**[Browse plugins & one-shot install →](https://21-breakincode.github.io/cc-plugins/)** · **[CATALOG.md](./CATALOG.md)**

## Install

Add the marketplace:

```bash
/plugin marketplace add 21-BreakinCode/cc-plugins
```

> The GitHub repo is `cc-plugins`; the marketplace it publishes is named **`21-breakincode`** — that's the `@suffix` you install with.

Then install any plugin:

```bash
/plugin install <plugin-name>@21-breakincode
```

To install **all** plugins in one shot, copy the CLI one-liner (or the `settings.json`
snippet) from the [site](https://21-breakincode.github.io/cc-plugins/) or
[CATALOG.md](./CATALOG.md).

## Updating

Third-party marketplaces don't auto-update by default — refresh the catalog, then update
each plugin you've installed:

```bash
/plugin marketplace update 21-breakincode     # pull the latest catalog from GitHub
/plugin update <plugin-name>@21-breakincode   # upgrade one plugin to its latest version
/reload-plugins                               # apply the changes without restarting
```

There's no bulk "update all" command — update each plugin individually, or turn on
auto-update for the marketplace in the `/plugin` → **Marketplaces** tab.

## Plugins

Seven focused plugins across memory, evals, review, workflow, and media. The full,
always-up-to-date list — with taglines, commands, configuration, and install commands —
lives in **[CATALOG.md](./CATALOG.md)** (auto-generated) and on the
**[live site](https://21-breakincode.github.io/cc-plugins/)**.

Each plugin folder contains its own `.claude-plugin/plugin.json` and a generated
`README.md`, and is a self-contained Claude Code plugin.

## Repository structure

```
cc-plugins/
├── .claude-plugin/marketplace.json   # Marketplace manifest — source of truth
├── content/plugins.content.json      # Authored prose (taglines, summaries, config)
├── scripts/                          # cicd.sh + generate-docs.mjs (+ tests)
├── site/                             # GitHub Pages site (generated data in site/data/)
├── CATALOG.md                        # Generated plugin catalog
├── session-learner/  autoresearch/  harness/  remotion-maker/
├── handover-handler/ code-reviewer/ uiux-optimizer/
└── docs/                             # Design specs and plans
```

## Generated docs

`CATALOG.md`, each plugin's `README.md`, and `site/data/plugins.json` are **generated**
from `.claude-plugin/marketplace.json` + `content/plugins.content.json` + each plugin's
command/skill frontmatter. Do not edit them by hand. Everything routes through one script:

```bash
./scripts/cicd.sh gen       # regenerate CATALOG.md, plugin READMEs, site data
./scripts/cicd.sh verify    # unit tests + drift check (exactly what CI runs)
./scripts/cicd.sh serve     # preview the site locally
./scripts/cicd.sh hooks     # one-time: auto-regenerate + stage on every commit
```

CI runs `./scripts/cicd.sh verify` on every PR (`.github/workflows/docs-check.yml`) and
deploys the site to GitHub Pages on push to `main` (`.github/workflows/deploy-pages.yml`).

## License

MIT
