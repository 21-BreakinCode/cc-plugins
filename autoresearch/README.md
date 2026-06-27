# autoresearch

> Eval-driven, autonomous code improvement

Runs an edit → eval → keep/discard loop on any artifact — code, prompts, or docs — scoring each change with a shell command, an LLM judge, or both. Keeps what passes, reverts what doesn't, and shows progress on a live auto-refreshing dashboard.

## Install

```bash
claude plugin install autoresearch@21-breakincode
```

## Commands

- **`/autoresearch:improve`** — Iteratively improve any artifact using an edit-eval-keep/discard loop with live dashboard

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
