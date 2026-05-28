# Harness Check & Harness Improvement — Design Spec

**Date:** 2026-04-12
**Status:** Draft
**Plugin:** autoresearch

## Summary

Two new slash commands for the autoresearch plugin that auto-discover project health metrics and execute improvement loops without manual configuration.

- `/autoresearch:harness-check` — scans an AI-generated project, runs probes across 4 categories, produces a scored harness report with impact-ranked improvement recommendations.
- `/autoresearch:harness-improvement` — reads the harness report, auto-generates a `program.md`, and spawns the existing experimenter agent to run the edit-eval-keep/discard loop.

**Inspiration:**
- [OpenAI — Harness Engineering](https://openai.com/index/harness-engineering/) — golden principles, recurring cleanup agents, entropy/garbage collection, agent legibility
- [Anthropic — Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) — GAN-inspired generator/evaluator separation, evaluator tuning, harness simplification

## Architecture: Probe-Based Discovery + Reuse Existing Loop

```
harness-check                          harness-improvement
┌─────────────┐                       ┌──────────────────┐
│ Probe: lint  │──┐                   │ Read harness.json │
│ Probe: test  │──┤ aggregate →       │ Pick top focus    │
│ Probe: runtime──┤ scorecard →       │ Generate program.md│
│ Probe: arch  │──┘ harness.json      │ Spawn experimenter│
└─────────────┘                       └──────────────────┘
```

Probes serve double duty: they are the discovery mechanism in `harness-check` AND the eval command in `harness-improvement`. The same probe that found a score of 68% becomes the eval that the experimenter re-runs after each iteration.

## Probe System

Each probe is a self-contained shell function in `lib/probes.sh` that:

1. **Detects** if it's relevant (skip if no config exists for that tooling)
2. **Runs** a check and captures output
3. **Returns** structured JSON: `{ "category", "score", "max", "findings": [...], "fix_targets": [...] }`

### Initial Probe Set (4 categories)

| Probe | What it checks | Detection method |
|---|---|---|
| `ar_probe_lint` | Lint errors | Auto-detect: eslint, ruff, flake8, clippy, golangci-lint via config files |
| `ar_probe_tests` | Test coverage + failures | Auto-detect: jest, pytest, cargo test, go test via package.json/pyproject.toml/Cargo.toml |
| `ar_probe_runtime` | App starts, endpoints respond, no console errors | Auto-detect: dev server script in package.json. Start server, then: (1) curl known routes from package.json proxy/API config, (2) curl common conventions (`/`, `/health`, `/api`). Playwright is NOT used by the probe — curl-only keeps probes lightweight and dependency-free. |
| `ar_probe_architecture` | Circular imports, oversized files, dead exports | Static analysis: file sizes, `madge` for JS/TS circular deps, grep for unused exports |

A probe that can't detect its tooling returns `{ "score": null, "skipped": true, "reason": "no eslint config found" }`.

### Scoring & Impact Ranking

Score per probe: 0-100.

Impact ranking formula:

```
impact = (100 - score) × weight × fixability
```

- `weight`: runtime (1.5) > architecture (1.2) > code quality (1.0) > tests (1.0)
- `fixability`: inverse of estimated effort, calculated as `10 / estimated_iterations` (capped at 1.0). Fewer iterations needed = higher fixability.

### Estimated Iterations Heuristic

Each probe estimates iterations based on findings count and severity:

| Category | Estimation rule |
|---|---|
| lint | 1 iteration per 5 findings (lint fixes are mechanical) |
| tests | 1 iteration per coverage gap file + 1 per failing test |
| runtime | 2 iterations per failing endpoint + 1 per console error |
| architecture | 3 iterations per circular dependency, 1 per oversized file |

## Artifacts

### `.autoresearch/harness.json`

```json
{
  "version": "1.0",
  "project": "my-project",
  "checked_at": "2026-04-12T09:30:00Z",
  "probes": {
    "lint": {
      "score": 72, "max": 100, "skipped": false,
      "tool": "eslint",
      "findings": [
        { "file": "src/api/routes.ts", "line": 45, "rule": "no-unused-vars", "severity": "warn" }
      ],
      "fix_targets": ["src/api/routes.ts", "src/utils/helpers.ts"]
    },
    "tests": {
      "score": 68, "max": 100, "skipped": false,
      "tool": "jest",
      "findings": [
        { "type": "coverage_gap", "file": "src/services/auth.ts", "coverage": 12 },
        { "type": "failing", "test": "auth.test.ts > login flow", "error": "timeout" }
      ],
      "fix_targets": ["src/services/auth.ts", "src/__tests__/auth.test.ts"]
    },
    "runtime": { "score": 45, "max": 100, "skipped": false },
    "architecture": { "score": 88, "max": 100, "skipped": false }
  },
  "summary": {
    "overall_score": 68,
    "ranked_improvements": [
      {
        "rank": 1,
        "category": "runtime",
        "impact_score": 82.5,
        "description": "Fix 2 failing endpoints in src/api/routes.ts",
        "estimated_iterations": 3,
        "targets": ["src/api/routes.ts"]
      },
      {
        "rank": 2,
        "category": "tests",
        "impact_score": 64.0,
        "description": "Add test coverage for auth service (12% → 80%)",
        "estimated_iterations": 5,
        "targets": ["src/services/auth.ts"]
      }
    ]
  }
}
```

## Command Interfaces

### `/autoresearch:harness-check`

No required arguments. Runs in the current project directory.

```
> /autoresearch:harness-check

🔍 Scanning project...
  Detected: eslint, jest, package.json dev script, TypeScript

Harness Check Report — my-project/
───────────────────────────────────
  Runtime Health   45/100  █████████░░░░░░░░░░░  2 endpoints returning 500
  Tests            68/100  █████████████░░░░░░░  68% coverage, 1 failing test
  Code Quality     72/100  ██████████████░░░░░░  3 lint errors
  Architecture     88/100  █████████████████░░░  1 circular import

  Overall: 68/100

  🎯 Top improvements by impact:
  #1  Runtime Health  → Fix 2 failing endpoints in src/api/routes.ts     (+30 pts, ~3 iterations)
  #2  Tests           → Cover auth service (12%→80%)                     (+20 pts, ~5 iterations)
  #3  Code Quality    → Fix 3 lint errors across 2 files                 (+10 pts, ~1 iteration)

  Run: /autoresearch:harness-improvement           (starts #1)
  Run: /autoresearch:harness-improvement --rank 2  (starts #2)
  Run: /autoresearch:harness-improvement --focus architecture
```

**Optional flags:**
- `--json` — output raw harness.json instead of formatted scorecard
- `--probe <name>` — run only a specific probe

### `/autoresearch:harness-improvement`

```
> /autoresearch:harness-improvement

Reading harness.json...
Target: Runtime Health (rank #1, score 45/100)
Goal: Fix 2 failing API endpoints in src/api/routes.ts
Eval: ar_probe_runtime (re-run after each iteration)
Threshold: ≥85/100
Max iterations: 10

Running baseline... 45/100
Generating dashboard...
Spawning experimenter agent...
```

**Optional flags:**
- `--rank <N>` — target the Nth ranked improvement instead of #1
- `--focus <category>` — target a specific category (runtime, tests, lint, architecture)
- `--threshold <N>` — override the default target score
- `--max-iterations <N>` — override default iteration limit (default: 10)

**Error cases:**
- No `harness.json` found → "Run /autoresearch:harness-check first"
- Stale `harness.json` (>24h old) → warn + suggest re-running check
- All probes skipped → "Could not detect any tooling. Add --probe <name> to harness-check or configure manually."
- Target already at ≥90 → suggest next ranked improvement

## New Files

```
autoresearch/
├── commands/
│   ├── improve.md              # existing
│   ├── harness-check.md        # NEW — /autoresearch:harness-check command
│   └── harness-improvement.md  # NEW — /autoresearch:harness-improvement command
├── lib/
│   ├── common.sh               # existing (add AR_HARNESS_FILE constant)
│   ├── dashboard.sh            # existing
│   ├── eval.sh                 # existing
│   ├── experiment-log.sh       # existing
│   ├── probes.sh               # NEW — all probe functions
│   └── harness.sh              # NEW — harness.json read/write, scoring, ranking
├── skills/
│   ├── experiment-loop/
│   │   └── SKILL.md            # existing — reused by harness-improvement
│   └── harness-probes/
│       └── SKILL.md            # NEW — probe authoring guide
```

### `lib/probes.sh` functions

```bash
ar_probe_detect_tooling()     # Scans for config files, returns available probes
ar_probe_lint()               # Runs detected linter, parses output → JSON
ar_probe_tests()              # Runs detected test runner, parses coverage + failures → JSON
ar_probe_runtime()            # Starts dev server, curls endpoints, checks for errors → JSON
ar_probe_architecture()       # Checks file sizes, circular deps, dead code → JSON
ar_probe_run_all()            # Orchestrates all probes, returns combined results
ar_probe_score()              # Calculates 0-100 score from raw findings
```

### `lib/harness.sh` functions

```bash
ar_harness_init()             # Creates harness.json from probe results
ar_harness_rank()             # Computes impact scores, sorts improvements
ar_harness_read()             # Reads harness.json
ar_harness_is_stale()         # Checks if harness.json is >24h old
ar_harness_to_program()       # Converts a ranked improvement → program.md
ar_harness_print_scorecard()  # Formats terminal output with progress bars
```

## Reused Components (no changes needed)

- `agents/experimenter.md` — harness-improvement spawns this unchanged
- `skills/experiment-loop/SKILL.md` — the iteration protocol stays the same
- `lib/dashboard.sh` — same dashboard generation
- `lib/eval.sh` — harness-improvement wraps probe calls into `ar_eval_run`
- `lib/experiment-log.sh` — same experiments.json logging
- `templates/dashboard.html` — same auto-refreshing dashboard

## Integration: How harness-improvement Bridges to the Experimenter

The command does exactly what `/autoresearch:improve` does in steps 4-7, but reads goal/eval/targets from `harness.json` instead of asking the user:

1. `ar_harness_to_program()` → writes `.autoresearch/program.md`
2. Wraps the relevant probe as eval command: `source probes.sh && ar_probe_tests`
3. `ar_log_init` with auto-generated config
4. Run baseline via `ar_eval_run`
5. Generate dashboard via `ar_dashboard_generate`
6. Spawn experimenter agent — identical handoff to existing `/autoresearch:improve`
