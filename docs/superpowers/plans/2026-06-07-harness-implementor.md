# Harness Implementor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `harness-check` and `harness-improvement` out of the `autoresearch` plugin into a new `harness` plugin, add a `harness_completeness` probe, and add `/harness:build` — a menu-driven scaffolder for four Tier-1 component types (feedback loop, eval loop, sensor, context-mgmt advisory).

**Architecture:** The new `harness` plugin owns the dev-lifecycle harness layer and depends on `autoresearch` for the eval-driven improvement loop primitive (the `experimenter` agent + `experiment-loop` skill stay in autoresearch). `harness:improvement` dispatches `autoresearch:experimenter` via the Agent tool. `lib/probes.sh` and `lib/harness.sh` move from autoresearch to harness; both source `autoresearch/lib/common.sh` via the existing `find ~/.claude/plugins -path '*/...'` pattern, so common helpers stay canonical in autoresearch. State directory `.autoresearch/` continues to be shared (both plugins write `harness.json`, `program.md`, etc., to it).

**Tech Stack:** Bash (POSIX-aware, `set -euo pipefail`), Python 3 for JSON / heuristics, Claude Code plugin manifests, hooks JSON schema. No new runtime deps beyond what autoresearch already uses (`python3`, optional `jq`, optional `gh`, `npx madge` already optional).

---

## File Structure

### New files

```
harness/
├── .claude-plugin/plugin.json
├── README.md
├── CLAUDE.md
├── commands/
│   ├── check.md
│   ├── build.md
│   └── improvement.md
├── lib/
│   ├── probes.sh                       # moved from autoresearch + new probe
│   ├── harness.sh                      # moved from autoresearch + weights update
│   └── build.sh                        # NEW — scaffolder helpers
├── skills/
│   └── harness-probes/SKILL.md         # moved from autoresearch + minor updates
├── templates/harness-components/
│   ├── feedback-loop/
│   │   └── hook.json.tmpl
│   ├── eval-loop/
│   │   └── eval.sh.tmpl
│   └── sensor/
│       ├── sensor.sh.tmpl
│       └── SENSOR.md.tmpl
└── tests/
    ├── test_probe_completeness.sh
    └── test_build_helpers.sh

docs/superpowers/plans/2026-06-07-harness-implementor.md   (this file)
```

### Modified files

```
autoresearch/.claude-plugin/plugin.json    # version bump 1.1.1 → 1.2.0
autoresearch/README.md                     # add "harness moved" note
autoresearch/commands/harness-check.md     # REPLACED with shim
autoresearch/commands/harness-improvement.md  # REPLACED with shim
```

### Removed files

```
autoresearch/lib/probes.sh                 # → harness/lib/probes.sh
autoresearch/lib/harness.sh                # → harness/lib/harness.sh
autoresearch/skills/harness-probes/SKILL.md  # → harness/skills/harness-probes/SKILL.md
```

### Touched files (unchanged content, but exercised by tests)

```
autoresearch/agents/experimenter.md        # invoked cross-plugin by /harness:improvement
autoresearch/skills/experiment-loop/SKILL.md  # read by the experimenter
autoresearch/lib/common.sh                 # sourced cross-plugin by harness/lib/*
autoresearch/lib/eval.sh, experiment-log.sh, dashboard.sh   # unchanged
```

---

## Phase 1 — Plugin scaffold + extraction

### Task 1: Create the `harness` plugin scaffold

**Files:**
- Create: `harness/.claude-plugin/plugin.json`
- Create: `harness/README.md`
- Create: `harness/CLAUDE.md`
- Create: `harness/commands/` (empty directory)
- Create: `harness/lib/` (empty directory)
- Create: `harness/skills/` (empty directory)
- Create: `harness/templates/harness-components/` (empty directory)
- Create: `harness/tests/` (empty directory)

- [ ] **Step 1: Create the plugin directory tree**

```bash
mkdir -p \
  /Users/williamhung/Projects/PersonalPlugins/harness/.claude-plugin \
  /Users/williamhung/Projects/PersonalPlugins/harness/commands \
  /Users/williamhung/Projects/PersonalPlugins/harness/lib \
  /Users/williamhung/Projects/PersonalPlugins/harness/skills \
  /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components \
  /Users/williamhung/Projects/PersonalPlugins/harness/tests
```

- [ ] **Step 2: Write `harness/.claude-plugin/plugin.json`**

```json
{
  "name": "harness",
  "description": "Dev-lifecycle harness builder. Scans for missing feedback loops, sensors, evals, and oversized agents, then scaffolds Tier-1 components into your project's .claude/.",
  "version": "0.1.0",
  "author": {
    "name": "William Hung"
  }
}
```

- [ ] **Step 3: Write `harness/CLAUDE.md`**

```markdown
# harness

Claude Code plugin that builds the dev-lifecycle harness around your agent workflow: feedback loops, eval loops, sensors, and context-mgmt advisories. Extracted from autoresearch — depends on autoresearch for the improvement-loop primitive.

## Standards

- Coding: see `~/.claude/rules/coding-style.md`
- Git: see `~/.claude/rules/git-workflow.md`
- Shell scripts follow POSIX conventions with `set -euo pipefail`
- All bash functions prefixed with `ar_` (shared namespace with autoresearch)

## Project Structure

- `commands/` — `/harness:check`, `/harness:build`, `/harness:improvement`
- `lib/` — `probes.sh` (extended), `harness.sh`, `build.sh`
- `skills/harness-probes/` — guide for adding new probes
- `templates/harness-components/` — Tier-1 templates for feedback / eval / sensor

## Runtime Artifacts

Written into the user's project at:
- `.autoresearch/harness.json` — health scorecard (shared with autoresearch)
- `.claude/hooks/<name>.json` — generated feedback loops
- `eval/<name>.sh` — generated eval scripts
- `.claude/sensors/<name>.sh` + `<name>.SENSOR.md` — generated sensors
- `.claude/harness-report-<date>.md` — context-mgmt advisory reports

## Cross-Plugin Dependency

`harness:improvement` dispatches the `autoresearch:experimenter` subagent via the Agent tool. autoresearch must be installed.
```

- [ ] **Step 4: Write a minimal `harness/README.md` placeholder (full content added in Phase 5)**

```markdown
# harness

Dev-lifecycle harness builder for Claude Code. Extracted from [autoresearch](../autoresearch). Full README arrives at v1.0.

## Commands

- `/harness:check` — scan project health (5 base categories + harness completeness)
- `/harness:build` — menu-driven scaffolder for feedback loops, eval loops, sensors, and context-mgmt advisories
- `/harness:improvement` — auto-fix the top-ranked issue from harness.json (delegates to autoresearch:experimenter)

## Install

Symlink or copy this directory to your Claude Code plugins directory. Requires `autoresearch` installed alongside.
```

- [ ] **Step 5: Verify directory layout**

```bash
tree /Users/williamhung/Projects/PersonalPlugins/harness -L 2
```

Expected: 4 top-level entries (`.claude-plugin/`, `commands/`, `lib/`, `skills/`, `templates/`, `tests/`, plus `README.md`, `CLAUDE.md`). All empty except plugin.json, README.md, CLAUDE.md.

- [ ] **Step 6: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/
git commit -m "feat(harness): scaffold new plugin (empty)"
```

---

### Task 2: Move `lib/probes.sh` from autoresearch to harness (verbatim)

**Files:**
- Create: `harness/lib/probes.sh` (copy of autoresearch/lib/probes.sh, only the source line changes)
- Modify: `autoresearch/lib/probes.sh` (deleted)

- [ ] **Step 1: Copy the file across**

```bash
cp /Users/williamhung/Projects/PersonalPlugins/autoresearch/lib/probes.sh \
   /Users/williamhung/Projects/PersonalPlugins/harness/lib/probes.sh
```

- [ ] **Step 2: Update the `source` line in the new copy**

The original line 6 in autoresearch/lib/probes.sh is:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

Edit `harness/lib/probes.sh` to change this single line to:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

- [ ] **Step 3: Verify shell syntax**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/probes.sh
echo "exit: $?"
```

Expected: `exit: 0` (no syntax errors).

- [ ] **Step 4: Verify functions load and a function runs**

```bash
cd /tmp && mkdir -p harness-probe-smoke && cd harness-probe-smoke && touch package.json && echo '{"name":"x"}' > package.json
source /Users/williamhung/Projects/PersonalPlugins/harness/lib/probes.sh
ar_probe_detect_tooling
```

Expected: a JSON object with keys `lint`, `tests`, `runtime`, `architecture`, `scriptability`. All values null except `architecture: "static"` and `scriptability: "static"`.

- [ ] **Step 5: Delete the autoresearch copy**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins rm autoresearch/lib/probes.sh
```

- [ ] **Step 6: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/probes.sh
git commit -m "refactor(harness): move probes.sh from autoresearch to harness"
```

---

### Task 3: Move `lib/harness.sh` from autoresearch to harness (verbatim, weights update deferred)

