# session-learner

> Give Claude a memory across sessions

Persists each session's context to disk and injects git-aware context on startup, so a new session knows what changed in the repo and what you did last time. Harvests learnings into Zettelkasten notes via /take-away and /digest.

## Install

```bash
claude plugin install session-learner@cc-plugins
```

## Commands

- **`/session-learner:digest`** — Digest a markdown note, file, or URL — break it down into atomic Zettelkasten cards
- **`/session-learner:take-away`** — Reflect on this session — learnings, corrections, and Zettelkasten card suggestions

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_SESSION_LEARNER_GIT_MODE` | `full` | `full` injects a git-diff summary on session start; `sha-only` just warns about commit count. |
| `CLAUDE_SESSION_LEARNER_MAX_AGE_DAYS` | `7` | Days to keep session files in `~/.claude/sessions/`. |
| `CLAUDE_SESSION_LEARNER_ZK_PATH` | `~/…/LifeOS/03-Resource/Zettelkasten/Permanent` | Vault `Permanent/` dir used to ground `/digest` tag and link suggestions. |

---

Part of the [cc-plugins](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
