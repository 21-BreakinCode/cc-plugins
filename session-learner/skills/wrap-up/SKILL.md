---
name: wrap-up
description: Use at the end of a working or debugging session to reflect on pitfalls worth noticing and list candidate take-away topics to keep.
---

# Session Wrap-Up

Reflect on the current session and *diverge*: surface what's worth noticing, then list candidate take-away topics. Use `Read`/`Grep`/`Glob` to inspect files referenced this session when it makes a watch-out concrete. Display everything in the terminal — DO NOT write any files.

## The funnel

- **wrap-up** (this skill) — reflect → watch-outs + numbered candidate topics
- **pick-up** — turn chosen topic number(s) into atomic Zettelkasten cards
- **recommend** — pick exactly one topic to keep, with reasoning

## Instructions

Review the full conversation in this session, then produce exactly the two sections below.

### Watch-outs this session

1–4 items. Each must be a pitfall hit, a footgun, a fragile assumption, or a non-obvious thing worth remembering — and must trace to a real moment in this session (a correction, a bug, a surprising constraint). Skip generic advice. If an item cannot be tied to something that actually happened, drop it.

### Candidate take-away topics

2–6 atomic, reusable topics drawn from the session. NUMBER them. Each is one line: a concise title plus why it is worth keeping. Favor knowledge that is reusable across projects and conceptual over one-off fixes.

## Output format

Display exactly this structure in the terminal:

```
🧭 Session Wrap-Up

## Watch-outs this session
- <watch-out 1>
- <watch-out 2>

## Candidate take-away topics
1. <Topic title> — <why it's worth keeping>
2. <Topic title> — <why it's worth keeping>
3. <Topic title> — <why it's worth keeping>

---
Next:
  /session-learner:pick-up <n[,n…]>   → turn topic(s) into atomic Zettelkasten cards
  /session-learner:recommend           → not sure which? I'll pick the single best one and tell you why
```

## Empty or trivial session

If nothing substantial happened (no real work, debugging, or decisions), output exactly this and stop — no watch-outs, no topic list:

```
Not much to wrap up yet — no substantial work this session.
```

## Constraints

- DO NOT write any files. Terminal output only.
- Topics MUST be numbered so pick-up and recommend can reference them by index.
- Watch-outs MUST reference real session moments, not generic best practices.