**Files:**
- Create: `harness/lib/harness.sh`
- Modify: `autoresearch/lib/harness.sh` (deleted)

- [ ] **Step 1: Copy the file**

```bash
cp /Users/williamhung/Projects/PersonalPlugins/autoresearch/lib/harness.sh \
   /Users/williamhung/Projects/PersonalPlugins/harness/lib/harness.sh
```

- [ ] **Step 2: Update the `source` line on line 6**

Original:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

Replace with:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

- [ ] **Step 3: Update the `probes_lib` resolution in `ar_harness_to_program` (lines ~275–276)**

Original:

```bash
local probes_lib
probes_lib="$(dirname "${BASH_SOURCE[0]}")/probes.sh"
```

Replace with:

```bash
local probes_lib
probes_lib="$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '')"
if [ -z "${probes_lib}" ]; then
  ar_log "ERROR: harness/lib/probes.sh not found in any installed plugin"
  return 1
fi
```

- [ ] **Step 4: Update the rendering hints printed at the bottom of `ar_harness_print_scorecard` (lines ~256–258)**

Original:

```bash
print()
print("  Run: /autoresearch:harness-improvement           (starts #1)")
if len(improvements) >= 2:
    print("  Run: /autoresearch:harness-improvement --rank 2  (starts #2)")
```

Replace with:

```bash
print()
print("  Run: /harness:improvement           (starts #1)")
if len(improvements) >= 2:
    print("  Run: /harness:improvement --rank 2  (starts #2)")
```

- [ ] **Step 5: Verify syntax + load**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/harness.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 6: Delete the autoresearch copy and commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git rm autoresearch/lib/harness.sh
git add harness/lib/harness.sh
git commit -m "refactor(harness): move harness.sh from autoresearch to harness"
```

---

### Task 4: Move the `harness-probes` skill from autoresearch to harness

**Files:**
- Create: `harness/skills/harness-probes/SKILL.md`
- Modify: `autoresearch/skills/harness-probes/SKILL.md` (deleted)

- [ ] **Step 1: Create destination dir + copy file**

```bash
mkdir -p /Users/williamhung/Projects/PersonalPlugins/harness/skills/harness-probes
cp /Users/williamhung/Projects/PersonalPlugins/autoresearch/skills/harness-probes/SKILL.md \
   /Users/williamhung/Projects/PersonalPlugins/harness/skills/harness-probes/SKILL.md
```

- [ ] **Step 2: Update the description frontmatter and any path references inside the skill body**

Open `harness/skills/harness-probes/SKILL.md` and:

- In the frontmatter, change the `description` field to: `"Guide for adding custom probes to the harness check system."` (drop "autoresearch").
- In the body, replace every occurrence of `autoresearch/lib/probes.sh` → `harness/lib/probes.sh` and `autoresearch/lib/harness.sh` → `harness/lib/harness.sh`.

There are exactly two references in the original file (in the "Adding a New Probe" steps): both must be updated.

- [ ] **Step 3: Delete the autoresearch copy**

```bash
git -C /Users/williamhung/Projects/PersonalPlugins rm -r autoresearch/skills/harness-probes
```

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/skills/harness-probes/
git commit -m "refactor(harness): move harness-probes skill from autoresearch to harness"
```

---

### Task 5: Move `commands/harness-check.md` from autoresearch to `harness/commands/check.md`

**Files:**
- Create: `harness/commands/check.md`
- Modify: `autoresearch/commands/harness-check.md` (replaced with shim in Phase 4)

- [ ] **Step 1: Copy the file**

```bash
cp /Users/williamhung/Projects/PersonalPlugins/autoresearch/commands/harness-check.md \
   /Users/williamhung/Projects/PersonalPlugins/harness/commands/check.md
```

- [ ] **Step 2: Update the frontmatter `description` field**

In `harness/commands/check.md`, replace the description with:

```yaml
description: "Scan project health across code quality, tests, runtime, architecture, scriptability, and harness completeness — produces a scored harness report with impact-ranked improvements"
```

- [ ] **Step 3: Update both `source` lines in Step 1 of the command body**

Original (in autoresearch):

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

Replace with:

```bash
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

- [ ] **Step 4: Update Step 7 of the command body to reference the new command name**

Original line near end:

```markdown
> Run `/autoresearch:harness-improvement` to start fixing the top-ranked issue.
```

Replace with:

```markdown
> Run `/harness:improvement` to start fixing the top-ranked issue.
```

- [ ] **Step 5: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/commands/check.md
git commit -m "feat(harness): add /harness:check command (moved from autoresearch)"
```

---

### Task 6: Move `commands/harness-improvement.md` from autoresearch to `harness/commands/improvement.md`

**Files:**
- Create: `harness/commands/improvement.md`
- Modify: `autoresearch/commands/harness-improvement.md` (replaced with shim in Phase 4)

- [ ] **Step 1: Copy the file**

```bash
cp /Users/williamhung/Projects/PersonalPlugins/autoresearch/commands/harness-improvement.md \
   /Users/williamhung/Projects/PersonalPlugins/harness/commands/improvement.md
```

- [ ] **Step 2: Update the frontmatter `description`**

Replace with:

```yaml
description: "Execute improvement loop on the top-ranked harness issue — auto-generates eval from probes and spawns the autoresearch:experimenter agent"
```

- [ ] **Step 3: Update the source block (currently lines 12–18)**

Original:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/eval.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

Replace with:

```bash
source "$(find ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/eval.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

(Only the first two `*/autoresearch/lib/` paths change to `*/harness/lib/`.)

- [ ] **Step 4: Update the recommendation text in Step 2's stale-warning + the harness-check reference**

Original:

```markdown
> No harness report found. Run `/autoresearch:harness-check` first to scan your project.
```

Replace with:

```markdown
> No harness report found. Run `/harness:check` first to scan your project.
```

Original:

```markdown
> ⚠️ Harness report is over 24 hours old. Consider re-running `/autoresearch:harness-check` for fresh results.
```

Replace with:

```markdown
> ⚠️ Harness report is over 24 hours old. Consider re-running `/harness:check` for fresh results.
```

- [ ] **Step 5: Update Step 9 to explicitly name `autoresearch:experimenter`**

Original Step 9 body:

```markdown
Then spawn the experimenter agent using the Agent tool. Pass:
1. The full content of `.autoresearch/program.md`
2. The path to the project root
3. The paths to the lib scripts
4. Instruction to read the experiment-loop skill for the iteration protocol

