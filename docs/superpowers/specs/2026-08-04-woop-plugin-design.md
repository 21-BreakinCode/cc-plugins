# WOOP plugin — design spec

**Status:** Experimental (v0.1.0) · **Date:** 2026-08-04 · **Category:** `review` (Review & Design)

A Claude Code plugin that installs a **problem / critical-thinking mindset** into the dev
lifecycle via Oettingen's **WOOP** (Wish · Outcome · Obstacle · Plan) plus Gollwitzer's
if-then implementation intentions.

---

## 1. Purpose & positioning

WOOP is a **commit lens, not an explore lens.** It attaches to any moment where you have
*understood* something and are about to *act* — and forces obstacle-awareness plus an
if-then reflex before you commit.

- It does **not** replace exploratory analysis, design, or debugging. It caps them.
- Its sharpest niche (not owned by any existing plugin) is `decide`: pre-morteming your
  own conclusion instead of re-running the analysis.

**Success criterion:** every run surfaces (a) a re-framed *essence* wish, (b) at least one
*actionable* obstacle, and (c) an `If … then …` plan per kept obstacle — rendered as a
terminal INSIGHT the user can check.

## 2. The mental model (two leading words + one rule)

- **essence-wish** — every run forces *surface wish → true wish*. "Fix the CTR drop" →
  "restore trustworthy attribution." The skill blocks progress past W until an essence-wish
  is named; the reframing is the value.
- **if-then reflex** — the Plan step is always `If <trigger>, then <action>`, so when the
  obstacle hits you act instead of panic.
- **The Obstacle rule (the discipline that stops WOOP degrading into a wish-list):** an
  obstacle must be something you can **attach an if-then trigger to** — internal *or*
  systemic-but-addressable. "The market crashed" fails; "we keep blaming creative when it's
  bid pacing" passes. Non-actionable obstacles are kept **visible but flagged "no if-then"**,
  never silently dropped.

## 3. The four modes (one lens, four temporal stances)

```
        BEFORE ───────────────────►  DURING ──►  AFTER
   ┌──────────┬──────────────┐   ┌──────────┐  ┌────────┐
   │ prevent  │   decide     │   │ firefight│  │  retro │
   └──────────┴──────────────┘   └──────────┘  └────────┘
```

| Mode | Trigger moment | Essence-wish reframes to | Obstacle hunt focuses on |
|---|---|---|---|
| `prevent` | before a risky change/design | the real safety property needed | hidden systemic failure modes |
| `decide` | after an analysis, before acting | "is my read even trustworthy?" | confounders that make the conclusion wrong |
| `firefight` | mid-incident | max survival under hard constraints | rigid playbooks / wasted golden time |
| `retro` | after the event | what recurs that we must stop | lessons that never became behavior |

## 4. Surface & components (hybrid: one engine + a discoverable door)

Fully self-contained. No hooks, no cross-plugin dependencies (honors `plugin-rules.md`).

```
woop/
├── .claude-plugin/plugin.json
├── commands/woop.md                          ← thin door; discoverability
├── skills/woop/SKILL.md                      ← the engine (shared W-O-O-P spine)
│   └── references/{prevent,decide,firefight,retro}.md   ← per-mode framing, disclosed on demand
├── agents/obstacle-hunter.md                 ← adversarial O-step subagent
└── tests/                                     ← fixtures + conformance checker
```

| File | Job |
|---|---|
| `commands/woop.md` | Bare `/woop` → mode-hint picker (`AskUserQuestion`); `/woop <mode>` → straight in. |
| `skills/woop/SKILL.md` | Model-invocable engine: mode resolution + W‑O‑O‑P steps + terminal INSIGHT + persist prompt. Also auto-fires on triggers like "what could go wrong before I ship this" / "pressure-test this conclusion". |
| `references/<mode>.md` | Per-mode reframing prompts. **Progressive disclosure** — loaded only for the active mode, keeping `SKILL.md` lean. |
| `agents/obstacle-hunter.md` | The always-on adversarial red-teamer for the Obstacle step. |

**Two doors, one engine:** `/woop` is the discoverable door; the skill description is the
ambient door. Both reach the same `SKILL.md` (single source of truth).

**Mode resolution (3-tier):** explicit arg → picker → auto-detect from conversation context.
Auto-detect only *suggests*; it never silently picks (wrong mode = wrong reframing).

