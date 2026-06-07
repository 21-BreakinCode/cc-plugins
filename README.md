# cc-plugins

Knowledge management and workflow automation plugins for Claude Code, distributed as a single monorepo marketplace.

## Installation

Add this marketplace to Claude Code:

```bash
/plugin marketplace add 21-BreakinCode/cc-plugins
```

Then install any plugin:

```bash
/plugin install <plugin-name>@cc-plugins
```

## Available Plugins

### session-learner

Session memory persistence, git-aware context injection, strategic compact suggestions, and `/take-away` reflections.

```bash
/plugin install session-learner@cc-plugins
```

- Automatic session memory saved to `~/.claude/sessions/`
- Git-aware context injection (detects codebase changes between sessions)
- Strategic `/compact` suggestions after configurable tool-call threshold
- Pre-compact annotation of session files
- `/session-learner:take-away` — reflect on session learnings and Zettelkasten card suggestions
- `/session-learner:digest` — digest files/URLs into Zettelkasten cards

Configuration: `CLAUDE_SESSION_LEARNER_GIT_MODE`, `CLAUDE_SESSION_LEARNER_COMPACT_THRESHOLD`, `CLAUDE_SESSION_LEARNER_MAX_AGE_DAYS` in `~/.zshrc`.
Optional dependency: `jq`.

### autoresearch

Iterative improvement loop with eval-driven keep/discard and live HTML dashboard, inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

```bash
/plugin install autoresearch@cc-plugins
```

- `/autoresearch:improve` — iteratively improve any artifact (code, prompts, docs)
- Shell command evals, LLM-as-judge scoring, or composite (both)
- Auto-refreshing HTML dashboard with Chart.js score visualization
- Git-backed experiment history (kept changes committed, discarded changes reverted)
- On-demand web research via defuddle
- Configurable stopping conditions

> The previous `/autoresearch:harness-check` and `/autoresearch:harness-improvement` commands have moved to the `harness` plugin below (deprecated aliases remain for one minor version).

### harness

Dev-lifecycle harness builder. Inspired by [OpenAI — Harness Engineering](https://openai.com/index/harness-engineering/). Depends on `autoresearch`.

```bash
/plugin install harness@cc-plugins
```

- `/harness:check` — score project health across 6 categories (5 base + new `Harness Completeness`)
- `/harness:build` — menu-driven scaffolder for four Tier-1 component types:
  - **Feedback loop** — Claude Code hook posting a domain principle on an event
  - **Eval loop** — shell script returning `{pass, metric, reason}`
  - **Sensor** — linter wrapper emitting agent-tuned fix messages
  - **Context-mgmt** — advisory report on oversized agent/skill files
- `/harness:improvement` — auto-fix the top-ranked issue (delegates the loop to `autoresearch:experimenter`)
- Every scaffolded artifact opens at the simplest viable shape with an inline Tier 1 → 2 → 3 upgrade ladder

### remotion-maker

Generate Remotion (React) videos with consistent style, automated media sourcing, staged preview, and multi-tier verification.

```bash
/plugin install remotion-maker@cc-plugins
```

- `/remotion-maker:create` — full pipeline: style → generate → preview → verify → render
- `/remotion-maker:define-style` — create or manage style definitions
- `/remotion-maker:find-media` — search free resources for media assets
- `/remotion-maker:verify` — verify video against style definition

## Repository Structure

```
cc-plugins/
├── .claude-plugin/
│   └── marketplace.json       # Marketplace manifest (relative-path sources)
├── session-learner/
├── autoresearch/
├── harness/                    # Depends on autoresearch
├── remotion-maker/
├── handover-handler/           # Plugin name: hh
├── code-reviewer/
├── uiux-optimizer/
├── docs/                       # Design notes and plans
└── README.md
```

Each plugin folder contains its own `.claude-plugin/plugin.json` and is a self-contained Claude Code plugin.

## License

MIT