The experimenter agent handles the edit-eval-keep/discard loop from here. It is defined at `agents/experimenter.md` within the autoresearch plugin.
```

Replace with:

```markdown
Then spawn the experimenter agent using the Agent tool with `subagent_type: "autoresearch:experimenter"`. Pass:
1. The full content of `.autoresearch/program.md`
2. The path to the project root
3. The paths to the lib scripts (harness/lib/probes.sh and harness/lib/harness.sh for probe-based evals, plus autoresearch/lib/* for experiment-log, eval, dashboard)
4. Instruction to read the experiment-loop skill (in autoresearch) for the iteration protocol

The experimenter agent (in autoresearch) handles the edit-eval-keep/discard loop from here.
```

- [ ] **Step 6: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/commands/improvement.md
git commit -m "feat(harness): add /harness:improvement command (moved from autoresearch)"
```

---

### Task 7: Parity smoke check — verify `/harness:check` output matches the old `/autoresearch:harness-check`

This is a manual end-to-end verification before adding new functionality.

**Files:**
- Read-only: existing harness lib files
- Generated: `/tmp/harness-parity/before.txt`, `/tmp/harness-parity/after.txt`

- [ ] **Step 1: Install both plugins into Claude Code's plugins cache so they're discoverable**

If they live in `~/.claude/plugins/` already, skip. Otherwise:

```bash
ln -sfn /Users/williamhung/Projects/PersonalPlugins/autoresearch ~/.claude/plugins/local/autoresearch
ln -sfn /Users/williamhung/Projects/PersonalPlugins/harness ~/.claude/plugins/local/harness
```

- [ ] **Step 2: Pick a target project for the check**

```bash
TARGET=/Users/williamhung/Projects/PersonalPlugins  # autoresearch's own repo — has shell + py files
mkdir -p /tmp/harness-parity
cd "${TARGET}"
```

- [ ] **Step 3: Run the harness library directly (simulating what /harness:check does)**

```bash
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit)"
source "$(find ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit)"
results=$(ar_probe_run_all)
ar_harness_init "${results}"
ar_harness_print_scorecard > /tmp/harness-parity/after.txt 2>&1
cat /tmp/harness-parity/after.txt
```

Expected: a normal scorecard with 5 categories (lint/tests/runtime/architecture/scriptability), no `harness` category yet (added in Phase 2). Numeric scores. No errors in stderr.

- [ ] **Step 4: Compare against git-history snapshot**

Restore a copy of the old probes/harness libs from git HEAD~5 (before the move) into a tmp dir and run them too:

```bash
git -C /Users/williamhung/Projects/PersonalPlugins show HEAD~5:autoresearch/lib/probes.sh > /tmp/old_probes.sh 2>/dev/null || echo "skip — no pre-move commit yet"
```

If pre-move commit doesn't exist (because all of Task 1–6 were just committed), the diff against the old behavior is implicit in the file moves themselves. Mark Step 4 PASSING based on Step 3's clean output.

- [ ] **Step 5: Inspect the harness.json that was generated**

```bash
cat /Users/williamhung/Projects/PersonalPlugins/.autoresearch/harness.json | python3 -m json.tool | head -40
```

Expected: valid JSON, has `project`, `timestamp`, `overall_score`, `probes`, `improvements`. No `harness` key in `probes` (added next phase). Improvements ranked by impact.

- [ ] **Step 6: Clean up state file (it will be regenerated each run)**

```bash
rm -f /Users/williamhung/Projects/PersonalPlugins/.autoresearch/harness.json
```

No commit — this is purely verification. If Step 3 or Step 5 failed, the previous tasks have a bug — go back and fix before proceeding.

---

## Phase 2 — `harness_completeness` probe

### Task 8: Write the probe smoke-test fixture

**Files:**
- Create: `harness/tests/test_probe_completeness.sh`

- [ ] **Step 1: Write the test script**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_probe_completeness.sh <<'EOF'
#!/usr/bin/env bash
# Smoke tests for ar_probe_harness_completeness.
# Run with: bash harness/tests/test_probe_completeness.sh
set -euo pipefail

PROBES_LIB="$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null)"
if [ -z "${PROBES_LIB}" ]; then
  PROBES_LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/probes.sh"
fi
# shellcheck disable=SC1090
source "${PROBES_LIB}"

PASS=0
FAIL=0

assert() {
  local name="$1"
  local cond="$2"
  if eval "${cond}"; then
    echo "  PASS  ${name}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  ${name}  (cond: ${cond})"
    FAIL=$((FAIL + 1))
  fi
}

ORIG_PWD=$(pwd)

# --- Test 1: empty project — every "missing" signal should fire ---
echo "Test 1: empty project"
TMP=$(mktemp -d)
cd "${TMP}"
result=$(ar_probe_harness_completeness "static")
score=$(echo "${result}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["score"])')
category=$(echo "${result}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["category"])')
assert "category is 'harness'" "[ '${category}' = 'harness' ]"
assert "empty project scores < 100" "[ '${score}' -lt 100 ]"
assert "empty project scores >= 0" "[ '${score}' -ge 0 ]"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- Test 2: well-harnessed project — only 'sensor' signal may fire ---
echo "Test 2: project with hooks + evals"
TMP=$(mktemp -d)
cd "${TMP}"
mkdir -p .claude/hooks .claude/sensors eval
echo '{"name":"x"}' > .claude/hooks/x.json
echo '#!/bin/sh' > eval/x.sh
result=$(ar_probe_harness_completeness "static")
score=$(echo "${result}" | python3 -c 'import json,sys; print(json.load(sys.stdin)["score"])')
assert "harnessed project scores >= 80" "[ '${score}' -ge 80 ]"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- Test 3: oversized agent file — context-mgmt signal fires ---
echo "Test 3: oversized agent file"
TMP=$(mktemp -d)
cd "${TMP}"
mkdir -p .claude/agents .claude/hooks .claude/sensors eval
echo '{"name":"x"}' > .claude/hooks/x.json
echo '#!/bin/sh' > eval/x.sh
yes "filler line" | head -350 > .claude/agents/bloated.md
result=$(ar_probe_harness_completeness "static")
findings=$(echo "${result}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(any("bloated.md" in f for f in d["findings"]))')
assert "oversized agent detected in findings" "[ '${findings}' = 'True' ]"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

echo
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
EOF
chmod +x /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_probe_completeness.sh
```

- [ ] **Step 2: Run the test — it should FAIL (probe not implemented yet)**

```bash
bash /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_probe_completeness.sh 2>&1 | head -10
```

Expected: a bash error like `command not found: ar_probe_harness_completeness` OR the assertion failures cascade. Either way, exit non-zero. This confirms we have something to drive.

- [ ] **Step 3: Commit the failing test**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/tests/test_probe_completeness.sh
git commit -m "test(harness): add failing smoke test for harness_completeness probe"
```

---

### Task 9: Implement `ar_probe_harness_completeness` in `harness/lib/probes.sh`

**Files:**
- Modify: `harness/lib/probes.sh` (append new function + register in detection + run_all)

- [ ] **Step 1: Append the new probe function to `harness/lib/probes.sh`**

Open `harness/lib/probes.sh`. After the closing `}` of `ar_probe_scriptability` (around line 798 in the moved copy) and before `ar_probe_run_all`, insert:

```bash
# ---------------------------------------------------------------------------
# ar_probe_harness_completeness <tool>
# Scans the user's project for missing harness components and emits the same
# JSON shape as every other probe. Heuristics are simple, explainable, and
# never call an LLM.
#
# Heuristics:
#   - .claude/hooks/ missing or empty                    → feedback-loop signal
#   - No eval/ dir or no *.sh under eval/                → eval-loop signal
#   - Linter detected but no .claude/sensors/            → sensor signal
#   - .claude/agents/*.md or .claude/skills/*/SKILL.md > 300 lines → context-mgmt
#   - git log --since='6 weeks ago' --grep='fix\|review' --oneline count > 20
#     → reactive-workflow booster (one-shot signal)
# ---------------------------------------------------------------------------
ar_probe_harness_completeness() {
  local tool="${1:-}"

  python3 - <<'PYEOF'
import json
import os
import subprocess

cwd = os.getcwd()

PENALTY_FEEDBACK = 15
PENALTY_EVAL = 15
PENALTY_SENSOR = 10
PENALTY_CONTEXT_PER_FILE = 15
CONTEXT_CAP = 3
PENALTY_REACTIVE = 5
OVERSIZED_LINES = 300

findings = []
fix_targets = []

# --- 1. Feedback loops: any hook configs? ---
hooks_dir = os.path.join(cwd, '.claude', 'hooks')
has_hooks = (
    os.path.isdir(hooks_dir) and
    any(f for f in os.listdir(hooks_dir) if not f.startswith('.'))
) if os.path.isdir(hooks_dir) else False
if not has_hooks:
    findings.append('No .claude/hooks/ — no feedback loops registered')
    fix_targets.append('.claude/hooks/')

# --- 2. Eval loops: any eval scripts? ---
eval_dir = os.path.join(cwd, 'eval')
has_evals = (
    os.path.isdir(eval_dir) and
    any(f.endswith('.sh') for f in os.listdir(eval_dir))
) if os.path.isdir(eval_dir) else False
if not has_evals:
    findings.append('No eval/*.sh scripts — no script-based eval loops')
    fix_targets.append('eval/')

# --- 3. Sensors: linter detected but no .claude/sensors/? ---
# Cheap detection — config files for common linters
linter_present = any(
    os.path.exists(os.path.join(cwd, p))
    for p in (
        '.eslintrc', '.eslintrc.js', '.eslintrc.json',
        'eslint.config.js', 'eslint.config.mjs',
        '.flake8', 'pyproject.toml', '.golangci.yml',
    )
)
sensors_dir = os.path.join(cwd, '.claude', 'sensors')
has_sensors = (
    os.path.isdir(sensors_dir) and
    any(f for f in os.listdir(sensors_dir) if not f.startswith('.'))
) if os.path.isdir(sensors_dir) else False
if linter_present and not has_sensors:
    findings.append('Linter present but no .claude/sensors/ — agent gets raw lint messages')
    fix_targets.append('.claude/sensors/')

# --- 4. Context-mgmt: oversized agent/skill files ---
oversized = []
for sub in ('.claude/agents', '.claude/skills'):
    abs_sub = os.path.join(cwd, sub)
    if not os.path.isdir(abs_sub):
        continue
    for dirpath, _, filenames in os.walk(abs_sub):
        for fname in filenames:
            if not fname.endswith('.md'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, 'r', errors='ignore') as f:
                    line_count = sum(1 for _ in f)
                if line_count > OVERSIZED_LINES:
                    rel = os.path.relpath(fpath, cwd)
                    oversized.append((rel, line_count))
            except Exception:
                pass

oversized = oversized[:CONTEXT_CAP]
for rel, line_count in oversized:
    findings.append(f'{rel}: {line_count} lines (>{OVERSIZED_LINES}) — consider splitting')
    fix_targets.append(rel)

# --- 5. Reactive workflow booster ---
reactive_signal = False
try:
    result = subprocess.run(
        ['git', 'log', '--since=6 weeks ago', '--grep=fix\\|review', '--oneline'],
        capture_output=True, text=True, timeout=10, cwd=cwd,
    )
    if result.returncode == 0:
        count = len([l for l in result.stdout.splitlines() if l.strip()])
        if count > 20:
            findings.append(
                f'{count} fix/review commits in 6 weeks — high reactive load, '
                f'consider a feedback loop'
            )
            reactive_signal = True
except Exception:
    pass

# --- Score ---
score = 100
if not has_hooks:
    score -= PENALTY_FEEDBACK
if not has_evals:
    score -= PENALTY_EVAL
if linter_present and not has_sensors:
    score -= PENALTY_SENSOR
score -= PENALTY_CONTEXT_PER_FILE * len(oversized)
if reactive_signal:
    score -= PENALTY_REACTIVE
score = max(0, min(100, score))

# --- Recommended types (for /harness:build menu annotation later) ---
recommended = []
if not has_hooks:
    recommended.append('feedback')
if not has_evals:
    recommended.append('eval')
if linter_present and not has_sensors:
    recommended.append('sensor')
if oversized:
    recommended.append('context-mgmt')

estimated_iterations = max(1, len(recommended))

result = {
    'category': 'harness',
    'score': score,
    'max': 100,
    'skipped': False,
    'tool': 'static',
    'findings': findings,
    'fix_targets': fix_targets,
    'estimated_iterations': estimated_iterations,
    'recommended': recommended,
}
print(json.dumps(result))
PYEOF
}
```

- [ ] **Step 2: Wire the new probe into `ar_probe_run_all`**

In the same file, edit `ar_probe_run_all` (around line 805). After the existing `ar_log "Running scriptability probe..."` block and before `ar_log "Combining probe results..."`, add:

```bash
  ar_log "Running harness completeness probe..."
  local harness_json
  harness_json=$(ar_probe_harness_completeness "static")
```

Then update the `printf '%s\n%s\n%s\n%s\n%s'` line (around line 847) to include the new variable. Original:

```bash
printf '%s\n%s\n%s\n%s\n%s' "${lint_json}" "${tests_json}" "${runtime_json}" "${arch_json}" "${script_json}" > "${combine_tmpfile}"
```

Replace with:

```bash
printf '%s\n%s\n%s\n%s\n%s\n%s' "${lint_json}" "${tests_json}" "${runtime_json}" "${arch_json}" "${script_json}" "${harness_json}" > "${combine_tmpfile}"
```

- [ ] **Step 3: Verify shell syntax**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/probes.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 4: Run the smoke test — it should PASS now**

```bash
bash /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_probe_completeness.sh
```

Expected output ends with `Passed: 5  Failed: 0` and exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/probes.sh
git commit -m "feat(harness): implement ar_probe_harness_completeness"
```

---

### Task 10: Add `harness` to weights and labels in `lib/harness.sh`

**Files:**
- Modify: `harness/lib/harness.sh`

- [ ] **Step 1: Add `harness` to `WEIGHTS` dict in `ar_harness_init`**

Open `harness/lib/harness.sh`, find the `WEIGHTS` dict (around line 43). Original:

```python
WEIGHTS = {
    'runtime': 1.5,
    'architecture': 1.2,
    'scriptability': 1.1,
    'lint': 1.0,
    'tests': 1.0,
}
```

Replace with:

```python
WEIGHTS = {
    'runtime': 1.5,
    'architecture': 1.2,
    'scriptability': 1.1,
    'harness': 1.0,
    'lint': 1.0,
    'tests': 1.0,
}
```

- [ ] **Step 2: Add `harness` to `LABELS` in `ar_harness_print_scorecard`**

Find the `LABELS` dict (around line 193). Original:

```python
LABELS = {
    'lint': 'Code Quality',
    'tests': 'Tests',
    'runtime': 'Runtime Health',
    'architecture': 'Architecture',
    'scriptability': 'Scriptability',
}
```

Replace with:

```python
LABELS = {
    'lint': 'Code Quality',
    'tests': 'Tests',
    'runtime': 'Runtime Health',
    'architecture': 'Architecture',
    'scriptability': 'Scriptability',
    'harness': 'Harness Completeness',
}
```

- [ ] **Step 3: Repeat the LABELS update in `ar_harness_to_program`**

Find the duplicate `LABELS` dict at the top of `ar_harness_to_program`'s Python block (around line 311). Apply the same replacement (add `'harness': 'Harness Completeness'`).

- [ ] **Step 4: Verify syntax**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/harness.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 5: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/harness.sh
git commit -m "feat(harness): register harness category in weights + labels"
```

---

### Task 11: End-to-end verification — run `/harness:check` against the PersonalPlugins repo

**Files:**
- Read-only

- [ ] **Step 1: Run the harness flow from a target project directory**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit)"
source "$(find ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit)"
results=$(ar_probe_run_all)
ar_harness_init "${results}"
ar_harness_print_scorecard
```

Expected: scorecard now includes a row labeled `Harness Completeness` with a numeric score and a finding count. The `Top improvements by impact` section should still be sorted; harness may or may not appear in the top 3 depending on score.

- [ ] **Step 2: Inspect harness.json**

```bash
python3 -c "
import json
with open('.autoresearch/harness.json') as f:
    d = json.load(f)
print('harness probe present:', 'harness' in d['probes'])
print('harness score:', d['probes'].get('harness', {}).get('score'))
print('harness findings:', d['probes'].get('harness', {}).get('findings', [])[:5])
"
```

Expected: `harness probe present: True`, a numeric score, a list of findings (this repo has hooks/sensors/evals missing in most subdirs).

- [ ] **Step 3: Clean up + verify nothing leaked**

```bash
rm -f /Users/williamhung/Projects/PersonalPlugins/.autoresearch/harness.json
```

No commit — verification only. Move to Phase 3.

---

## Phase 3 — `/harness:build` command + templates

### Task 12: Author the feedback-loop Tier-1 template

**Files:**
- Create: `harness/templates/harness-components/feedback-loop/hook.json.tmpl`

- [ ] **Step 1: Write the template**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/feedback-loop/hook.json.tmpl <<'EOF'
{
  "_tier": "Tier 1 — a single hook that posts the principle as a reminder. Tier 2 → split into <name>-detect + <name>-respond when the principle branches. Tier 3 → extract to a subagent when invocation becomes multi-step.",
  "_principle": "{{PRINCIPLE}}",
  "{{EVENT}}": [
    {
      "matcher": "{{MATCHER}}",
      "hooks": [
        {
          "type": "command",
          "command": "echo 'REMINDER: {{PRINCIPLE}}' >&2"
        }
      ]
    }
  ]
}
EOF
```

- [ ] **Step 2: Verify it's valid JSON template (placeholders resolved)**

```bash
sed -e 's/{{EVENT}}/PostToolUse/g' \
    -e 's/{{MATCHER}}/Edit/g' \
    -e 's/{{PRINCIPLE}}/All TypeScript functions must have explicit return types/g' \
    /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/feedback-loop/hook.json.tmpl \
  | python3 -m json.tool
```

Expected: pretty-printed JSON, no error.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/templates/harness-components/feedback-loop/
git commit -m "feat(harness): add feedback-loop Tier-1 template"
```

---

### Task 13: Author the eval-loop Tier-1 template

**Files:**
- Create: `harness/templates/harness-components/eval-loop/eval.sh.tmpl`

- [ ] **Step 1: Write the template**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/eval-loop/eval.sh.tmpl <<'EOF'
#!/usr/bin/env bash
# Tier 1 — a single eval that prints one JSON line.
# Tier 2 → break into multiple sub-checks aggregated into the JSON.
# Tier 3 → extract a subagent if eval needs multi-step reasoning.
#
# What this evaluates: {{DESCRIPTION}}
# Scope: {{SCOPE}}
# Pass criterion: {{CRITERION}}
#
# Output contract (one JSON line on stdout):
#   {"pass": true|false, "metric": <number>, "reason": "<short string>"}
#
# Usage as the eval_command in /autoresearch:improve:
#   /autoresearch:improve "<goal>"
#   eval/{{NAME}}.sh

set -euo pipefail

# --- Replace this block with the actual check ---
# Example stub: always passes with metric=1.
pass=true
metric=1
reason="stub — replace with real check for: {{CRITERION}}"

printf '{"pass": %s, "metric": %s, "reason": "%s"}\n' "${pass}" "${metric}" "${reason}"
EOF
```

- [ ] **Step 2: Verify the rendered template is valid bash**

```bash
sed -e 's/{{DESCRIPTION}}/no untyped functions/g' \
    -e 's/{{SCOPE}}/whole repo/g' \
    -e 's/{{CRITERION}}/grep returns 0 matches/g' \
    -e 's/{{NAME}}/no_untyped_fns/g' \
    /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/eval-loop/eval.sh.tmpl \
  | bash -n /dev/stdin
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/templates/harness-components/eval-loop/
git commit -m "feat(harness): add eval-loop Tier-1 template"
```

---

### Task 14: Author the sensor Tier-1 template (script + SENSOR.md)

**Files:**
- Create: `harness/templates/harness-components/sensor/sensor.sh.tmpl`
- Create: `harness/templates/harness-components/sensor/SENSOR.md.tmpl`

- [ ] **Step 1: Write the sensor script template**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/sensor/sensor.sh.tmpl <<'EOF'
#!/usr/bin/env bash
# Tier 1 — a single sensor wrapping one linter rule with an agent-tuned fix message.
# Tier 2 → wrap multiple related rules in one sensor when they share a fix idiom.
# Tier 3 → extract into a custom plugin/extension for the linter.
#
# Linter:  {{LINTER}}
# Rule:    {{RULE}}
# Agent-tuned fix message: {{MESSAGE}}
#
# Behavior: runs the linter, filters to {{RULE}}, rewrites each finding line
# with the agent-tuned message. Output is plain text (one finding per line).

set -euo pipefail

LINTER="{{LINTER}}"
RULE="{{RULE}}"
FIX_MESSAGE="{{MESSAGE}}"

case "${LINTER}" in
  eslint)
    npx eslint --format compact . 2>&1 \
      | grep -F "${RULE}" \
      | awk -v msg="${FIX_MESSAGE}" '{printf "%s\n  AGENT-FIX: %s\n", $0, msg}'
    ;;
  ruff)
    ruff check --select "${RULE}" . 2>&1 \
      | awk -v msg="${FIX_MESSAGE}" '/^[^[:space:]]/ {print; printf "  AGENT-FIX: %s\n", msg}'
    ;;
  *)
    echo "SENSOR ERROR: linter '${LINTER}' not supported by this Tier-1 template" >&2
    exit 1
    ;;
esac
EOF
```

- [ ] **Step 2: Write the SENSOR.md doc template**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/sensor/SENSOR.md.tmpl <<'EOF'
# Sensor: {{NAME}}

**Tier 1 sensor.** Tier 2 → expand to multiple related rules. Tier 3 → custom linter plugin.

## What it catches
- Linter: `{{LINTER}}`
- Rule: `{{RULE}}`

## Agent-tuned fix message
> {{MESSAGE}}

## How it runs
This sensor is a shell script at `.claude/sensors/{{NAME}}.sh`. It wraps the
existing linter run, filters output to the chosen rule, and appends an
`AGENT-FIX:` line after each finding with concrete action guidance the agent
can act on without further inference.

## How to invoke
Add this to a hook, or run on demand:

```bash
.claude/sensors/{{NAME}}.sh
```

## When to escalate
- The fix idiom now branches → split into two sensors (Tier 2 split).
- Multiple rules share the fix idiom → group them in one sensor (Tier 2 grow).
- The "fix message" needs to read the surrounding code → escalate to a subagent (Tier 3).
EOF
```

- [ ] **Step 3: Verify both templates substitute cleanly**

```bash
sed -e 's/{{NAME}}/no_var/g' \
    -e 's/{{LINTER}}/eslint/g' \
    -e 's/{{RULE}}/no-var/g' \
    -e 's|{{MESSAGE}}|Replace var with const if never reassigned, else let|g' \
    /Users/williamhung/Projects/PersonalPlugins/harness/templates/harness-components/sensor/sensor.sh.tmpl \
  | bash -n /dev/stdin
echo "sensor.sh exit: $?"
```

Expected: `sensor.sh exit: 0`.

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/templates/harness-components/sensor/
git commit -m "feat(harness): add sensor Tier-1 template (script + SENSOR.md)"
```

---

### Task 15: Implement `harness/lib/build.sh` — feedback-loop scaffolder

**Files:**
- Create: `harness/lib/build.sh`

- [ ] **Step 1: Write the initial `lib/build.sh` with the feedback-loop function**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh <<'EOF'
#!/usr/bin/env bash
# Tier-1 scaffolders for /harness:build.
# Each ar_harness_build_<type> writes one (or two) files into the CWD's .claude/
# (or eval/) and prints the absolute paths of the created files on stdout.

set -euo pipefail

# Resolve harness templates dir regardless of where this is sourced from.
ar_harness_templates_dir() {
  find ~/.claude/plugins -path '*/harness/templates/harness-components' -print -quit 2>/dev/null
}

# Source common helpers (for ar_log).
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"

# ---------------------------------------------------------------------------
# ar_harness_build_feedback_loop <name> <event> <matcher> <principle>
# Generates .claude/hooks/<name>.json from the feedback-loop template.
# ---------------------------------------------------------------------------
ar_harness_build_feedback_loop() {
  local name="$1"
  local event="$2"
  local matcher="$3"
  local principle="$4"

  local tmpl_dir
  tmpl_dir=$(ar_harness_templates_dir)
  if [ -z "${tmpl_dir}" ]; then
    ar_log "ERROR: harness templates not found"
    return 1
  fi

  mkdir -p .claude/hooks
  local out=".claude/hooks/${name}.json"

  # Substitute. Use python so we don't have to worry about sed-escaping the principle text.
  python3 - "${tmpl_dir}/feedback-loop/hook.json.tmpl" "${out}" \
    "${event}" "${matcher}" "${principle}" <<'PYEOF'
import sys
src, dst, event, matcher, principle = sys.argv[1:6]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{EVENT}}', event)
  .replace('{{MATCHER}}', matcher)
  .replace('{{PRINCIPLE}}', principle.replace("'", "\\'")))