The bare-`/woop` hint picker:
```
WOOP — pick a mode  (or: /woop <mode>)
  prevent    pre-mortem before you build
  decide     pressure-test a call before you commit
  firefight  triage a live incident
  retro      post-mortem → if-then commitments
```

## 5. Data flow (one run)

```
/woop  ──►  resolve mode ──►  load references/<mode>.md
(or skill      │
 auto-fires)   ▼
        W  essence-wish   surface → true wish   (blocks until essence named)
        O  outcome        vivid success picture (the pull)
        O  OBSTACLE ──► dispatch obstacle-hunter subagent (fresh, adversarial)
                          └─► ranked obstacles ─► keep those passing the Obstacle rule
        P  if-then        per kept obstacle: If <trigger>, then <action>
                          ▼
        terminal WOOP INSIGHT block (house FACT/ASSUME/INSIGHT/SUGGEST style) — user checks
                          ▼
        persist?  ask y/n ─► write WOOP record file
```

## 6. Obstacle-hunter subagent contract

Runs **every mode** (rigor by default; no config knob). Isolated precisely so it is *not*
invested in the plan the main thread just built — the same adversarial-verify pattern
`code-reviewer` / `autoresearch` use.

- **Input:** essence-wish + outcome + plan/context + mode.
- **Brief:** "You are NOT invested in this plan. Find what makes it fail."
- **Per-mode lens:** `prevent`→systemic failure modes, `decide`→confounders,
  `firefight`→rigid playbooks / wasted time, `retro`→why lessons don't stick.
- **Returns (structured markdown):** ranked obstacles, each with description, why it bites,
  impact × likelihood, `actionable?` (passes Obstacle rule), and a suggested if-then trigger
  seed.
- **Tools:** Read / Grep / Glob / Bash / WebSearch — **read-only** (analyst, not editor).
- **Division of labor:** subagent *proposes* obstacles + trigger seeds; the main thread
  *commits* the if-then plan (keeps the human's judgment on the commitment).

## 7. Output & persistence

**Primary deliverable = the terminal INSIGHT block.** The mindset lives in *seeing* the
WOOP reasoning each run, in the user's house style, for them to sanity-check. Saving is an
optional tail, not the point.

**Persistence = ask per run** (also satisfies the "ask before mutating" rule — the file
write is the mutation). On yes:

```
docs/woop/YYYY-MM-DD-<mode>-<slug>.md
────────────────────────────────────────────
---
mode: decide
date: 2026-08-04
essence_wish: restore trustworthy attribution
---
## Wish     surface → essence
## Outcome  the pull
## Obstacles (actionable, ranked)
## If-Then Plan          ← the reusable playbook
  - If <trigger>, then <action>
```

The `## If-Then Plan` blocks are the accumulating asset — `grep -r "If " docs/woop/` becomes
a decision journal / pre-committed playbook across runs.

## 8. Edge cases (fail loud, degrade gracefully)

| Case | Behavior |
|---|---|
| Obstacle-hunter unavailable / errors | Fall back to inline O, **print a note** that red-teaming was self-run (weaker) — never silent. |
| Auto-detected mode ambiguous | Suggest, confirm before proceeding. |
| Obstacle fails the actionable rule | Kept visible, **flagged "no if-then"** — not silently dropped. |
| Wish stays surface-level | Skill blocks progress to O until an essence-wish is named. |

## 9. Testing

Mirrors `session-learner/tests/`: per-mode fixtures + a **shell conformance checker** (no
framework) asserting each run's output has all four W‑O‑O‑P sections, a surface→essence
reframing, and an `If … then …` for every planned obstacle.

## 10. Plugin wiring

- `.claude-plugin/plugin.json` + `marketplace.json` entry — `name: woop`, `version: 0.1.0`,
  author William Hung. Versions kept equal in both files.
- `content/plugins.content.json` entry (tagline / summary / `category: review`) — must stay
  in lockstep with `marketplace.json` or GEN throws.
- Run `./scripts/cicd.sh GEN` then `VERIFY`; README / CATALOG / site regenerate from source
  (never hand-edited).

## 11. Non-goals (YAGNI)

- No hooks, no ambient injection — every mode is a deliberate "I hit this moment" invocation.
- No env-var config knobs.
- No cross-plugin dependencies.
- Does **not** redo analysis, design, or debugging — it caps them.
