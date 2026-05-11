# session-learner

Session memory persistence, git-aware context injection, strategic compact suggestions, and `/take-away` reflections for Claude Code.

## Installation

```bash
/plugin install session-learner@workflow-plugins-marketplace
```

Or via marketplace:

```bash
/plugin marketplace add 21-BreakinCode/workflow-plugins-marketplace
/plugin install session-learner@workflow-plugins-marketplace
```

## What You Get

- **Session memory** — Automatically saves session context (tasks, files modified, tools used) to `~/.claude/sessions/`
- **Git-aware context** — Detects codebase changes between sessions and warns about stale references
- **Compact suggestions** — Reminds you to `/compact` after configurable tool-call threshold
- **Pre-compact capture** — Annotates session file before context compaction
- **Stop reminder** — Suggests `/session-learner:take-away` when significant work is detected
- `/session-learner:take-away` — Reflect on session learnings, corrections, and Zettelkasten card suggestions
- `/session-learner:digest <path-or-url>` — Digest a file or URL into atomic Zettelkasten cards (terminal-only, with verification gate)

## Configuration

Set these environment variables (e.g., in `~/.zshrc`):

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_SESSION_LEARNER_GIT_MODE` | `full` | `full` = inject git diff summary on session start; `sha-only` = just warn about commit count |
| `CLAUDE_SESSION_LEARNER_COMPACT_THRESHOLD` | `50` | Tool calls before suggesting `/compact` |
| `CLAUDE_SESSION_LEARNER_MAX_AGE_DAYS` | `7` | Days to keep session files in `~/.claude/sessions/` |
| `CLAUDE_SESSION_LEARNER_ZK_PATH` | `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/03-Resource/Zettelkasten/Permanent` | Path to vault `Permanent/` directory for grounding `/digest` tag and link suggestions |

## Optional Dependency

- `jq` (`brew install jq`) — Needed for transcript parsing. Without it, session summaries are minimal.

## License

MIT License
