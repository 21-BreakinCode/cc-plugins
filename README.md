# autoresearch

A Claude Code plugin for autonomous, eval-driven code improvement. Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

## Commands

### `/autoresearch:improve` — Manual improvement loop

You define the goal, target files, and eval method. The plugin runs an autonomous edit-eval-keep/discard loop with a live dashboard.

**Use when:** You know exactly what to improve and how to measure it.

```
/autoresearch:improve make the sort function in src/utils/sort.ts faster.
  Eval: npm run benchmark, metric: sort_time_ms (lower is better).
```

The command interactively asks for anything you don't provide:
- **Eval metrics** (required) — shell command, LLM-judge criteria, or both
- **Target file(s)** — which files to modify
- **Stopping condition** — when to stop iterating

### `/autoresearch:harness-check` — Auto-discover project health

Scans your project and scores it across 4 categories. No configuration needed — it detects your tooling automatically.

**Use when:** You want a quick health check of an AI-generated (or any) project, or you're not sure what to improve first.

```
/autoresearch:harness-check
```

Produces a scorecard like:

```
Harness Check Report — my-project/
──────────────────────────────────
  Runtime Health   45/100  █████████░░░░░░░░░░░  2 findings
  Tests            68/100  █████████████░░░░░░░  3 findings
  Code Quality     72/100  ██████████████░░░░░░  3 findings
  Architecture     88/100  █████████████████░░░  1 finding

  Overall: 68/100

  🎯 Top improvements by impact:
  #1  Runtime Health  → Fix 2 findings in runtime  (+30 pts, ~3 iterations)
  #2  Tests           → Fix 3 findings in tests    (+20 pts, ~5 iterations)
```

**Probes:**

| Category | What it checks | Auto-detects |
|---|---|---|
| Code Quality | Lint errors | eslint, ruff, flake8, clippy, golangci-lint |
| Tests | Failures + coverage gaps | jest, vitest, pytest, cargo test, go test |
| Runtime | Server starts, endpoints respond | npm dev/start/serve scripts |
| Architecture | Oversized files, circular deps | file analysis, madge (JS/TS) |
| Scriptability | Long/duplicated inline scripts in markdown — extract for consistency + token efficiency | static markdown scan |

Flags: `--json` (raw output), `--probe <name>` (run single probe)

### `/autoresearch:harness-improvement` — Auto-fix top issues

Reads the harness report, picks the highest-impact issue, and runs the improvement loop automatically — no manual configuration needed.

**Use when:** You've run `harness-check` and want to start fixing issues.

```
/autoresearch:harness-improvement              # fix top-ranked issue
/autoresearch:harness-improvement --rank 2     # fix second-ranked issue
/autoresearch:harness-improvement --focus tests # fix test issues specifically
```

This auto-generates the experiment spec and spawns the same experimenter agent used by `/autoresearch:improve`. You get the same dashboard, the same edit-eval-keep/discard loop — just without manual setup.

## Typical workflow

```
/autoresearch:harness-check          # 1. See what's wrong
/autoresearch:harness-improvement    # 2. Auto-fix the worst issue
/autoresearch:harness-check          # 3. Re-check, see improvement
/autoresearch:harness-improvement    # 4. Fix the next issue
```

## Runtime artifacts

Created in `.autoresearch/` (gitignored automatically):

| File | Purpose |
|---|---|
| `program.md` | Experiment spec — editable between iterations |
| `experiments.json` | Structured log of all iterations |
| `dashboard.html` | Live dashboard — auto-refreshes every 5s |
| `harness.json` | Health scorecard from `harness-check` |

## Dashboard

Auto-opens in your browser. Shows score chart (green=kept, red=discarded), expandable diffs, reasoning, and summary stats.

## Install

```
# Clone and symlink (or copy) to your plugins directory
cp -r autoresearch/ ~/.claude/plugins/local/autoresearch/
```

## Adding custom probes

See the `harness-probes` skill for a guide on adding new probe categories (e.g., security, performance).
