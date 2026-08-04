# WOOP Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an experimental `woop` plugin that installs a WOOP critical-thinking commit-lens into the dev lifecycle — one engine, four modes, an always-on adversarial obstacle-hunter subagent, terminal INSIGHT output, ask-per-run persistence.

**Architecture:** A single model-invocable skill (`skills/woop/SKILL.md`) holds the shared W‑O‑O‑P spine; four `references/<mode>.md` files carry per-mode framing (progressive disclosure). A thin `/woop` command is the discoverable door (mode-hint picker via AskUserQuestion + arg passthrough). The Obstacle step always dispatches a read-only `agents/obstacle-hunter.md` subagent. Fully self-contained — no hooks, no cross-plugin deps.

**Tech Stack:** Claude Code plugin (markdown skill/command/agent + JSON manifests), Bash conformance test, repo `scripts/cicd.sh` GEN/VERIFY doc pipeline.

## Global Constraints

- Plugin name `woop`; version `0.1.0` in BOTH `.claude-plugin/plugin.json` and `marketplace.json` (kept equal).
- Category `review`; author `William Hung`.
- Reference bundled files via `${CLAUDE_PLUGIN_ROOT}`; lib→sibling via `$(dirname "${BASH_SOURCE[0]}")` (none needed here — no libs).
- Never reach across plugin boundaries; no `find ~/.claude/plugins`.
- `marketplace.json` and `content/plugins.content.json` MUST stay in lockstep or GEN throws. Commands/skills are auto-harvested — do NOT list them in content.
- Never hand-edit `CATALOG.md`, `*/README.md`, `site/data/plugins.json`; regenerate via `./scripts/cicd.sh GEN`.
- Obstacle rule: an obstacle must be attachable to an if-then trigger; non-actionable ones stay visible, flagged "no if-then". No env-var config knobs.

---

### Task 1: Plugin manifest scaffold

**Files:**
- Create: `woop/.claude-plugin/plugin.json`

**Interfaces:**
- Produces: the plugin dir + manifest that GEN/marketplace reference.

- [ ] **Step 1: Write `woop/.claude-plugin/plugin.json`** — `{ name: "woop", description: <one-line commit-lens tagline>, version: "0.1.0", author: { name: "William Hung" } }`, mirroring `session-learner/.claude-plugin/plugin.json`.
- [ ] **Step 2: Verify** — `python3 -c "import json;json.load(open('woop/.claude-plugin/plugin.json'))"` exits 0.

---

### Task 2: The WOOP skill engine

**Files:**
- Create: `woop/skills/woop/SKILL.md`

**Interfaces:**
- Consumes: `references/<mode>.md` (Task 3), `obstacle-hunter` agent (Task 5).
- Produces: the W‑O‑O‑P run contract the command (Task 4) and tests (Task 6) rely on.

- [ ] **Step 1: Frontmatter** — `name: woop`; `description:` model-invoked with rich distinct triggers (one per branch, no synonym duplication): pre-mortem before shipping, pressure-test a conclusion/decision, triage a live incident, turn a retro into if-then commitments. Front-load the leading word **WOOP**.
- [ ] **Step 2: Body — the spine.** Sections in order: leading words (**essence-wish**, **if-then reflex**); the **Obstacle rule**; **mode resolution** (3-tier: arg → picker → auto-detect-suggest-only); then the four steps W→O→O→P where the second O **always dispatches the obstacle-hunter subagent** and keeps only rule-passing obstacles; then the **terminal WOOP INSIGHT block** (house FACT/ASSUME/INSIGHT/SUGGEST); then **persist prompt** (ask y/n → write `docs/woop/YYYY-MM-DD-<mode>-<slug>.md` with the Section-7 record format).
- [ ] **Step 3: Completion criteria baked into steps** — W blocks until a surface→essence reframing is named; every kept obstacle carries an `If … then …`; degrade-loud note if the subagent is unavailable.
- [ ] **Step 4: Verify** — frontmatter parses (has `name`+`description`); body contains all four W/O/O/P section headers and the persist-path template. (Checked mechanically in Task 6.)

---

### Task 3: Per-mode reference files

**Files:**
- Create: `woop/skills/woop/references/prevent.md`
- Create: `woop/skills/woop/references/decide.md`
- Create: `woop/skills/woop/references/firefight.md`
- Create: `woop/skills/woop/references/retro.md`

**Interfaces:**
- Consumes: mode name from SKILL.md.
- Produces: per-mode essence-wish reframing prompt + the obstacle-family lens the subagent is told to hunt.

