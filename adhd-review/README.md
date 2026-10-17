# adhd-review

> Action-first replies, blockers before FYI

One ruleset, three layers. Layer 1 shapes every reply — lead with the action, number multi-step work with time estimates, cut preamble/recap/closers, state errors matter-of-factly. Layer 2 governs the final turn of substantial multi-step work with Review-Ready buckets — ✅ Done / ⚠️ Broken / 🙋 What I need from you / 🤖 What I'll do, blockers before FYI, each ask naming why it's yours and asked through the AskUserQuestion picker; a Stop hook asks Claude once to re-ask a plain-text question as a picker. A Visual Layer draws non-linear flow-shaped concepts — branches, loops, state changes, hierarchies — as fenced ASCII diagrams instead of prose, while linear steps stay numbered lists. Applies to the human-facing thread only: a default-on SessionStart hook injects the rules into the main session, so subagent returns stay full-detail. On by default — installing the plugin shapes the main thread out of the box; set CLAUDE_ADHD_REVIEW=0 to silence a session. Toggle per session with /adhd-review-mode.

## Install

```bash
claude plugin install adhd-review@21-breakincode
```

## Skills

Invoke one directly as `/adhd-review:<skill>`, or let it activate automatically when relevant.

- **`adhd-review-mode`** — Use to toggle the adhd-review reply style for the current session.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_ADHD_REVIEW` | `unset → on` | Per-session kill switch for both hooks (rule injection and the picker check). On by default. Set to `0` to disable both for that session; unset (or `1`) re-enables. The style targets the main thread only; subagents never inherit it. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