with open(dst, 'w') as f:
    f.write(content)
PYEOF

  echo "$(pwd)/${out}"
}
EOF
chmod +x /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
```

- [ ] **Step 2: Syntax check**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 3: Smoke test the feedback-loop builder in a tmp dir**

```bash
TMP=$(mktemp -d) && cd "${TMP}"
source /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
ar_harness_build_feedback_loop \
  "require-return-types" \
  "PostToolUse" \
  "Edit" \
  "All TypeScript functions must have explicit return types"
echo "--- generated hook ---"
cat .claude/hooks/require-return-types.json
python3 -m json.tool < .claude/hooks/require-return-types.json > /dev/null && echo "JSON valid"
cd - && rm -rf "${TMP}"
```

Expected: prints the absolute path of the generated file, the file contents (a valid JSON hook config with the placeholders substituted), and `JSON valid`.

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/build.sh
git commit -m "feat(harness): add ar_harness_build_feedback_loop to lib/build.sh"
```

---

### Task 16: Add `ar_harness_build_eval_loop` to `lib/build.sh`

**Files:**
- Modify: `harness/lib/build.sh`

- [ ] **Step 1: Append the function to `harness/lib/build.sh`**

Open the file and append before EOF:

```bash
# ---------------------------------------------------------------------------
# ar_harness_build_eval_loop <name> <description> <scope> <criterion>
# Generates eval/<name>.sh from the eval-loop template.
# ---------------------------------------------------------------------------
ar_harness_build_eval_loop() {
  local name="$1"
  local description="$2"
  local scope="$3"
  local criterion="$4"

  local tmpl_dir
  tmpl_dir=$(ar_harness_templates_dir)
  if [ -z "${tmpl_dir}" ]; then
    ar_log "ERROR: harness templates not found"
    return 1
  fi

  mkdir -p eval
  local out="eval/${name}.sh"

  python3 - "${tmpl_dir}/eval-loop/eval.sh.tmpl" "${out}" \
    "${name}" "${description}" "${scope}" "${criterion}" <<'PYEOF'
import sys
src, dst, name, description, scope, criterion = sys.argv[1:7]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{NAME}}', name)
  .replace('{{DESCRIPTION}}', description)
  .replace('{{SCOPE}}', scope)
  .replace('{{CRITERION}}', criterion))
with open(dst, 'w') as f:
    f.write(content)
PYEOF

  chmod +x "${out}"
  echo "$(pwd)/${out}"
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 3: Smoke test**

```bash
TMP=$(mktemp -d) && cd "${TMP}"
source /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
ar_harness_build_eval_loop \
  "no_var_decl" \
  "No 'var' declarations in source files" \
  "whole repo" \
  "grep -r '\\bvar ' src/ returns 0 matches"
