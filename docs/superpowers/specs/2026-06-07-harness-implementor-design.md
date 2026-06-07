# Harness Implementor — Design Spec

**Date:** 2026-06-07
**Status:** Approved (brainstorm), pending implementation plan
**Inspired by:** [OpenAI — Harness Engineering](https://openai.com/index/harness-engineering/)

## Summary

Extend the autoresearch toolkit with a **harness implementor**: a menu-driven scaffolder that builds single-job, dev-lifecycle harness components (feedback loops, eval loops, sensors, context-management advisories). To make the layering clean, extract the existing `harness-*` commands out of the `autoresearch` plugin into a new `harness` plugin. autoresearch retains its core improvement-loop primitive (`/autoresearch:improve`, the `experimenter` agent, the `experiment-loop` skill). The new plugin depends on autoresearch; autoresearch has no dependency on harness.

## Goals

1. Help the user build the four named harness-component types from a single menu-driven command.
2. Each generated component starts at the **simplest viable shape (Tier 1, single file)**, with the upgrade path documented inline.
3. Discovery: a new `harness_completeness` probe scans the project for missing harness pieces; advice surfaces as annotations on the build menu and as a 6th category in `harness-check`.
4. Preserve the existing improvement loop unchanged. Reuse the `experimenter` agent across plugins.
5. No breaking change for current autoresearch users: deprecation shims forward old commands for 1–2 releases.

## Non-Goals

- No automatic MCP server generation.
- No git history rewriting, no PR comment posting.
- Context-mgmt component is **advisory only** — never auto-splits agent/skill files.
- No new component types beyond the four listed.
- No cross-language eval plugin system in MVP — templates are bash/POSIX first.

## Architecture

### Plugin split

- **`autoresearch` (existing, slimmed):**
  - `/autoresearch:improve` (generic edit-eval-keep/discard loop)
  - `experimenter` agent (reused by harness)
  - `experiment-loop` skill (reused by harness)
  - Legacy shims for `harness-check` and `harness-improvement` (deprecation period)

- **`harness` (new plugin):**
  - `/harness:check` — extracted from autoresearch, extended with a `harness_completeness` probe
  - `/harness:build` — **new**, menu-driven scaffolder for the four component types
  - `/harness:improvement` — extracted from autoresearch; delegates execution to autoresearch's `experimenter` agent
  - Templates for the four component types under `templates/harness-components/`

### Dependency direction

`harness` → `autoresearch` (one-way). The harness plugin invokes autoresearch's `experimenter` via the Agent tool with a fully prepared `program.md`. autoresearch never references harness.

### Probe library reuse

`lib/probes.sh` (currently in autoresearch) is the host for the new `harness_completeness` probe. To avoid duplication, move the probe library into the `harness` plugin and have autoresearch source it via the same `find ~/.claude/plugins -path '*/.../lib/...'` pattern already used by the agents. (Decision recorded in §Implementation Phases — Phase 1.)

## `/harness:check` (extended)

Same scorecard shape as today, with a 6th category appended.

### New probe: `harness_completeness`

**Inputs:** project root.
**Output:** the same JSON shape every probe emits (`category`, `score`, `max`, `skipped`, `tool`, `findings`, `fix_targets`, `estimated_iterations`).

**Heuristics** (all simple, all explainable, no LLM calls):

| Signal | Detection | Per-finding penalty | Maps to component |
|---|---|---|---|
| No feedback loops | `.claude/hooks/` empty or absent | 15 | feedback loop |
| No script-based eval | No `eval/` dir; no `*.sh` eval registered in any local `program.md` | 15 | eval loop |
| Linter present but no agent-tuned messages | Linter detected by existing detection AND no `.claude/sensors/` AND no `SENSOR.md` files in repo | 10 | sensor |
| Oversized agent/skill | `.claude/agents/*.md` or `.claude/skills/*/SKILL.md` > 300 lines | 15 each (capped at 3) | context-mgmt |
| Reactive workflow signal | `git log --since='6 weeks ago' --grep='fix\|review' --oneline` count > 20 | 5 (one-shot) | feedback loop (booster) |
| PR comment repetition | If `gh` available: top recurring 5-gram across recent PR comments has frequency ≥ 5 | 5 (one-shot) | feedback loop (booster) |

**Score:** start at 100, deduct per finding above, clamp `[0, 100]`.

**`fix_targets`:** the directory or file paths the signal points at (e.g., `.claude/hooks/` for the missing-hooks signal).

**`estimated_iterations`:** number of distinct component types recommended (1–4).

The `harness_completeness` probe is added to `ar_probe_run_all` and registered in `ar_harness_init`'s category weights (suggested weight: `1.0`, on par with `lint`/`tests`).

## `/harness:build` (new command)

### Flow

1. **Source probes lib + run `harness_completeness` silently.** Collect the per-type advice — which of the four component types are recommended and why.
2. **Render the menu** with annotations:
   ```
   What do you want to build?

   1. Feedback loop      ← recommended: 8 commits in last 6 weeks match "fix null check"
   2. Eval loop          ← recommended: no eval/ directory found
   3. Sensor             ← available
   4. Context-mgmt       ← recommended: 2 agent files exceed 300 lines (list below)
   ```
3. **User picks one** (via `AskUserQuestion`).
4. **Run focused intake** — 2–3 questions tailored to the chosen type (specified below).
5. **Generate Tier-1 scaffold** — a single file (or 1 + companion) using the template for that type. Substitute user inputs into placeholders.
6. **Write to `.claude/`** in the user's project root.
7. **Print reload hint** + summary: what was created, what event/condition it responds to, where the upgrade-path docs are.

### Intake questions per type

**Feedback loop:**
- Q1: Which event should this fire on? (`UserPromptSubmit`, `Stop`, `PostToolUse`, `PreToolUse`)
- Q2: One-line description of the principle this loop enforces (e.g., "no untyped function signatures in TypeScript files")
- Q3: (optional, default skip) Filter pattern — restrict to certain file types or tool names

**Eval loop:**
- Q1: What does this eval measure? (free-text, becomes the `reason` template)
- Q2: Will it run on a single file, on the whole repo, or against a command's output?
- Q3: Pass/fail criterion in plain English (becomes a stub comment + suggested check)

**Sensor:**
- Q1: Which linter does it wrap? (auto-detected default from existing tooling detection)
- Q2: Which rule code or category to specialize on? (free-text)
- Q3: The replacement message — what should the agent be told to do? (free-text)

**Context-mgmt:**
- No intake. The command runs the probe sub-routine that lists oversized/multi-responsibility files and writes an advisory report directly.

### Generated artifacts (Tier 1, simplest viable)

All paths relative to the user's project root.

| Type | Files | Notes |
|---|---|---|
| Feedback loop | `.claude/hooks/<name>.json` | Hook config with a single matcher and an inline command that prints the principle as a reminder. Optional companion `.claude/skills/<name>/SKILL.md` if intake principle > 200 chars. |
| Eval loop | `eval/<name>.sh` | POSIX shell; prints JSON `{"pass": bool, "metric": number, "reason": string}`. Includes a `# Tier 1 — single check.` ladder comment. Registered in user-facing docstring so `/autoresearch:improve` can use it as `eval_command`. |
| Sensor | `.claude/sensors/<name>.sh` + `.claude/sensors/<name>.SENSOR.md` | Shell wraps the existing linter, filters to chosen rule, rewrites messages using the agent-facing fix string. `SENSOR.md` documents what it catches and the replacement message. |
| Context-mgmt | `.claude/harness-report-YYYY-MM-DD.md` | Markdown advisory: each oversized file gets a section with current size, top-level responsibilities (heuristic: count distinct H1/H2/`---` block headers), and 1–2 proposed splits. |

Every generated file (except the context-mgmt report) opens with a **tier ladder comment**:

```
# Tier 1 — <one-sentence description of the simplest form>.
# Tier 2 → <when and how to escalate>.
# Tier 3 → <when to extract into a richer component>.
```

This puts the upgrade path in front of whoever maintains the file, so we don't need separate docs for it.

## `/harness:improvement` (extracted)

No behavior change from current `/autoresearch:harness-improvement`. Implementation detail:

- The command lives in `harness/commands/improvement.md`.
- It reads `harness.json`, picks a target, builds `program.md`, then **spawns autoresearch's `experimenter` agent via the `Agent` tool**, passing all required context (program.md content, project root, lib paths).
- Autoresearch must continue to publish the `experimenter` subagent type in its plugin manifest so it remains discoverable cross-plugin.

## Migration

- Autoresearch 1.x keeps `/autoresearch:harness-check` and `/autoresearch:harness-improvement` as **deprecation shim commands**.
- Each shim prints:
  > `/autoresearch:harness-check` has moved to the `harness` plugin. Run `/harness:check` instead. This alias will be removed in autoresearch 2.0.
- If the `harness` plugin is installed, the shim forwards by invoking the new command (using the Skill / command-invocation pattern available to Claude Code). Otherwise it instructs the user to install harness and exits.
- Plan window: keep shims for **two minor releases** of autoresearch after harness 1.0 ships.

## Simplest-First Principle

Two layers:

1. **For the user (this plugin's design):** the build command always generates Tier 1. Generator does not produce Tier 2/3. Users escalate when the inline ladder comment is satisfied.
2. **For generated components (the agents we scaffold):** templates are bash-first, file-count minimized, no abstraction unless the intake demands it. Comments are minimal; only the tier ladder is mandatory.

## Implementation Phases

(Detail for the writing-plans skill to expand into an executable plan.)

1. **Phase 1 — Plugin scaffold + extraction.**
   - Create `harness/` plugin with `plugin.json`, `README.md`, `commands/`, `agents/` (empty), `skills/` (empty), `lib/`, `templates/`.
   - Move `lib/probes.sh`, `lib/harness.sh` from autoresearch to harness.
   - Move `commands/harness-check.md` and `commands/harness-improvement.md` from autoresearch to harness, renaming to `commands/check.md`, `commands/improvement.md`. Adjust source paths.
   - Verify parity: existing tests on the harness flow still pass.
2. **Phase 2 — `harness_completeness` probe.**
   - Implement `ar_probe_harness_completeness` in `harness/lib/probes.sh` per §heuristics.
   - Wire into `ar_probe_run_all` and `ar_harness_init` weights.
   - Add to scorecard rendering.
3. **Phase 3 — `/harness:build` command + templates.**
   - Implement the menu/intake flow in `harness/commands/build.md`.
   - Author four Tier-1 templates under `harness/templates/harness-components/`.
   - Implement the context-mgmt advisory generator (no template — direct file walker).
4. **Phase 4 — Deprecation shims in autoresearch.**
   - Replace `autoresearch/commands/harness-check.md` and `harness-improvement.md` with shim bodies that print the redirect message and forward (or instruct install).
   - Update autoresearch README to point at the harness plugin.
5. **Phase 5 — Cross-plugin integration test.**
   - `/harness:improvement` → spawns autoresearch's `experimenter` → runs at least one iteration → dashboard renders.

## Risks & Open Questions

- **Probe library extraction risk:** the autoresearch loop may rely on `lib/probes.sh` for ad-hoc evals. Phase 1 must audit cross-references before moving.
- **Hook syntax churn:** Claude Code hook config format may evolve. Templates should reference current docs at generation time. (Mitigation: use the `claude-code-guide` agent during template authoring to fetch current hook schema.)
- **gh CLI optional:** PR-comment heuristic in `harness_completeness` skips silently when `gh` is missing.
- **Cross-plugin agent invocation:** confirm that the `Agent` tool can dispatch a subagent type published by a different installed plugin. If not, `harness:improvement` must instead `source` the experimenter loop logic directly. Validate during Phase 5.

## Out of Scope (explicit)

- LLM-as-judge variants of any probe.
- A web UI for the build menu (terminal only).
- Auto-installation of `gh` or other prerequisites.
- Versioning of generated components.
- Cross-machine sync of `.claude/`.
