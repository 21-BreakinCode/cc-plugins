---
name: woop
description: Use to pressure-test a decision with WOOP (Wish·Outcome·Obstacle·Plan) before you commit. Fires when pre-morteming a risky change before you ship, sanity-checking whether a data/analysis conclusion is trustworthy before acting on it, triaging a live incident under hard constraints, or converting a retro/post-mortem into if-then commitments. Also on "what could go wrong", "stress-test this plan", "is this conclusion trustworthy", or /woop.
---

# WOOP — the commit lens

WOOP turns a conclusion into an **obstacle-aware, if-then plan** *before* you act. It caps
thinking you have already done — an analysis, a design, a post-mortem — it never redoes it.
Run it at any moment you are about to **commit**.

## Two leading words

- **essence-wish** — first reframe the *surface* wish into the *true* wish. "Fix the CTR
  drop" → "restore trustworthy attribution." **Do not proceed past W until the essence-wish
  is named** — the reframing is the whole value.
- **if-then reflex** — every plan is `If <trigger>, then <action>`, so when the obstacle
  hits you *act* instead of freeze.

## The Obstacle rule

An obstacle counts only if you can attach an **if-then trigger** to it — internal ("I skip
the test when rushed") or systemic-but-addressable ("attribution silently double-counts").
An external act-of-god ("the market crashes") fails the rule: keep it **visible but flagged
`no if-then`**, never silently dropped — so the user sees what they are *not* planning for.

## Modes — one lens, four moments

| Mode | Fires | Reference |
|---|---|---|
| `prevent` | before a risky change / design | `references/prevent.md` |
| `decide` | after an analysis, before acting on it | `references/decide.md` |
| `firefight` | mid-incident, under hard constraints | `references/firefight.md` |
| `retro` | after the event | `references/retro.md` |

**Resolve the mode (3-tier):** explicit arg → ask the user to pick → auto-detect from
context. Auto-detect only *suggests*; confirm before proceeding — the wrong mode reframes the
wrong problem.

Read the active mode's file — `${CLAUDE_PLUGIN_ROOT}/skills/woop/references/<mode>.md` —
before step W. It carries that mode's reframing and the obstacle-family lens to hand the
subagent.

## Run: W → O → O → P

1. **W — essence-wish.** State the surface wish, then reframe to the essence-wish (see the
   mode reference). Block here until it is named.
2. **O — outcome.** One vivid picture of success — the pull that makes the work worth it.
3. **O — obstacle (always red-teamed).** Dispatch the **obstacle-hunter** subagent with:
   essence-wish + outcome + the plan/context + the mode. It returns ranked obstacles, each
   with `actionable?` and an if-then trigger seed. Keep the rule-passing ones; flag the rest
   `no if-then`. **If the subagent is unavailable, hunt obstacles inline and print a note
   that the red-team was self-run (weaker) — never silent.**
4. **P — if-then plan.** For each kept obstacle: `If <trigger>, then <action>`. Concrete
   trigger, concrete action.

## Output — the terminal WOOP INSIGHT

Render the result in the terminal for the user to check, in the house style:

- **FACT:** the essence-wish (surface → essence) and the ranked actionable obstacles.
- **ASSUME:** what is still uncertain in the obstacles or outcome.
- **INSIGHT:** the non-obvious blind spot the red-team surfaced.
- **SUGGEST:** the if-then plan — the commitments to carry forward.

The mindset lives in *seeing* this each run.

## Persist — ask per run

Ask: **"Save this WOOP record? (y/n)"** On yes, write
`docs/woop/<YYYY-MM-DD>-<mode>-<slug>.md`:

```
---
mode: <mode>
date: <YYYY-MM-DD>
essence_wish: <one line>
---
## Wish
surface: ...
essence: ...
## Outcome
...
## Obstacles (actionable, ranked)
1. ...
## If-Then Plan
- If <trigger>, then <action>
```

The `## If-Then Plan` blocks accumulate — `grep -r "If " docs/woop/` is your decision journal.
