# Plugin Sprawl Review — 2026-07-05

Surface counts = files on disk under each plugin's installPath from
`~/.claude/plugins/installed_plugins.json`: `skills/*/SKILL.md`, `agents/**.md`,
`commands/**.md` (counted 2026-07-05; corrected after adversarial review — an
earlier draft over-counted skills). Exception: obsidian-visual-skills uses a
nonstandard layout; its 3 skills were counted from a live session's skill list.

## Scoping Mechanics (official, verified 2026-07-05)
- Plugins are user-scope by default (active in every project).
- `/plugin disable <name>@<marketplace>` + `/reload-plugins` disables globally.
- Per-project disabling of a user-scope plugin is NOT documented.
- To "wanted in one repo only": `/plugin install <name>@<mp> --scope project` in that
  repo, then `/plugin disable <name>@<marketplace>` (user scope).

## Already-Disabled (skip re-review)
- `explanatory-output-style@claude-plugins-official` — false in settings.json
- `learning-output-style@claude-plugins-official` — false in settings.json

---

## Plugin Review Table (22 enabled)

Surface notation: Nskills / Nagents / Ncmds = context items injected per session.

| # | Plugin | Surface | Verdict | Rationale | Risk if wrong |
|---|--------|---------|---------|-----------|---------------|
| 1 | `superpowers@claude-plugins-official` | 14s/0a/0c | **KEEP** | Harness-infrastructure: orchestration/planning/git-worktrees used in every env | Lose cross-env orchestration scaffolding |
| 2 | `plugin-dev@claude-plugins-official` | 7s/3a/1c | **RESCOPE → PersonalPlugins** | Pure plugin-authoring skills; only relevant in this marketplace repo | Miss skill hints when authoring plugins |
| 3 | `remotion-maker@21-breakincode` | 1s/4a/4c | **RESCOPE → Remotion project** | Video/animation work is project-specific | Lose Remotion skills outside that project |
| 4 | `pr-review-toolkit@claude-plugins-official` | 0s/6a/1c | **KEEP** | Code review agents used across every software project | Lose multi-perspective PR reviews |
| 5 | `autoresearch@21-breakincode` | 2s/1a/4c | **KEEP** | Research harness used in all envs; his own plugin | Lose /autoresearch commands globally |
| 6 | `chrome-devtools-mcp@claude-plugins-official` | 6s/0a/0c + ~30 MCP tools | **RESCOPE → web projects** | Browser debug/audit; its ~30 deferred MCP tool stubs are the real tax; not useful in LifeOS or k8s/docker work | Lose devtools automation in web sessions |
| 7 | `hookify@claude-plugins-official` | 1s/1a/4c | **KEEP** | Hook config spans all projects; low surface | Lose hook authoring anywhere |
| 8 | `obsidian@obsidian-skills` | 5s/0a/0c | **RESCOPE → LifeOS** | Obsidian CLI/markdown/bases skills; single-environment (vault) | Lose obsidian skills in vault sessions |
| 9 | `hh@21-breakincode` | 0s/0a/4c | **RESCOPE → LifeOS** | Handover commands; LifeOS-only workflow | Lose /hh commands in vault |
| 10 | `session-learner@21-breakincode` | 3s/0a/0c | **KEEP** | Session-memory plugin; cross-env by design; his own | Lose session summaries and pick-up |
| 11 | `obsidian-visual-skills@axton-obsidian-visual-skills` | 3s/0a/0c | **RESCOPE → LifeOS** | Excalidraw/Mermaid/Canvas in Obsidian; vault-only | Lose visual diagram skills in vault |
| 12 | `code-reviewer@21-breakincode` | 0s/2a/1c | **KEEP** | His own dogfooded reviewer; low surface; used in any repo with PRs | Lose /code-reviewer:review-pr command |
| 13 | `agent-sdk-dev@claude-plugins-official` | 0s/2a/1c | **RESCOPE → PersonalPlugins** | SDK app scaffolding; only relevant when authoring agents/plugins | Lose agent-creator in this repo |
| 14 | `uiux-optimizer@21-breakincode` | 1s/1a/0c | **KEEP** | UI reviews useful across any web project; low surface | Lose uiux-optimizer skill |
| 15 | `code-simplifier@claude-plugins-official` | 0s/1a/0c | **KEEP** | Single agent, zero skills; universal code quality use | Lose /simplify agent everywhere |
| 16 | `skill-creator@claude-plugins-official` | 1s/0a/0c | **RESCOPE → PersonalPlugins** | Skill authoring; only needed when creating/editing skills in this repo | Miss skill-creator in marketplace repo |
| 17 | `claude-code-setup@claude-plugins-official` | 1s/0a/0c | **DISABLE** | One-time onboarding recommender; setup is complete across envs | Nothing — it is already done |
| 18 | `context7@claude-plugins-official` | 0s/0a/0c + 2 MCP tools | **KEEP** | Near-zero surface; universal library-docs lookup across all envs | Lose live doc fetching everywhere |
| 19 | `typescript-lsp@claude-plugins-official` | 0s/0a/0c | **KEEP** | Zero surface; LSP tooling; TypeScript used across projects | Lose TS type-checking in LSP sessions |
| 20 | `pyright-lsp@claude-plugins-official` | 0s/0a/0c | **KEEP** | Zero surface; Python used in k8s/docker work | Lose Python type-checking via LSP |
| 21 | `gopls-lsp@claude-plugins-official` | 0s/0a/0c | **DISABLE** | Zero Go in any named env; zero surface anyway | Nothing — it contributes no context |
| 22 | `warp@claude-code-warp` | 0s/0a/0c (hooks) | **KEEP** | Hooks-only plugin (terminal notify); zero skill surface; cross-env useful | Lose Warp terminal notifications |

