---
name: recommend
description: Use after wrap-up when unsure which take-away topic matters most — picks exactly one topic to keep, with reasoning.
---

# Recommend

From the candidate topics in the last `wrap-up`, *converge*: pick exactly ONE to keep and justify it. Display everything in the terminal — DO NOT write any files.

## Argument

None. Reads the numbered topics from the most recent `🧭 Session Wrap-Up` in the conversation.

## Phase 0 — Resolve topics

- **No wrap-up in the conversation** → output exactly this, then stop:
  ```
  Run /session-learner:wrap-up first so I have topics to choose from.
  ```
- **Only one candidate topic** → recommend it, noting it was the only one.

## Phase 1 — Rank and pick

Rank the candidate topics on:

- **Reusability** — applies across projects, not a one-off fix.
- **Cost of the lesson** — how much pain it caused here, or would prevent later.
- **Recurrence** — how often it will come up again.
- **Non-obviousness** — worth recording vs. already-common knowledge.

Pick the single strongest topic.

## Output format

```
🎯 Recommended take-away

Topic <n> — <title>

Why this one:
  • <strongest reason: leverage / reusability / cost-of-not-knowing>
  • <why it beats the runners-up, named briefly>

---
Deepen it →  /session-learner:pick-up <n>
```

## Constraints

- DO NOT write any files. Terminal output only.
- Pick exactly ONE topic. Do not produce cards — that is pick-up's job.
