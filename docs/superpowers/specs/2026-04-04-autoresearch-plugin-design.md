# autoresearch Plugin Design Spec

**Date:** 2026-04-04
**Status:** Draft
**Inspired by:** [karpathy/autoresearch](https://github.com/karpathy/autoresearch), [SkyPilot scaling blog](https://blog.skypilot.co/scaling-autoresearch/)

## Overview

A Claude Code plugin that applies autoresearch's edit-eval-keep/discard iteration loop to any user-specified improvement task. The user describes what to improve and how to measure it, the plugin generates a `program.md` experiment spec, then an autonomous agent iterates: edit the target, run eval, keep or discard, repeat. A local HTML dashboard visualizes progress in real time.

## Design Principles

- **You program the program, not the code.** The human defines the goal, target, and eval. The agent handles the iteration. Mirrors autoresearch's `program.md` philosophy.
- **One hypothesis per iteration.** Each edit tests a single idea. This keeps diffs reviewable and causation clear.
- **No silent failures.** Dashboard generation is blocking. Eval errors are surfaced. The user always knows what's happening.
- **Progressive disclosure.** The command interactively fills in gaps. Simple tasks stay simple; complex ones get structure.

## Plugin Structure

```
autoresearch/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── commands/
│   └── improve.md               # /autoresearch:improve slash command
├── agents/
│   └── experimenter.md          # Subagent that runs the edit-eval loop
├── skills/
│   └── experiment-loop.md       # Core iteration logic skill
├── lib/
│   ├── dashboard.sh             # Generate/update HTML dashboard
│   ├── eval.sh                  # Run shell-based evals, parse scores
│   └── experiment-log.sh        # Read/write .autoresearch/experiments.json
├── templates/
│   ├── dashboard.html           # HTML template with Chart.js for score visualization
│   └── program.template.md      # Template for generated program.md
├── CLAUDE.md
└── README.md
```

**Runtime artifacts** (in user's project, added to `.gitignore`):

```
.autoresearch/
├── program.md                   # Generated experiment spec (human-readable, re-runnable)
├── experiments.json             # Structured log of all iterations
└── dashboard.html               # Auto-generated, auto-opened in browser
```

## Component Design

### 1. `/autoresearch:improve` Command

Entry point. User types:

```
/autoresearch:improve make this React component render faster
```

**Flow:**

1. **Parse input** — extract improvement goal from inline content.
2. **Eval metrics guard** — check if user provided eval metrics. If not, block and ask:
   > "Before I start iterating, I need to know how to measure improvement. Please provide one or both:
   >
   > **Objective** — a shell command that outputs a measurable score (e.g., `npm test`, `pytest --benchmark`, `lighthouse --output json`)
   >
   > **Subjective** — criteria for me to judge each iteration (e.g., 'rate code readability 1-10 considering naming, structure, and complexity')
   >
   > Without eval metrics, I can't determine if changes are improvements."

   The loop does not start until at least one eval method is confirmed.

3. **Interactive gap-filling** — ask for missing pieces only (skip what's already provided):
   - **Target file(s)** — which file(s) to modify (can auto-detect from context)
   - **Eval method** — shell command, LLM-as-judge criteria, or both
   - **Stopping condition** — ask user: "How should we stop?"
     - When all eval metrics pass a threshold (user specifies thresholds)
     - Smart defaults: max 10 iterations OR 3 consecutive non-improvements, whichever first
     - Custom

4. **Generate `.autoresearch/program.md`** — from gathered info:

   ```markdown
   # Experiment Program

   ## Goal
   Make this React component render faster

   ## Target Files
   - src/components/DataGrid.tsx

   ## Eval
   ### Shell Command
   `npm run benchmark -- --component DataGrid`
   ### Success Metric
   `render_time_ms` — lower is better

   ## Stopping Condition
   3 consecutive non-improvements OR max 10 iterations

   ## Constraints
   - Do not change the component's public API
   - Keep bundle size under 50KB
   ```

5. **Initialize runtime artifacts** — create `.autoresearch/` directory, initial `experiments.json`, add `.autoresearch/` to `.gitignore`.

6. **Hand off to experimenter agent** — spawn the agent with `program.md` as context. Generate initial dashboard and auto-open it in the browser.

### 2. Experimenter Agent

An autonomous subagent that runs the edit-eval-keep/discard loop. Each iteration:

**Step 1 — Read State**
- Read `program.md` for goal, constraints, eval method
- Read `experiments.json` for history (what's been tried, what worked/didn't)
- Read current target file(s)

**Step 2 — Plan the Edit**
- Based on history, decide what to try next. Avoid repeating failed approaches.
- If 2+ iterations showed no improvement, shift strategy (not just parameter tweaks)
- If it needs external knowledge, use defuddle + web search on-demand

**Step 3 — Make the Edit**
- Edit target file(s) using the Edit tool
- One hypothesis per iteration — keep changes focused

**Step 4 — Run Eval**

For shell command evals:
- Run the user's command, capture stdout/stderr
- Agent extracts the numeric score from output

For LLM-as-judge evals:
- Agent reads the modified file, scores against user's criteria (1-10)
- Outputs score with a one-line justification
- Justification is logged for the dashboard

For composite (both):
- Run shell command first (objective), then LLM-as-judge (subjective)
- Both scores logged independently, no forced normalization
- Shell metric is primary for keep/discard if available

**Step 5 — Keep or Discard**
- **Keep:** Score improved. `git commit` with message: `autoresearch: iteration N — metric_name X→Y (kept)`
- **Discard:** Score worsened or unchanged. `git checkout -- <target files>` to revert. Log the attempted diff and score in `experiments.json`.

**Step 6 — Update Dashboard**
- Append iteration result to `experiments.json`
- Regenerate `dashboard.html` from updated data
- **Dashboard generation is blocking.** If it fails, attempt one fix. If still broken, stop the loop and report the error to the user.

**Step 7 — Check Stopping Condition**
- All metrics passed threshold? Stop, report final results.
- Hit max iterations? Stop.
- N consecutive non-improvements? Stop.
- Otherwise, next iteration.

The agent logs its reasoning (what it tried, why, what it expected) into `experiments.json` so the dashboard shows the thought process, not just scores.

### 3. HTML Dashboard

A self-contained single HTML file using inline Chart.js from CDN. No server needed.

**Features:**
- **Score chart** — line chart of scores over iterations. Green dots for kept, red for discarded, blue for baseline.
- **Iteration log table** — columns: #, Score, Delta, Status (kept/discarded/baseline), What was tried
- **Expandable rows** — click to see the full diff attempted and agent's reasoning
- **Summary stats** — best score, baseline score, total improvement %, iterations remaining
- **Multi-metric support** — composite eval shows separate chart lines per metric
- **Research entries** — web research logged as info rows, distinct from experiment rows
- **Auto-refresh** — `<meta http-equiv="refresh" content="5">` while the loop is running. Data is embedded inline in the HTML (regenerated each iteration).
- **Status indicator** — header shows "Running (iteration N/max)" or "Complete"

**Auto-open behavior:**
- On first iteration, run `open .autoresearch/dashboard.html` (macOS) to open in default browser
- If `open` fails, warn but don't block — print the file path so user can open manually

### 4. Web Research via Defuddle

On-demand web research during the iteration loop using `npx defuddle parse <url> --md`.

**When the agent researches:**
- Stuck: 2+ iterations with no improvement and no new ideas
- Needs current library/framework docs for the improvement goal
- Eval output suggests an issue the agent lacks context to fix

**How it works:**
1. Agent formulates a search query based on goal and current blockers
2. Uses WebSearch to find relevant URLs
3. Uses `npx defuddle parse <url> --md` to extract clean markdown (no ads, nav, clutter)
4. Incorporates knowledge into next edit attempt
5. Logs research in `experiments.json` as `type: "research"` with what was learned

**Constraints:**
- Research does not count as an iteration (no score, no keep/discard)
- Research entries appear as info rows in the dashboard, visually distinct from experiments

## Error Handling

| Scenario | Behavior |
|---|---|
| Eval command crashes | Log as `eval_error`, revert the edit, count as non-improvement. After 2 consecutive eval errors, pause and ask the user. |
| Eval command returns no parseable score | Agent attempts to extract a number from output. If it can't, ask user to clarify output format. |
| Target file edit causes syntax errors | Detected by eval failure. Revert, log, try different approach. |
| Git conflict on commit | Should not happen (sequential, single-branch). If it does, stop and report. |
| LLM-judge scores inconsistent | Log scores with justification. If variance > 3 points across similar iterations, flag to user. |
| Dashboard generation fails | **Block the loop.** Attempt to fix once. If still broken, stop and report error to user. |
| Dashboard file can't be written | **Block.** Check permissions, report to user. |
| Browser auto-open fails | **Warn but don't block.** Print the file path so user can open manually. |

## `experiments.json` Schema

```json
{
  "goal": "Make this React component render faster",
  "baseline": {
    "timestamp": "2026-04-04T10:00:00Z",
    "scores": { "render_time_ms": 150 }
  },
  "iterations": [
    {
      "id": 1,
      "type": "experiment",
      "timestamp": "2026-04-04T10:05:00Z",
      "hypothesis": "Memoize expensive sort operation in useMemo",
      "reasoning": "The sort runs on every render, even when data hasn't changed",
      "scores": { "render_time_ms": 120 },
      "delta": { "render_time_ms": -30 },
      "status": "kept",
      "commit_sha": "abc1234",
      "diff_summary": "Added useMemo wrapper around sortData call"
    },
    {
      "id": 2,
      "type": "research",
      "timestamp": "2026-04-04T10:12:00Z",
      "query": "React virtualized list performance optimization",
      "urls": ["https://react.dev/reference/react/useMemo"],
      "learned": "useMemo dependency array must be stable references"
    }
  ],
  "status": "running",
  "config": {
    "max_iterations": 10,
    "consecutive_non_improvements_limit": 3,
    "eval_method": "shell | llm_judge | composite",
    "eval_command": "npm run benchmark -- --component DataGrid",
    "llm_judge_criteria": null,
    "metrics": [
      {
        "name": "render_time_ms",
        "direction": "lower_is_better",
        "source": "shell",
        "threshold": null,
        "primary": true
      }
    ]
  }
}
```

## Stopping Conditions

Three modes, asked during setup:

1. **Threshold-based** — all metrics pass a user-defined threshold (e.g., `render_time_ms < 50`)
2. **Smart defaults** — max 10 iterations OR 3 consecutive non-improvements, whichever first
3. **Custom** — user specifies their own max iterations and non-improvement limit

When the loop stops, the agent:
- Updates dashboard status to "Complete"
- Prints a summary: baseline score, final best score, total improvement %, number of iterations, number kept vs discarded
- Leaves the codebase on the best-performing version (already committed)

## Git Integration

- Each **kept** iteration is committed: `autoresearch: iteration N — metric X→Y (kept)`
- Each **discarded** iteration is reverted via `git checkout -- <target files>`
- Discarded experiments are only recorded in `experiments.json` (no git trace)
- `.autoresearch/` is added to `.gitignore` automatically
- The user's working tree is always in a clean state between iterations
