# adhd-review

> Action-first replies, blockers before FYI

One output style, two layers. Layer 1 shapes every reply — lead with the action, number multi-step work with time estimates, cut preamble/recap/closers, state errors matter-of-factly. Layer 2 governs the final turn of substantial multi-step work with Review-Ready buckets — ✅ Done / ⚠️ Broken / 🙋 What I need from you / 🤖 What I'll do, blockers before FYI, each ask naming why it's yours. Applies to the human-facing thread only: the output-style mechanism and an opt-in SessionStart hook both target the main session, so subagent returns stay full-detail. Toggle per session with /adhd-review-mode or /output-style adhd-review.

## Install

```bash
claude plugin install adhd-review@21-breakincode
```

## Skills

Invoke one directly as `/adhd-review:<skill>`, or let it activate automatically when relevant.

- **`adhd-review-mode`** — Use to toggle the adhd-review output style for the current session — turn ADHD-friendly, action-first, blocker-before-FYI reply shaping on…

## Configuration

| Variable | Default | Description |
|---|---|---|
| `~/.claude/.adhd-review-always` | `absent` | Opt-in flag FILE (not an env var) for always-on mode. `touch` it to auto-apply the style to every new session; `rm` to stop. Honors `$CLAUDE_CONFIG_DIR`. Absent = installing the plugin changes nothing. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