- [ ] **Step 1:** Each file = (a) the moment it fires, (b) how surface-wish reframes to essence-wish in that mode, (c) the obstacle family (prevent→systemic failure modes; decide→confounders that make the conclusion wrong; firefight→rigid playbooks/wasted golden time; retro→why lessons don't stick), (d) one worked mini-example.
- [ ] **Step 2: Verify** — all four files exist and name their obstacle family (Task 6 checks).

---

### Task 4: The `/woop` command (discoverable door)

**Files:**
- Create: `woop/commands/woop.md`

**Interfaces:**
- Consumes: `$ARGUMENTS` (optional mode), the woop skill.
- Produces: user-facing entry.

- [ ] **Step 1: Frontmatter** — `description` (human-facing one-liner), `argument-hint: "[prevent|decide|firefight|retro]"`, `allowed-tools: ["AskUserQuestion"]`.
- [ ] **Step 2: Body** — if `$ARGUMENTS` names a valid mode → invoke the woop skill in that mode; if empty → show the mode-hint picker (the four modes with one-line descriptions) via AskUserQuestion, then invoke the skill with the chosen mode. Single source of truth: the command routes, the skill does the work.
- [ ] **Step 3: Verify** — frontmatter parses; body references all four mode names (Task 6).

---

### Task 5: Obstacle-hunter subagent

**Files:**
- Create: `woop/agents/obstacle-hunter.md`

**Interfaces:**
- Consumes: essence-wish + outcome + plan/context + mode (from SKILL.md).
- Produces: ranked obstacles — each with description, why-it-bites, impact×likelihood, `actionable?`, if-then trigger seed.

- [ ] **Step 1: Frontmatter** — `name: obstacle-hunter`; `description:` "Adversarial red-teamer for the WOOP Obstacle step … Do not invoke directly — the woop skill dispatches it."; `tools: ["Read","Grep","Glob","Bash","WebSearch"]` (read-only, no Write/Edit); `model: sonnet`.
- [ ] **Step 2: System prompt** — brief: "You are NOT invested in this plan. Find what makes it fail." Per-mode obstacle lens. Apply the Obstacle rule (mark each actionable y/n + trigger seed). Return ranked structured markdown; propose only — the main thread commits the plan.
- [ ] **Step 3: Verify** — frontmatter parses; tools list has no Write/Edit (Task 6).

---

### Task 6: Conformance tests

**Files:**
- Create: `woop/tests/test_woop_conformance.sh`
- Create: `woop/tests/README.md`

**Interfaces:**
- Consumes: the created plugin files.
- Produces: a deterministic structural gate (mirrors `session-learner/tests/`).

- [ ] **Step 1:** `set -euo pipefail`, `assert()` helper (same shape as `session-learner/tests/test_card_conformance.sh`). Assert: plugin.json valid + version `0.1.0`; SKILL.md has `name`+`description` and all four W/O/O/P headers + persist-path template; 4 reference files exist; command references 4 modes; obstacle-hunter tools exclude Write/Edit; no `find ~/.claude/plugins` anywhere in the plugin.
- [ ] **Step 2: Run** — `bash woop/tests/test_woop_conformance.sh` → `Passed: N Failed: 0`, exit 0.

---

### Task 7: Wire into marketplace + content, regenerate docs

**Files:**
- Modify: `.claude-plugin/marketplace.json` (append plugin entry)
- Modify: `content/plugins.content.json` (append `woop` entry under `plugins`)

**Interfaces:**
- Consumes: all prior tasks.
- Produces: catalog/README/site entries (generated).

- [ ] **Step 1:** Append to `marketplace.json.plugins`: `{ name:"woop", source:"./woop", description:<same as plugin.json>, version:"0.1.0", strict:true }`.
- [ ] **Step 2:** Append `woop` under `content/plugins.content.json.plugins`: `tagline`, `summary`, `category:"review"`, `dependsOn:[]`, `config:[]`. (No commands/skills listed — auto-harvested.)
- [ ] **Step 3: Regenerate** — `./scripts/cicd.sh GEN` (writes CATALOG/README/site).
- [ ] **Step 4: Full gate** — `./scripts/cicd.sh VERIFY` → tests + doc-sync check pass.
- [ ] **Step 5: Commit** — `git add woop docs/superpowers .claude-plugin/marketplace.json content/plugins.content.json CATALOG.md woop/README.md site` then `git commit -m "feat(woop): experimental WOOP critical-thinking commit-lens plugin"`.

---

## Self-Review

**Spec coverage:** §1 purpose→Tasks 2-3; §2 model/leading-words/Obstacle-rule→Task 2; §3 four modes→Task 3; §4 surface/components→Tasks 1,2,4,5; §5 data flow→Task 2; §6 subagent contract→Task 5; §7 output+persistence→Task 2; §8 edge cases→Task 2 step 3; §9 testing→Task 6; §10 wiring→Tasks 1,7; §11 non-goals→Global Constraints. No gaps.

**Placeholder scan:** `<mode>`/`<slug>`/`<same as plugin.json>` are intentional format tokens; no TBD/TODO.

**Type consistency:** mode names `prevent|decide|firefight|retro` and agent name `obstacle-hunter` used identically across Tasks 2-7; version `0.1.0` and category `review` consistent.
