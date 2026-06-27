# Orchestration Reference

How `uiux-optimizer` conducts the external taste and motion skills around its own
`design-advisor` reference engine. The skill (`SKILL.md`) is the conductor; this
file holds the wiring detail so `SKILL.md` stays lean.

## Conductor model

Orchestration runs in the **main loop**, not inside a subagent — a dispatched
subagent (`design-advisor`) cannot reliably invoke other skills or agents. So
`SKILL.md` sequences:

1. `Skill` tool → **taste-skill** (when installed) — discipline / brief / system
2. `Agent` tool → **design-advisor** — reference-driven exemplars (unchanged role)
3. `Skill` tool → **motion-design-skill** (when installed) — motion choreography

Always check availability and degrade (see Graceful degradation) — never block on
a missing layer.

## Per-mode layer wiring

| Mode | taste | design-advisor | motion |
|---|---|---|---|
| **Explore** | brief-inference → a *system* pick | 2-3 *brand* directions | — (nothing to animate yet) |
| **Audit** | anti-slop checklist as an extra lens | reference-grounded gaps | critiques existing motion |
| **Build** | shapes generated code (system, parity, bans) | grounds structure in refs | adds interactions after static |
| **Ship** *(pipeline)* | step 1 guardrails | step 1 brand dirs + step 2 refs | step 3, gated |

In **Explore** and the pipeline's direction step, taste's system pick and
design-advisor's brand directions are presented **in parallel** — the user
reconciles. Do not force-merge them.

## Pipeline ("ship") — steps and gates

The gates are what produce the compound effect: each layer assumes the previous
one is solid.

1. **Direction** — invoke taste (brief + system pick) AND dispatch design-advisor
   (Explore → brand directions). Present both in parallel.
   **GATE: the user picks a direction before continuing.**
2. **Static quality** — with the chosen direction, dispatch design-advisor for
   reference-grounded structure, and apply taste discipline (anti-slop,
   hierarchy, contrast, light/dark parity) to produce/refine the static UI.
   **GATE: taste pre-flight checks pass before motion.**
3. **Motion** — only after the static gate, invoke motion-skill to layer
   interactions and choreography.
   **GATE: motion respects reduced-motion / accessibility preferences.**

## Graceful degradation

The conductor must complete with whatever layers are available:

- **taste-skill missing** → fall back to uiux-optimizer's own Refero-mindset
  discipline (hierarchy-first, constraint-driven, pattern-first). Note the
  install command: `npx skills add Leonxlnx/taste-skill`.
- **motion-design-skill missing** → fall back to brief, principle-level motion
  notes only. Note the install command:
  `npx skills add LottieFiles/motion-design-skill`.
- The ship pipeline still runs end-to-end; absent layers are skipped, not fatal.

## Dependency posture

Prefer zero-dependency solutions first (CSS animations, the existing design
system). Suggest adding a dependency (e.g. Framer Motion, GSAP, shadcn) only when
the chosen direction genuinely needs it — and always flag the dependency
explicitly so the user opts in knowingly.

## Taste scope (v1)

Orchestrate only the core `taste-skill` (brief → design-system mapping +
anti-slop discipline). The aesthetic variants (`soft-skill`, `brutalist-skill`,
etc.) are user-driven flavor — invoke one only when the user explicitly names
that aesthetic. Do not wire all of them.
