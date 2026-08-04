---
description: "Pressure-test a decision with WOOP — pick a mode (prevent/decide/firefight/retro) or type one directly."
argument-hint: "[prevent|decide|firefight|retro]"
allowed-tools: ["AskUserQuestion"]
---

# /woop

Front door to the **woop** skill (the commit lens). Route by `$ARGUMENTS`:

**If `$ARGUMENTS` is one of `prevent | decide | firefight | retro`:** invoke the woop skill
directly in that mode.

**If `$ARGUMENTS` is empty:** show the mode-hint picker via `AskUserQuestion`, then invoke
the woop skill in the chosen mode:

```
WOOP — pick a mode  (or: /woop <mode>)
  prevent    pre-mortem before you build
  decide     pressure-test a call before you commit
  firefight  triage a live incident
  retro      post-mortem → if-then commitments
```

**If `$ARGUMENTS` is anything else:** show the picker and note the unrecognized mode.

The command only routes; the **woop** skill does the W‑O‑O‑P work (single source of truth).