echo "--- generated eval ---"
cat eval/no_var_decl.sh
bash -n eval/no_var_decl.sh && echo "bash syntax OK"
./eval/no_var_decl.sh | python3 -m json.tool && echo "JSON output OK"
cd - && rm -rf "${TMP}"
```

Expected: prints the path, the generated script content, `bash syntax OK`, and a pretty-printed JSON object with `pass`, `metric`, `reason` fields.

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/build.sh
git commit -m "feat(harness): add ar_harness_build_eval_loop"
```

---

### Task 17: Add `ar_harness_build_sensor` to `lib/build.sh`

**Files:**
- Modify: `harness/lib/build.sh`

- [ ] **Step 1: Append the sensor builder**

```bash
# ---------------------------------------------------------------------------
# ar_harness_build_sensor <name> <linter> <rule> <message>
# Generates .claude/sensors/<name>.sh + .claude/sensors/<name>.SENSOR.md.
# ---------------------------------------------------------------------------
ar_harness_build_sensor() {
  local name="$1"
  local linter="$2"
  local rule="$3"
  local message="$4"

  local tmpl_dir
  tmpl_dir=$(ar_harness_templates_dir)
  if [ -z "${tmpl_dir}" ]; then
    ar_log "ERROR: harness templates not found"
    return 1
  fi

  mkdir -p .claude/sensors
  local script_out=".claude/sensors/${name}.sh"
  local doc_out=".claude/sensors/${name}.SENSOR.md"

  python3 - "${tmpl_dir}/sensor/sensor.sh.tmpl" "${script_out}" \
    "${name}" "${linter}" "${rule}" "${message}" <<'PYEOF'
import sys
src, dst, name, linter, rule, message = sys.argv[1:7]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{NAME}}', name)
  .replace('{{LINTER}}', linter)
  .replace('{{RULE}}', rule)
  .replace('{{MESSAGE}}', message))
with open(dst, 'w') as f:
    f.write(content)
PYEOF
  chmod +x "${script_out}"

  python3 - "${tmpl_dir}/sensor/SENSOR.md.tmpl" "${doc_out}" \
    "${name}" "${linter}" "${rule}" "${message}" <<'PYEOF'
import sys
src, dst, name, linter, rule, message = sys.argv[1:7]
with open(src) as f:
    content = f.read()
content = (content
  .replace('{{NAME}}', name)
  .replace('{{LINTER}}', linter)
  .replace('{{RULE}}', rule)
  .replace('{{MESSAGE}}', message))
with open(dst, 'w') as f:
    f.write(content)
PYEOF

  echo "$(pwd)/${script_out}"
  echo "$(pwd)/${doc_out}"
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 3: Smoke test**

```bash
TMP=$(mktemp -d) && cd "${TMP}"
source /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
ar_harness_build_sensor \
  "no_var" \
  "eslint" \
  "no-var" \
  "Replace var with const if never reassigned, else let"
