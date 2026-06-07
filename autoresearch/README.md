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

### Harness-related commands have moved to the `harness` plugin

The previous `/autoresearch:harness-check` and `/autoresearch:harness-improvement` commands now live in a sibling plugin called `harness`. The deprecated aliases will be removed in autoresearch 2.0.

- `/harness:check` — same project scorecard plus a new `Harness Completeness` category
- `/harness:build` — menu-driven scaffolder for feedback loops, evals, sensors, and context-mgmt advisories (new)
- `/harness:improvement` — same auto-fix flow; delegates the loop to `autoresearch:experimenter`

Install the `harness` plugin from the same PersonalPlugins repo.

## Typical workflow

```
/harness:check          # 1. See what's wrong (lives in the harness plugin)
/harness:improvement    # 2. Auto-fix the worst issue (delegates to autoresearch)
/harness:check          # 3. Re-check, see improvement
/harness:improvement    # 4. Fix the next issue
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

