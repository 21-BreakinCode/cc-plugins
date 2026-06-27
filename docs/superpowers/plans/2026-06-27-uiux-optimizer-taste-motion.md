# uiux-optimizer taste+motion orchestration — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `uiux-optimizer` orchestrate the external taste-skill and motion-design-skill across enriched Audit/Build/Explore modes plus a new gated "ship" pipeline, degrading gracefully when either skill is absent.

**Architecture:** `SKILL.md` becomes the conductor (main loop, Skill tool): it invokes taste-skill, dispatches the unchanged `design-advisor` reference agent, and invokes motion-skill. Pipeline detail lives in a new `references/orchestration.md` so `SKILL.md` stays lean.

**Tech Stack:** Markdown skill/agent instruction files + a JSON plugin manifest. No runtime test framework — verification is structural (grep/jq) and behavioral (plugin-validator agent). "Tests" below are acceptance checks defined before each edit.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `uiux-optimizer/skills/uiux-optimizer/references/orchestration.md` | Create | Per-mode layer wiring, pipeline steps + 3 gates, graceful degradation, dependency posture, taste scope |
| `uiux-optimizer/skills/uiux-optimizer/SKILL.md` | Modify | Add conductor section + "ship" mode; point to orchestration.md; promote motion from footnote; list optional deps; update frontmatter description |
| `uiux-optimizer/agents/design-advisor.md` | Modify | Drop motion ownership; note brand dirs sit beside taste's pick (parallel); relax no-deps constraint |
| `uiux-optimizer/.claude-plugin/plugin.json` | Modify | Bump 1.1.0 → 1.2.0; update description; document 2 optional external skill deps |

---

### Task 1: Create the orchestration reference doc

**Files:**
- Create: `uiux-optimizer/skills/uiux-optimizer/references/orchestration.md`

- [ ] **Step 1: Define acceptance check**

The file must contain, as discrete sections: (a) a per-mode layer-wiring table covering Explore/Audit/Build/Ship, (b) the 3-step pipeline with an explicit GATE line after each step, (c) graceful-degradation rules naming both install commands, (d) the dependency-posture rule, (e) the v1 taste-scope (core only) rule.

- [ ] **Step 2: Write the file**

Content must include:
- **Conductor model:** SKILL.md sequences `Skill`-tool invocations (taste, motion) around an `Agent`-tool dispatch of `design-advisor`. Subagents cannot invoke skills, so orchestration stays in the main loop.
- **Per-mode wiring table** (Explore / Audit / Build / Ship × taste / design-advisor / motion) — same content as the spec's Modes table.
- **Pipeline ("ship") steps with gates:**
  1. Direction — invoke taste (brief + system pick) AND dispatch design-advisor (Explore → brand dirs); present in parallel. **GATE: user picks a direction.**
  2. Static quality — chosen direction → design-advisor reference-grounded structure + taste discipline (anti-slop, hierarchy, contrast, light/dark parity). **GATE: taste pre-flight passes.**
  3. Motion — only after static gate → motion-skill choreography. **GATE: respects reduced-motion.**
- **Graceful degradation:** taste missing → fall back to Refero-mindset discipline + note `npx skills add Leonxlnx/taste-skill`; motion missing → fall back to brief motion notes + note `npx skills add LottieFiles/motion-design-skill`; pipeline always completes with available layers.
- **Dependency posture:** prefer zero-dep first; allow a dep only when the chosen direction needs it; always flag it.
- **Taste scope (v1):** orchestrate only core `taste-skill`; aesthetic variants invoked only when the user names that aesthetic.

- [ ] **Step 3: Verify the acceptance check**

Run: `grep -c "GATE" uiux-optimizer/skills/uiux-optimizer/references/orchestration.md`
Expected: `3` (one per pipeline step).
Run: `grep -E "npx skills add (Leonxlnx|LottieFiles)" uiux-optimizer/skills/uiux-optimizer/references/orchestration.md`
Expected: both install commands present.

