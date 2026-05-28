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

### autoimprove-agents

Modular CLAUDE.md architecture + project/cross-project knowledge base + self-improvement loop for agents.

```bash
/plugin install autoimprove-agents@cc-plugins
```

- `/autoimprove-agents:setup` — interactive first-time configuration
- `/autoimprove-agents:init` — set up modular CLAUDE.md in any project
- `/autoimprove-agents:sync-kb` — capture session learnings to project KB
- `/autoimprove-agents:review-kb` — review and archive stale KB entries
- `/autoimprove-agents:self-improve` — review and apply agent instruction improvements
- Cross-project knowledge agent for surfacing patterns across all projects
- Optional NotebookLM integration for queryable knowledge stores

### zettelkasten-capture

Transform Claude session output into structured Obsidian Zettelkasten draft notes with excalidraw stubs.

```bash
/plugin install zettelkasten-capture@cc-plugins
```

- Automatic draft note generation in Obsidian inbox after each session
- Excalidraw stub creation when architectural topics are detected
- `/zettelkasten-capture:setup` — configure Obsidian vault path
- `/zettelkasten-capture:finalize` — promote drafts to permanent notes
- `/zettelkasten-capture:push-to-kb` — sync notes to project KB (requires autoimprove-agents)

Soft dependencies: session-learner, autoimprove-agents (both optional).

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

Configuration: `CLAUDE_SESSION_LEARNER_GIT_MODE`, `CLAUDE_SESSION_LEARNER_COMPACT_THRESHOLD`, `CLAUDE_SESSION_LEARNER_MAX_AGE_DAYS` in `~/.zshrc`.
Optional dependency: `jq`.

### data-analysis

Structured data analysis using DuckDB and Six Thinking Hats with business-context playbooks and FACT/ASSUME methodology.

```bash
/plugin install data-analysis@cc-plugins
```

- Six Thinking Hats analysis methodology (Blue → White → Red → Black → Yellow → Green)
- DuckDB-powered queries for CSV, Parquet, and JSON datasets
- Business-context playbooks for domain-specific analysis
- FACT/ASSUME structured output for clarity

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

## Repository Structure

```
cc-plugins/
├── .claude-plugin/
│   └── marketplace.json       # Marketplace manifest (relative-path sources)
├── autoimprove-agents/
├── zettelkasten-capture/
├── session-learner/
├── data-analysis/
├── autoresearch/
├── docs/                       # Design notes and plans
└── README.md
```

Each plugin folder contains its own `.claude-plugin/plugin.json` and is a self-contained Claude Code plugin.

## License

MIT