echo "--- sensor.sh ---"
cat .claude/sensors/no_var.sh | head -20
echo "--- SENSOR.md ---"
cat .claude/sensors/no_var.SENSOR.md | head -20
bash -n .claude/sensors/no_var.sh && echo "sensor.sh syntax OK"
cd - && rm -rf "${TMP}"
```

Expected: both files generated, no placeholders remain, `sensor.sh syntax OK`.

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/build.sh
git commit -m "feat(harness): add ar_harness_build_sensor"
```

---

### Task 18: Add `ar_harness_build_context_report` to `lib/build.sh`

**Files:**
- Modify: `harness/lib/build.sh`

- [ ] **Step 1: Append the advisory-report generator**

```bash
# ---------------------------------------------------------------------------
# ar_harness_build_context_report
# Walks .claude/agents and .claude/skills for agent/skill files exceeding
# 300 lines and writes a Markdown advisory report at
# .claude/harness-report-YYYY-MM-DD.md. Never auto-edits agent files.
# ---------------------------------------------------------------------------
ar_harness_build_context_report() {
  mkdir -p .claude
  local out=".claude/harness-report-$(ar_date).md"

  python3 - "${out}" <<'PYEOF'
import os
import re
import sys

out_path = sys.argv[1]
cwd = os.getcwd()
OVERSIZED_LINES = 300

oversized = []
for sub in ('.claude/agents', '.claude/skills'):
    abs_sub = os.path.join(cwd, sub)
    if not os.path.isdir(abs_sub):
        continue
    for dirpath, _, filenames in os.walk(abs_sub):
        for fname in filenames:
            if not fname.endswith('.md'):
                continue
            fpath = os.path.join(dirpath, fname)
            try:
                with open(fpath, 'r', errors='ignore') as f:
                    lines = f.readlines()
                if len(lines) > OVERSIZED_LINES:
                    # Heuristic: count top-level (## or #) headings as "responsibilities"
                    headings = [
                        l.strip() for l in lines
                        if re.match(r'^#{1,2}\s+\S', l) and 'frontmatter' not in l.lower()
                    ]
                    oversized.append({
                        'path': os.path.relpath(fpath, cwd),
                        'lines': len(lines),
                        'headings': headings[:8],
                    })
            except Exception:
                pass

with open(out_path, 'w') as f:
    f.write('# Harness Context-Mgmt Report\n\n')
    if not oversized:
        f.write('No agent/skill files exceed 300 lines. Nothing to recommend.\n')
    else:
        f.write(f'{len(oversized)} file(s) exceed 300 lines. Suggested splits below.\n\n')
        for item in oversized:
            f.write(f"## `{item['path']}` ({item['lines']} lines)\n\n")
            if item['headings']:
                f.write('**Top-level sections in this file:**\n\n')
                for h in item['headings']:
                    f.write(f'- {h}\n')
                f.write('\n')
                f.write(
                    '**Suggested split:** group sections that share a noun '
                    '(e.g. all sections about "input" → one file; all about '
                    '"output" → another). Aim for each split to stay below '
                    '300 lines and own one responsibility.\n\n'
                )
            else:
                f.write(
                    '**Suggested split:** no clear section structure found. '
                    'Add `## Section` headings to expose responsibilities, '
                    'then split.\n\n'
                )

print(out_path)
PYEOF
}
```

- [ ] **Step 2: Syntax check**

```bash
bash -n /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
echo "exit: $?"
```

Expected: `exit: 0`.

- [ ] **Step 3: Smoke test**

```bash
TMP=$(mktemp -d) && cd "${TMP}"
mkdir -p .claude/agents
yes "padding line" | head -350 > .claude/agents/bloated.md
echo "## Section A
content
## Section B
more content
$(yes 'pad' | head -340)" > .claude/agents/structured.md
source /Users/williamhung/Projects/PersonalPlugins/harness/lib/build.sh
ar_harness_build_context_report
echo "--- report ---"
cat .claude/harness-report-*.md
cd - && rm -rf "${TMP}"
```

Expected: report prints both files, with the "structured" file showing `Section A` and `Section B` headings, and the "bloated" file showing the no-structure fallback advice.

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/lib/build.sh
git commit -m "feat(harness): add ar_harness_build_context_report"
```

---

### Task 19: Implement the `/harness:build` command orchestration

**Files:**
- Create: `harness/commands/build.md`

- [ ] **Step 1: Write the command file**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/commands/build.md <<'EOF'
---
description: "Menu-driven scaffolder for harness components — feedback loop, eval loop, sensor, or context-mgmt advisory. Writes Tier-1 artifacts into your project's .claude/."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
---

# /harness:build

You are the build command for the harness plugin. Your job is to help the user
scaffold one harness component at the simplest possible Tier-1 shape.

## Step 1: Source libraries

```bash
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/harness/lib/build.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

## Step 2: Run the harness-completeness probe silently

```bash
advice_json=$(ar_probe_harness_completeness "static")
recommended=$(echo "${advice_json}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d.get('recommended', [])))")
echo "RECOMMENDED: ${recommended}"
```

Parse the comma-separated `recommended` list. It will contain zero or more of:
`feedback`, `eval`, `sensor`, `context-mgmt`.

## Step 3: Present the menu

Use AskUserQuestion with a single question. The header is "Component type".
Construct option labels by annotating each with " (recommended)" if the type
appears in `recommended`. Keep the four options in the same order every time.
The user's pick determines the next step.

Options:
1. Feedback loop — hook on a Claude Code event that posts a domain principle
2. Eval loop — script that returns JSON `{pass, metric, reason}`
3. Sensor — wrap a linter, emit agent-tuned fix messages
4. Context-mgmt — generate an advisory report of oversized agent/skill files

## Step 4: Run the focused intake for the chosen type

### If feedback loop

Ask 3 questions via AskUserQuestion (one per call OR a single 3-question batch — your call):

- Q1 (header "Event"): Which Claude Code event? Options: `UserPromptSubmit`, `Stop`, `PostToolUse`, `PreToolUse`.
- Q2 (header "Matcher"): What tool/pattern should fire? Default: `Edit`. Accept free-text.
- Q3 (header "Principle"): One-line description of the principle to enforce. Free-text.

Then call:

```bash
name="<derived from principle, slugified, max 40 chars>"  # e.g. 'all-ts-fns-have-return-types'
ar_harness_build_feedback_loop "${name}" "${event}" "${matcher}" "${principle}"
```

### If eval loop

Ask 3 questions:

- Q1 (header "Description"): What does this eval measure? Free-text.
- Q2 (header "Scope"): single file, whole repo, or command output? Multiple choice.
- Q3 (header "Criterion"): pass/fail criterion in plain English. Free-text.

Then call:

```bash
name="<slugified description>"
ar_harness_build_eval_loop "${name}" "${description}" "${scope}" "${criterion}"
```

### If sensor

Ask 3 questions:

- Q1 (header "Linter"): which linter? Default to the project's detected linter (from `ar_probe_detect_tooling`). Multiple choice: `eslint`, `ruff`, or "other (specify)".
- Q2 (header "Rule"): rule code or category. Free-text.
- Q3 (header "Message"): the agent-tuned fix message. Free-text.

Then call:

```bash
name="<slugified rule>"
ar_harness_build_sensor "${name}" "${linter}" "${rule}" "${message}"
```

### If context-mgmt

No intake. Just call:

```bash
ar_harness_build_context_report
```

## Step 5: Summarize what was created

Read each output path printed by the builder. Print to the user:

> Created at <path>:
> - <one-line description of the artifact>
>
> Tier-1 scaffold complete. The upgrade ladder is documented inline in the file.
> Reload Claude Code (or restart your session) to pick up new .claude/ entries.

## Important notes

- Always produce Tier-1 only. Never emit a Tier-2 or Tier-3 scaffold.
- Never edit existing files in `.claude/agents/` or `.claude/skills/` — even for context-mgmt, only the advisory report is written.
- If the user types a component name that already exists at the destination, ask before overwriting (use AskUserQuestion: overwrite / pick new name).
- Always confirm the destination path before writing, e.g. "I'll write `.claude/hooks/<name>.json` — OK?"
EOF
```

