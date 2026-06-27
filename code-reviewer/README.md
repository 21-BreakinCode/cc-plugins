# code-reviewer

> Principle-aware PR review

Layers a repo-specific review-mindset agent on top of pr-review-toolkit's 4+6 perspectives, citing your repo's own distilled principles, hotspots, and red-flags. Degrades gracefully to the standard review when no principle directory exists.

## Install

```bash
claude plugin install code-reviewer@21-breakincode
```

## Commands

- **`/code-reviewer:review-pr`** — Principle-aware PR review — layers a repo-specific review mindset on top of the standard 4+6 multi-agent review

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CODE_REVIEWER_PRINCIPLE_DIR` | `—` | Hard override; skip the resolution chain and use this principle directory. |
| `CODE_REVIEWER_CONFIG_FILE` | `~/.claude/code-reviewer/config.json` | Override the config file that lists principle-directory roots. |
| `CODE_REVIEWER_CACHE_FILE` | `~/.claude/code-reviewer/principle-map.json` | Override the per-repo principle-path cache. |

## Depends on

- `pr-review-toolkit` _(external)_
- [`hh`](../handover-handler/README.md)

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