---

## Top 5 by Context Surface (file counts; corrected 2026-07-05)

| Rank | Plugin | Total items | Breakdown |
|------|--------|-------------|-----------|
| 1 | `superpowers@claude-plugins-official` | 14 | 14s / 0a / 0c |
| 2 | `plugin-dev@claude-plugins-official` | 11 | 7s / 3a / 1c |
| 3 | `remotion-maker@21-breakincode` | 9 | 1s / 4a / 4c |
| 4 | `pr-review-toolkit@claude-plugins-official` | 7 | 0s / 6a / 1c |
| 4 | `autoresearch@21-breakincode` | 7 | 2s / 1a / 4c |

Counting its ~30 deferred MCP tool stubs, `chrome-devtools-mcp` (~36 items)
actually tops this list — visible in any session's system prompt.

Executing all disables + rescopes removes ~43 skill/agent/command items plus
~30 MCP tool stubs from every session outside their home projects.

---

## Commands to Run (disable / rescope verdicts)

### DISABLE (run these first — simplest)
```
/plugin disable claude-code-setup@claude-plugins-official
/plugin disable gopls-lsp@claude-plugins-official
/reload-plugins
```

### RESCOPE → PersonalPlugins repo (run inside /Users/williamhung/Projects/PersonalPlugins)
```
/plugin install plugin-dev@claude-plugins-official --scope project
/plugin disable plugin-dev@claude-plugins-official
/plugin install skill-creator@claude-plugins-official --scope project
/plugin disable skill-creator@claude-plugins-official
/plugin install agent-sdk-dev@claude-plugins-official --scope project
/plugin disable agent-sdk-dev@claude-plugins-official
/reload-plugins
```

### RESCOPE → LifeOS vault (run inside the LifeOS Obsidian vault directory)
```
/plugin install obsidian@obsidian-skills --scope project
/plugin disable obsidian@obsidian-skills
/plugin install obsidian-visual-skills@axton-obsidian-visual-skills --scope project
/plugin disable obsidian-visual-skills@axton-obsidian-visual-skills
/plugin install hh@21-breakincode --scope project
/plugin disable hh@21-breakincode
/reload-plugins
```

### RESCOPE → web/frontend projects (run inside relevant project)
```
/plugin install chrome-devtools-mcp@claude-plugins-official --scope project
/plugin disable chrome-devtools-mcp@claude-plugins-official
/reload-plugins
```

### RESCOPE → Remotion project (run inside that project's directory)
```
/plugin install remotion-maker@21-breakincode --scope project
/plugin disable remotion-maker@21-breakincode
/reload-plugins
```