- [ ] **Step 4: Commit**

```bash
git add uiux-optimizer/skills/uiux-optimizer/references/orchestration.md
git commit -m "feat(uiux-optimizer): add orchestration reference (pipeline, gates, degradation)"
```

---

### Task 2: Update SKILL.md — conductor + ship mode + motion promotion

**Files:**
- Modify: `uiux-optimizer/skills/uiux-optimizer/SKILL.md`

- [ ] **Step 1: Define acceptance check**

After the edit, SKILL.md must: mention the "ship" pipeline mode, reference `references/orchestration.md`, name both taste and motion as orchestrated layers, no longer relegate motion to a "note-briefly secondary domain," list both optional install commands, and have a frontmatter `description` that mentions motion + anti-slop/taste + pipeline.

- [ ] **Step 2: Edit the Decision Framework**

In the "Dispatch the design-advisor agent" step (currently `SKILL.md:40-44`), add the conductor sequencing: before dispatching design-advisor, invoke `taste-skill` (when available) for guardrails/brief; after design-advisor for Build/Ship, invoke `motion-design-skill` (when available). Add the `ship` operating mode alongside `audit`/`build`/`explore`, described as the gated direction → static → motion pipeline, with a one-line pointer: "See `references/orchestration.md` for pipeline steps, gates, and degradation."

- [ ] **Step 3: Promote motion**

Replace the line `SKILL.md:74` ("Secondary domains (motion, interaction design, accessibility) — note briefly when relevant, don't lead with them") with wording that motion is now a dedicated, gated layer owned by motion-design-skill in Build/Ship, while accessibility remains a cross-cutting concern. Keep it one or two lines.

- [ ] **Step 4: Add optional-dependencies note + update frontmatter**

Add a short "External skills (optional)" subsection listing:
`npx skills add Leonxlnx/taste-skill` and `npx skills add LottieFiles/motion-design-skill`, noting the plugin degrades gracefully without them.
Update the frontmatter `description` to mention motion choreography + anti-slop/taste discipline + the ship pipeline (keep the existing trigger phrases).

- [ ] **Step 5: Verify the acceptance check**

Run: `grep -iE "ship|orchestration.md|taste|motion" uiux-optimizer/skills/uiux-optimizer/SKILL.md`
Expected: matches for ship mode, the orchestration.md pointer, taste, and motion.
Run: `grep -n "note briefly" uiux-optimizer/skills/uiux-optimizer/SKILL.md`
Expected: no match (old footnote removed).

- [ ] **Step 6: Commit**

```bash
git add uiux-optimizer/skills/uiux-optimizer/SKILL.md
git commit -m "feat(uiux-optimizer): make SKILL.md the conductor; add ship pipeline mode"
```

---

### Task 3: Update design-advisor agent

**Files:**
- Modify: `uiux-optimizer/agents/design-advisor.md`

- [ ] **Step 1: Define acceptance check**

After the edit: the no-dependencies constraint (`design-advisor.md:182`) is relaxed to the contextual dependency posture; the Explore section notes brand directions are presented alongside taste's system pick (parallel, user reconciles); motion is no longer claimed as this agent's responsibility.

- [ ] **Step 2: Relax the dependency constraint**

Replace the constraint line "Don't suggest adding dependencies (no 'install this design system')" with the dependency posture: prefer zero-dep (CSS, existing system) first; suggest a dependency only when the chosen direction genuinely needs it (e.g. Framer Motion, shadcn) and always flag it explicitly.

- [ ] **Step 3: Note the parallel direction seam**

In Mode: Explore (around `design-advisor.md:60-74`), add a sentence: when the conductor also ran taste-skill, this agent's brand directions are presented in parallel with taste's design-system recommendation; do not attempt to merge them — the user reconciles.

- [ ] **Step 4: Verify the acceptance check**

