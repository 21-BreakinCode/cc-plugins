# uiux-optimizer + taste + motion orchestration — design

- **Date:** 2026-06-27
- **Status:** Approved (design); pending implementation plan
- **Plugin:** `uiux-optimizer` (current v1.1.0)

## Goal

Extend `uiux-optimizer` to orchestrate two external skills so its advice spans
the full design pipeline instead of just reference-driven static suggestions:

1. **Taste Skill** (`tasteskill.dev`, `Leonxlnx/taste-skill`) — anti-slop
   discipline: brief-inference → design-system mapping → banned-pattern +
   hierarchy/contrast enforcement, light/dark parity.
2. **LottieFiles motion-design-skill** (`LottieFiles/motion-design-skill`) —
   motion layer: timing, easing, choreography, Disney principles for UI;
   implementation-agnostic (CSS / Framer Motion / GSAP / Lottie).

## Why these compose (not overlap)

Each skill owns a different layer of the design pipeline:

- **uiux-optimizer (today)** — reference-driven *exemplars*. "Here's how
  Linear/Stripe handle this," sourced live from refero.design and the
  awesome-design-md brand catalogue.
- **taste** — *discipline/judgment*. Avoids generic output; picks a coherent
  system; enforces parity.
- **motion** — the *time dimension*, which uiux-optimizer currently
  de-prioritizes by design (`SKILL.md:74` — motion is a "note-briefly secondary
  domain").

The compound effect is a **pipeline with ordering**: direction → static quality
→ motion. Motion layered on an un-disciplined static UI is wasted, so motion is
gated on static quality, and taste sets guardrails before/with reference work.

## Decisions (locked)

| Fork | Decision | Consequence |
|---|---|---|
| Integration strategy | **Orchestrate external** | Skills stay separately installed and upstream-updatable; plugin stays thin; no license-copy concerns. |
| Structure | **Enrich existing modes + add a full pipeline mode** | Audit/Build/Explore get richer; a new "ship" mode runs the end-to-end sequence. |
| Direction seam | **Parallel, user picks** | taste's system recommendation is presented *alongside* design-advisor's brand directions; the user reconciles. No forced synthesis. |

## Architecture

```
uiux-optimizer/SKILL.md      ← CONDUCTOR (runs in main loop, has the Skill tool)
  ├─ invokes taste-skill           (Skill tool, when installed)
  ├─ dispatches design-advisor     (Agent tool — reference engine, role unchanged)
  └─ invokes motion-design-skill   (Skill tool, when installed)
```

Orchestration lives in `SKILL.md` because only the main loop can invoke other
skills — a dispatched subagent (`design-advisor`) cannot reliably invoke other
skills or agents. `design-advisor` keeps its current job (fetch references,
produce ranked suggestions / brand directions) and loses only its motion
responsibility, which moves up to the dedicated motion layer.

## Modes

| Mode | taste contributes | design-advisor contributes | motion contributes |
|---|---|---|---|
| **Explore** | brief-inference → a *system* pick | 2-3 *brand* directions | — (nothing to animate yet) |
| **Audit** | anti-slop checklist as an extra lens | reference-grounded gaps | critiques existing motion |
| **Build** | shapes generated code (system, parity, bans) | grounds structure in refs | adds interactions after static |
| **Ship** *(new)* | step 1 guardrails | step 1 brand dirs + step 2 refs | step 3, gated |

In Explore and the pipeline's direction step, taste's system pick and
design-advisor's brand directions are shown **in parallel** (the "parallel, user
picks" decision).

## Pipeline ("ship") — gates

The gates are the mechanism that produces the compound effect.

1. **Direction** — invoke taste (brief + system pick) AND dispatch design-advisor
   (Explore → brand directions). Present both in parallel.
   → **GATE: user picks a direction.**
2. **Static quality** — with the chosen direction, dispatch design-advisor for
   reference-grounded structure and apply taste discipline (anti-slop,
   hierarchy, contrast, light/dark parity) to produce/refine the static UI.
   → **GATE: taste pre-flight checks pass.**
3. **Motion** — only after the static gate, invoke motion-skill to layer
   interactions/choreography.
   → **GATE: respects reduced-motion / accessibility.**

## Behaviors / policies

### Dependency posture (revise current rule)

`design-advisor.md:182` currently says "Don't suggest adding dependencies."
Relax this **contextually**: prefer zero-dependency first (CSS animations,
existing system), but allow a dependency (Framer Motion, shadcn, etc.) when the
chosen direction genuinely needs it — and always flag the dependency explicitly.
Keeps the surgical spirit without blocking the motion/taste layers.

### Graceful degradation

The conductor must not hard-fail when a skill is absent:

- **taste-skill missing** → fall back to uiux-optimizer's own Refero-mindset
  discipline; note the install command (`npx skills add Leonxlnx/taste-skill`).
- **motion-skill missing** → fall back to current "note motion briefly when
  relevant" behavior; note the install command
  (`npx skills add LottieFiles/motion-design-skill`).
- The pipeline still runs end-to-end with whatever layers are available.

### Taste scope (YAGNI)

v1 orchestrates only the **core `taste-skill`** (brief→system + anti-slop). The
12 aesthetic variants (`soft-skill`, `brutalist-skill`, etc.) are left as
user-driven flavor — invoked only when the user names that aesthetic. Do not
wire all 13.

## Key risk — install discoverability

Both skills install via `npx skills add …`. Orchestration only works if that
command lands them somewhere **Claude Code actually scans** (a discoverable
skills/plugin directory). If the `skills` CLI installs elsewhere, the `Skill`
tool won't see them and dispatch silently no-ops.

**Must verify before/early in implementation:** install one skill, confirm it
appears in Claude Code's available-skills list and is invocable via the `Skill`
tool. This is the #1 reason graceful degradation is mandatory, not optional.

## Files touched

- `skills/uiux-optimizer/SKILL.md` — add conductor logic + the "ship" mode; keep
  lean by delegating detail to the new reference file.
- `skills/uiux-optimizer/references/orchestration.md` — **new**; holds the
  pipeline steps, gates, degradation rules, and per-mode layer wiring so
  `SKILL.md` stays small (many-small-files rule).
- `agents/design-advisor.md` — minor: drop motion ownership; note that in
  Explore its brand directions sit beside taste's system pick; relax the
  no-dependencies constraint per the dependency posture above.
- `.claude-plugin/plugin.json` — update description; bump version; document the
  two optional external skill dependencies and their install commands.

## Out of scope (v1)

- Vendoring or re-authoring either external skill (chose orchestrate-external).
- The 12 non-core taste aesthetic variants beyond name-triggered invocation.
- Any change to how design-advisor fetches references (refero.design / catalogue
  logic is unchanged).
- Synthesizing taste's system pick with brand directions (chose parallel).

## Success criteria

1. Invoking uiux-optimizer in each mode demonstrably calls the right layers in
   the right order (verifiable by the conductor's stated sequence).
2. With both skills installed, the "ship" pipeline runs direction → static →
   motion with the three gates enforced.
3. With either/both skills uninstalled, the plugin still produces useful output
   and surfaces the relevant install command (no hard failure).
4. Motion is no longer a buried footnote — it is an explicit, gated layer.