- [ ] **Step 2: Verify the command file parses as valid markdown with frontmatter**

```bash
python3 -c "
import re
with open('/Users/williamhung/Projects/PersonalPlugins/harness/commands/build.md') as f:
    body = f.read()
m = re.match(r'^---\n(.*?\n)---\n', body, re.S)
assert m, 'frontmatter missing'
fm = m.group(1)
assert 'description:' in fm
assert 'allowed-tools:' in fm
print('frontmatter OK')
"
```

Expected: `frontmatter OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/commands/build.md
git commit -m "feat(harness): add /harness:build command"
```

---

## Phase 4 — Deprecation shims in autoresearch

### Task 20: Replace `autoresearch/commands/harness-check.md` with a shim

**Files:**
- Modify: `autoresearch/commands/harness-check.md` (replace entire content)

- [ ] **Step 1: Overwrite with shim content**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/autoresearch/commands/harness-check.md <<'EOF'
---
description: "[DEPRECATED] Moved to /harness:check. This alias forwards or instructs install."
allowed-tools: ["Read", "Bash"]
---

# /autoresearch:harness-check (deprecated alias)

This command has moved to the `harness` plugin.

## Step 1: Check whether `harness` is installed

```bash
harness_check=$(find ~/.claude/plugins -path '*/harness/commands/check.md' -print -quit 2>/dev/null)
if [ -z "${harness_check}" ]; then
  install_status="missing"
else
  install_status="installed"
fi
echo "STATUS: ${install_status}"
```

## Step 2: Tell the user

If `STATUS: installed`, print:

> ⚠️  `/autoresearch:harness-check` has moved to `/harness:check`. This alias will be removed in autoresearch 2.0. Forwarding now...

Then dispatch the new command in your next response (do **not** try to source the harness libs directly from here — just instruct the user to run `/harness:check` and stop).

If `STATUS: missing`, print:

> ⚠️  `/autoresearch:harness-check` has moved to a new plugin called `harness`. Install it from the PersonalPlugins repo (sibling of autoresearch) and then run `/harness:check`. This alias will be removed in autoresearch 2.0.

Stop.
EOF
```

- [ ] **Step 2: Verify**

```bash
head -3 /Users/williamhung/Projects/PersonalPlugins/autoresearch/commands/harness-check.md
```

Expected: shows the `---` frontmatter starting with the deprecated description.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add autoresearch/commands/harness-check.md
git commit -m "refactor(autoresearch): convert harness-check to deprecation shim"
```

---

### Task 21: Replace `autoresearch/commands/harness-improvement.md` with a shim

**Files:**
- Modify: `autoresearch/commands/harness-improvement.md` (replace entire content)

- [ ] **Step 1: Overwrite with shim content**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/autoresearch/commands/harness-improvement.md <<'EOF'
---
description: "[DEPRECATED] Moved to /harness:improvement. This alias forwards or instructs install."
allowed-tools: ["Read", "Bash"]
---

# /autoresearch:harness-improvement (deprecated alias)

This command has moved to the `harness` plugin.

## Step 1: Check whether `harness` is installed

```bash
harness_imp=$(find ~/.claude/plugins -path '*/harness/commands/improvement.md' -print -quit 2>/dev/null)
if [ -z "${harness_imp}" ]; then
  install_status="missing"
else
  install_status="installed"
fi
echo "STATUS: ${install_status}"
```

## Step 2: Tell the user

If `STATUS: installed`, print:

> ⚠️  `/autoresearch:harness-improvement` has moved to `/harness:improvement`. This alias will be removed in autoresearch 2.0. Run `/harness:improvement` to proceed.

Stop.

If `STATUS: missing`, print:

> ⚠️  `/autoresearch:harness-improvement` has moved to a new plugin called `harness`. Install it from the PersonalPlugins repo (sibling of autoresearch) and then run `/harness:improvement`. This alias will be removed in autoresearch 2.0.

Stop.
EOF
```

- [ ] **Step 2: Verify**

```bash
head -3 /Users/williamhung/Projects/PersonalPlugins/autoresearch/commands/harness-improvement.md
```

Expected: shim frontmatter.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add autoresearch/commands/harness-improvement.md
git commit -m "refactor(autoresearch): convert harness-improvement to deprecation shim"
```

---

### Task 22: Update `autoresearch/README.md` to point at the harness plugin

**Files:**
- Modify: `autoresearch/README.md`

- [ ] **Step 1: Edit the README in place**

Open `autoresearch/README.md`. Locate the section header `### /autoresearch:harness-check — Auto-discover project health` (currently around line 23).

Replace the entire block from `### /autoresearch:harness-check — Auto-discover project health` through the end of `### /autoresearch:harness-improvement — Auto-fix top issues` (currently lines 23–74) with the following single section:

```markdown
### Harness-related commands have moved to the `harness` plugin

The previous `/autoresearch:harness-check` and `/autoresearch:harness-improvement` commands now live in a sibling plugin called `harness`. The deprecated aliases will be removed in autoresearch 2.0.

- `/harness:check` — same project scorecard plus a new `Harness Completeness` category
- `/harness:build` — menu-driven scaffolder for feedback loops, evals, sensors, and context-mgmt advisories (new)
- `/harness:improvement` — same auto-fix flow; delegates the loop to `autoresearch:experimenter`

Install the `harness` plugin from the same PersonalPlugins repo.
```

- [ ] **Step 2: Update the "Typical workflow" section (currently around line 76)**

Find the existing block:

```markdown
## Typical workflow

```
/autoresearch:harness-check          # 1. See what's wrong
/autoresearch:harness-improvement    # 2. Auto-fix the worst issue
/autoresearch:harness-check          # 3. Re-check, see improvement
/autoresearch:harness-improvement    # 4. Fix the next issue
```
```

Replace with:

```markdown
## Typical workflow

```
/harness:check          # 1. See what's wrong (lives in the harness plugin)
/harness:improvement    # 2. Auto-fix the worst issue (delegates to autoresearch)
/harness:check          # 3. Re-check, see improvement
/harness:improvement    # 4. Fix the next issue
```
```

- [ ] **Step 3: Remove the "Adding custom probes" section at the bottom**

The section `## Adding custom probes` referencing the moved `harness-probes` skill should be removed (it now lives in the harness plugin). Delete those 3 lines.

- [ ] **Step 4: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add autoresearch/README.md
git commit -m "docs(autoresearch): redirect harness commands to harness plugin"
```

---

### Task 23: Bump autoresearch version to 1.2.0

**Files:**
- Modify: `autoresearch/.claude-plugin/plugin.json`

- [ ] **Step 1: Edit `version` field**

Open `autoresearch/.claude-plugin/plugin.json` and change `"version": "1.1.1"` to `"version": "1.2.0"`.

- [ ] **Step 2: Verify**

```bash
python3 -c "
import json
with open('/Users/williamhung/Projects/PersonalPlugins/autoresearch/.claude-plugin/plugin.json') as f:
    d = json.load(f)
assert d['version'] == '1.2.0', d
print('version OK')
"
```

Expected: `version OK`.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add autoresearch/.claude-plugin/plugin.json
git commit -m "chore(autoresearch): bump to 1.2.0 (harness moved out)"
```

---

## Phase 5 — Integration test + finalize

### Task 24: End-to-end test of `/harness:improvement` against a sample project

**Files:**
- Read-only

- [ ] **Step 1: Set up a tmp project with one easy-to-fix harness gap**

```bash
TMP=$(mktemp -d) && cd "${TMP}"
git init -q
mkdir -p src
echo "function add(a, b) { return a + b }" > src/index.js
echo '{"name":"tmp","version":"1.0.0"}' > package.json
git add . && git -c user.email=dev@x.local -c user.name=dev commit -q -m "init"
```

- [ ] **Step 2: Run the harness check by sourcing the libs directly**

```bash
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit)"
source "$(find ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit)"
results=$(ar_probe_run_all)
ar_harness_init "${results}"
ar_harness_print_scorecard
```

Expected: scorecard shows `Harness Completeness` row with a moderate score (this project has no `.claude/` or `eval/`).

- [ ] **Step 3: Try to generate a program.md for the harness rank**

```bash
python3 -c "
import json
with open('.autoresearch/harness.json') as f:
    d = json.load(f)
ranks = [(i['rank'], i['category']) for i in d['improvements']]
print(ranks)
"
```

Identify the rank number of the `harness` category from the printed list. Then:

```bash
ar_harness_to_program <rank-of-harness>
cat .autoresearch/program.md
```

Expected: a program.md with goal "Improve Harness Completeness from <score>/100…", target files list (paths from `fix_targets`), an eval command, and stopping conditions. No errors.

- [ ] **Step 4: Confirm the experimenter agent is dispatchable cross-plugin**

This step is **manual** — there's no scripted way to test the Agent tool dispatch from a non-interactive shell. Mark this passing by inspection of the Agent tool's available subagent types: `autoresearch:experimenter` must appear in the list. If it does (as documented in the harness:improvement command Step 9), the dispatch will work at runtime.

If you want a stronger check, invoke `/harness:improvement` from an interactive Claude Code session against this tmp project and confirm the experimenter starts iterating.

- [ ] **Step 5: Cleanup**

```bash
cd - && rm -rf "${TMP}"
```

No commit — verification only. If anything failed, go back to the affected task.

---

### Task 25: Write the smoke test for the build helpers and add to `harness/tests/`

**Files:**
- Create: `harness/tests/test_build_helpers.sh`

- [ ] **Step 1: Write the test**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_build_helpers.sh <<'EOF'
#!/usr/bin/env bash
# Smoke tests for all four ar_harness_build_* functions.
set -euo pipefail

BUILD_LIB="$(find ~/.claude/plugins -path '*/harness/lib/build.sh' -print -quit 2>/dev/null)"
if [ -z "${BUILD_LIB}" ]; then
  BUILD_LIB="$(cd "$(dirname "$0")/.." && pwd)/lib/build.sh"
fi
# shellcheck disable=SC1090
source "${BUILD_LIB}"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

ORIG_PWD=$(pwd)

# --- feedback loop ---
echo "Test: feedback loop"
TMP=$(mktemp -d)
cd "${TMP}"
ar_harness_build_feedback_loop 'test-fb' 'PostToolUse' 'Edit' 'no untyped fns' >/dev/null
assert "hook file exists" "[ -f '${TMP}/.claude/hooks/test-fb.json' ]"
assert "hook is valid JSON" "python3 -m json.tool < '${TMP}/.claude/hooks/test-fb.json' >/dev/null"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- eval loop ---
echo "Test: eval loop"
TMP=$(mktemp -d)
cd "${TMP}"
ar_harness_build_eval_loop 'test-eval' 'descr' 'whole repo' 'criterion' >/dev/null
assert "eval file exists" "[ -f '${TMP}/eval/test-eval.sh' ]"
assert "eval is executable" "[ -x '${TMP}/eval/test-eval.sh' ]"
assert "eval is valid bash" "bash -n '${TMP}/eval/test-eval.sh'"
out_json=$("${TMP}/eval/test-eval.sh")
assert "eval prints valid JSON" "echo '${out_json}' | python3 -m json.tool >/dev/null"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- sensor ---
echo "Test: sensor"
TMP=$(mktemp -d)
cd "${TMP}"
ar_harness_build_sensor 'test-sensor' 'eslint' 'no-var' 'use let/const' >/dev/null
assert "sensor script exists" "[ -f '${TMP}/.claude/sensors/test-sensor.sh' ]"
assert "sensor doc exists"    "[ -f '${TMP}/.claude/sensors/test-sensor.SENSOR.md' ]"
assert "sensor script is bash" "bash -n '${TMP}/.claude/sensors/test-sensor.sh'"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

# --- context report ---
echo "Test: context report"
TMP=$(mktemp -d)
cd "${TMP}"
mkdir -p .claude/agents
yes "padding line" | head -350 > .claude/agents/bloated.md
ar_harness_build_context_report >/dev/null
reports=( "${TMP}"/.claude/harness-report-*.md )
assert "report file exists" "[ -f '${reports[0]}' ]"
assert "report mentions bloated.md" "grep -q bloated.md '${reports[0]}'"
cd "${ORIG_PWD}"
rm -rf "${TMP}"

echo
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
EOF
chmod +x /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_build_helpers.sh
```

- [ ] **Step 2: Run the test**

```bash
bash /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_build_helpers.sh
```

Expected output ends with `Passed: 11  Failed: 0` (2 feedback + 4 eval + 3 sensor + 2 context = 11 asserts). Exit 0.

- [ ] **Step 3: Commit**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/tests/test_build_helpers.sh
git commit -m "test(harness): add smoke tests for ar_harness_build_* helpers"
```

---

### Task 26: Finalize the harness README + bump version to 1.0.0

**Files:**
- Modify: `harness/README.md`
- Modify: `harness/.claude-plugin/plugin.json`

- [ ] **Step 1: Rewrite `harness/README.md`**

```bash
cat > /Users/williamhung/Projects/PersonalPlugins/harness/README.md <<'EOF'
# harness

A Claude Code plugin that builds the dev-lifecycle harness around your agent workflow. Inspired by [OpenAI — Harness Engineering](https://openai.com/index/harness-engineering/). Extracted from [autoresearch](../autoresearch) — depends on it for the improvement-loop primitive.

## Commands

### `/harness:check` — Scan project health

Same five base categories autoresearch's harness-check used to provide (Code Quality, Tests, Runtime, Architecture, Scriptability) **plus** a new `Harness Completeness` category that flags missing harness components.

```
/harness:check
```

### `/harness:build` — Scaffold a Tier-1 harness component

Menu-driven. Pick one of:

1. **Feedback loop** — a Claude Code hook that posts a domain principle on an event
2. **Eval loop** — a shell script returning `{"pass": bool, "metric": n, "reason": "..."}`
3. **Sensor** — a linter wrapper that rewrites findings into agent-tuned fix messages
4. **Context-mgmt** — a Markdown advisory report on oversized agent/skill files

Every generated artifact is **Tier 1** (single file) and embeds an inline upgrade ladder documenting when to escalate to Tier 2 / 3.

```
/harness:build
```

### `/harness:improvement` — Auto-fix the top-ranked issue

Reads `harness.json` from `/harness:check`, generates an experiment spec, dispatches `autoresearch:experimenter`. Same dashboard, same loop, just routed through the new plugin.

```
/harness:improvement              # fix top-ranked
/harness:improvement --rank 2     # fix second-ranked
/harness:improvement --focus tests
```

## Typical workflow

```
/harness:check          # 1. See what's missing
/harness:build          # 2. Add the harness component the project needs most
/harness:check          # 3. Re-check, see the harness score rise
/harness:improvement    # 4. Auto-fix the next non-harness issue
```

## Tier-1 principle

Every generated component opens at the **simplest viable shape** — a single file. The file documents how to escalate. We never auto-generate Tier 2 or Tier 3 scaffolds.

## Runtime artifacts

| File | Purpose |
|---|---|
| `.autoresearch/harness.json` | Health scorecard (shared state with autoresearch) |
| `.claude/hooks/<name>.json` | Generated feedback loops |
| `eval/<name>.sh` | Generated eval scripts |
| `.claude/sensors/<name>.sh`, `.SENSOR.md` | Generated sensors |
| `.claude/harness-report-<date>.md` | Context-mgmt advisory reports |

## Install

```bash
ln -sfn $(pwd)/harness ~/.claude/plugins/local/harness
# autoresearch must also be installed
```

## Adding custom probes

See `skills/harness-probes/SKILL.md`.
EOF
```

- [ ] **Step 2: Bump version**

Edit `harness/.claude-plugin/plugin.json` and change `"version": "0.1.0"` to `"version": "1.0.0"`.

- [ ] **Step 3: Verify**

```bash
python3 -c "
import json
with open('/Users/williamhung/Projects/PersonalPlugins/harness/.claude-plugin/plugin.json') as f:
    d = json.load(f)
assert d['version'] == '1.0.0', d
print('version OK')
"
```

Expected: `version OK`.

- [ ] **Step 4: Commit + tag**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
git add harness/README.md harness/.claude-plugin/plugin.json
git commit -m "chore(harness): finalize README + bump to 1.0.0"
```

---

## Final verification

After all 26 tasks are complete:

- [ ] **All tests pass:**

```bash
bash /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_probe_completeness.sh
bash /Users/williamhung/Projects/PersonalPlugins/harness/tests/test_build_helpers.sh
```

Both should print `Passed: N  Failed: 0` and exit 0.

- [ ] **`/harness:check` runs against the PersonalPlugins repo and shows the harness category:**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
source "$(find ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit)"
source "$(find ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit)"
results=$(ar_probe_run_all)
ar_harness_init "${results}"
ar_harness_print_scorecard | grep -q "Harness Completeness" && echo "OK"
rm -f .autoresearch/harness.json
```

Expected: `OK`.

- [ ] **All four build helpers produce valid artifacts** (proven by Task 25's smoke test).

- [ ] **Autoresearch deprecation shims load without error** (visual inspection — both shim files have valid frontmatter and a Step 1 / Step 2 body).

- [ ] **Git log shows clear, scoped commits** (one logical change per commit, ~26 commits total).

```bash
git -C /Users/williamhung/Projects/PersonalPlugins log --oneline | head -30
```
