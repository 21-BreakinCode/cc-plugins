# autoresearch

A Claude Code plugin that applies an autonomous edit-eval-keep/discard iteration loop to any improvement task. Inspired by [karpathy/autoresearch](https://github.com/karpathy/autoresearch).

## How it works

1. You describe what to improve and how to measure it
2. The plugin generates an experiment spec (`program.md`)
3. An autonomous agent iterates: edit → eval → keep or discard → repeat
4. A live HTML dashboard shows scores, diffs, and reasoning in real time

## Install

Copy this plugin directory to `~/.claude/plugins/local/autoresearch/`

## Usage

```
/autoresearch:improve <describe what you want to improve>
```

The command will interactively ask for:
- **Eval metrics** (required) — a shell command, LLM-judge criteria, or both
- **Target file(s)** — which files to modify
- **Stopping condition** — when to stop iterating

### Examples

**Optimize a function with a benchmark:**
```
/autoresearch:improve make the sort function in src/utils/sort.ts faster. Eval: npm run benchmark, metric: sort_time_ms (lower is better). Stop after 10 iterations.
```

**Improve code readability with LLM-as-judge:**
```
/autoresearch:improve improve readability of src/services/auth.ts
```
(The command will ask you for eval criteria since none were provided.)

**Improve prompt quality with composite eval:**
```
/autoresearch:improve optimize the system prompt in prompts/classifier.md. Shell eval: python eval_prompt.py, metric: accuracy (higher is better). Also judge: rate clarity and specificity 1-10.
```

## Runtime artifacts

Created in your project under `.autoresearch/` (gitignored automatically):

| File | Purpose |
|---|---|
| `program.md` | Experiment spec — human-readable, editable between iterations |
| `experiments.json` | Structured log of all iterations |
| `dashboard.html` | Auto-refreshing HTML dashboard — opens automatically |

## Dashboard

The dashboard auto-opens in your browser and refreshes every 5 seconds. It shows:
- Score chart with kept (green) vs discarded (red) iterations
- Iteration log with expandable diffs and reasoning
- Summary stats: baseline, best score, improvement %, kept/total ratio
- Research entries when the agent looked something up

## Eval methods

| Method | When to use | Example |
|---|---|---|
| Shell command | You have a benchmark, test suite, or scoring script | `pytest --benchmark`, `npm run perf` |
| LLM-as-judge | Subjective quality (readability, clarity, style) | "rate readability 1-10" |
| Composite | Both objective and subjective metrics | benchmark + readability score |

## Configuration

Edit `.autoresearch/program.md` between iterations to adjust the goal, constraints, or eval criteria. The agent re-reads it at the start of each iteration.