Run: `grep -niE "framer motion|shadcn|parallel|reconcile" uiux-optimizer/agents/design-advisor.md`
Expected: matches showing the relaxed posture and the parallel note.
Run: `grep -n "Don't suggest adding dependencies" uiux-optimizer/agents/design-advisor.md`
Expected: no match (old blanket rule removed).

- [ ] **Step 5: Commit**

```bash
git add uiux-optimizer/agents/design-advisor.md
git commit -m "feat(uiux-optimizer): relax design-advisor deps rule; note parallel direction seam"
```

---

### Task 4: Bump version + update manifest

**Files:**
- Modify: `uiux-optimizer/.claude-plugin/plugin.json`

- [ ] **Step 1: Define acceptance check**

`version` is `1.2.0`; `description` mentions motion + anti-slop/taste orchestration + pipeline; JSON parses cleanly.

- [ ] **Step 2: Edit plugin.json**

Set `"version": "1.2.0"`. Update `description` to reflect the new capability, e.g.: "UI/UX design advisor — orchestrates reference-driven patterns (refero.design + awesome-design-md), anti-slop taste discipline, and motion choreography across audit/build/explore modes and a gated ship pipeline." Keep `name` and `author` unchanged.

- [ ] **Step 3: Verify the acceptance check**

Run: `python3 -c "import json;d=json.load(open('uiux-optimizer/.claude-plugin/plugin.json'));print(d['version']);assert d['version']=='1.2.0'"`
Expected: prints `1.2.0`, no assertion error.

- [ ] **Step 4: Commit**

```bash
git add uiux-optimizer/.claude-plugin/plugin.json
git commit -m "chore(uiux-optimizer): bump to 1.2.0; update manifest description"
```

---

### Task 5: Validate the plugin

**Files:** none (verification only)

- [ ] **Step 1: Run the plugin validator**

Dispatch the `plugin-dev:plugin-validator` agent against `uiux-optimizer/`. Expected: no structural errors (valid manifest, discoverable skill + agent, well-formed frontmatter).

- [ ] **Step 2: Fix any reported issues**

If the validator flags problems, fix inline and re-run until clean. Commit any fixes with `fix(uiux-optimizer): …`.

---

### Task 6: Merge to main and push (user-authorized)

**Files:** none (git operations)

- [ ] **Step 1: Merge the feature branch into main**

```bash
git checkout main
git merge --no-ff feat/uiux-optimizer-taste-motion -m "Merge feat/uiux-optimizer-taste-motion: taste+motion orchestration"
```

- [ ] **Step 2: Push main**

```bash
git push origin main
```

- [ ] **Step 3: Verify**

Run: `git log --oneline -1 origin/main` (after push) — confirm the merge commit is on the remote.

---

## Manual verification (user runtime, non-blocking)

The orchestrate-external path depends on `npx skills add …` landing the skills where Claude Code scans them. To confirm live orchestration (vs. graceful degradation):
1. `npx skills add Leonxlnx/taste-skill` and `npx skills add LottieFiles/motion-design-skill`.
2. Restart Claude Code; confirm both appear in the available-skills list.
3. Trigger a "ship" pass and confirm taste → design-advisor → motion fire in order.
If the skills don't appear, orchestration silently degrades — which is the designed safe fallback, not a failure.

## Self-Review

- **Spec coverage:** orchestrate-external (Task 2 conductor), enrich+pipeline (Tasks 1-2), parallel seam (Tasks 1, 3), dependency posture (Tasks 1, 3), graceful degradation (Task 1), taste scope (Task 1), version bump (Task 4), files-touched list (all tasks), install-discoverability risk (Manual verification). All covered.
- **Placeholder scan:** none — each task specifies exact content requirements and concrete verify commands.
- **Type/name consistency:** mode name "ship", file `references/orchestration.md`, version `1.2.0`, branch `feat/uiux-optimizer-taste-motion` used consistently across tasks.
