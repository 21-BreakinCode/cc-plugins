---
name: experiment-loop
description: "Core iteration logic for autoresearch: edit target, run eval, keep or discard, update dashboard, repeat."
---

# Experiment Loop

You are running an autonomous improvement loop. Each iteration follows a strict protocol.

## Before Each Iteration

1. Read `.autoresearch/experiments.json` to understand:
   - The goal and constraints from the config
   - What was tried before (avoid repeating failed approaches)
   - The current best score
   - How many consecutive non-improvements happened

2. Read the target file(s) listed in `.autoresearch/program.md`

   **On the first iteration only**, take the baseline revert point before any
   edit:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/common.sh"
   source "${CLAUDE_PLUGIN_ROOT}/lib/snapshot.sh"
   ar_snapshot_save <target_files>
   ```
   The snapshot holds the **last known good** state. It advances only on a
   keep. Never save before an edit, or a crash mid-edit will poison the revert
   point. No git repo is required at the target.

3. Decide what to try next:
   - **If first iteration:** Make the most obvious improvement based on the goal
   - **If previous iterations improved:** Continue in a similar direction, refine further
   - **If 2+ consecutive non-improvements:** Shift strategy entirely. Do not tweak. Try a fundamentally different approach.
   - **If stuck and need knowledge:** Use WebSearch + `npx defuddle parse <url> --md` to research. Log as a research entry (see Research Protocol below). This does NOT count as an iteration.

## Dashboard Artifact Update

After any dashboard generation, call Artifact with:
- `file_path`: `.autoresearch/dashboard.html`
- `url`: `<dashboard_url>`
- `favicon`: `📈`

The stable update arguments are `url: <dashboard_url>` and `favicon: 📈`. If the Artifact publish fails, retry once. If the retry fails, stop the loop and report the publish error. Use this procedure after a normal iteration, after research dashboard regeneration, and after final completion.

## The Iteration Protocol

### 1. Plan

Write a one-line hypothesis: what you plan to change and why you expect it to improve the metric.

### 2. Edit

Make the edit to the target file(s). **One hypothesis per iteration.** Keep changes focused and minimal, one idea at a time.

### 3. Eval

**For shell command evals:**

Run the eval command using Bash:
```bash
<eval_command> 2>&1
```

Extract the metric score from the output. Look for patterns like `metric_name: value`, `metric_name=value`, or `metric_name value`.

If the command crashes (non-zero exit without a score):
- This counts as an eval error
- Revert the edit: `ar_snapshot_restore <target_files>`
- Log the iteration as `status: "discarded"` with the error in reasoning
- If 2 consecutive eval errors, STOP and ask the user

**For LLM-as-judge evals:**

Read the modified target file. Score it against the criteria specified in program.md on a 1-10 scale. Write a one-line justification for the score.

**For composite evals:**

Run the shell command first, then do the LLM-as-judge scoring. Log both scores. Use the shell metric as the primary keep/discard signal.

### 4. Compare

Compare the new score against the previous best score (not baseline, the running best).

Calculate the delta: `new_score - previous_best_score`

Use the metric direction (lower_is_better or higher_is_better) to determine whether this is an improvement.

### 5. Keep or Discard

**If improved (keep):**
```bash
ar_snapshot_save <target_files>
```

This advances the revert point to the new best state. A later discard falls
back to *this* iteration, not the original baseline.

Log the iteration to experiments.json with `status: "kept"` and your one-line reasoning.

**If not improved (discard):**
```bash
ar_snapshot_restore <target_files>
```

Log the iteration to experiments.json with `status: "discarded"`, your reasoning, and the attempted change in `diff_summary`. The dashboard shows your thinking, not just scores.

### 6. Update Dashboard

This step is **BLOCKING**. If it fails, stop the loop.

Generate the updated dashboard:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/dashboard.sh"
ar_dashboard_generate
```

If `ar_dashboard_generate` returns non-zero:
1. Attempt to fix the issue (for example, re-read the template, check experiments.json validity)
2. Try generating again
3. If it still fails, STOP the loop and report: "Dashboard generation failed. Iteration paused. Error: <details>"

After generation succeeds, follow the Dashboard Artifact Update procedure.

### 7. Check Stopping Condition

Read the config from experiments.json:
- `max_iterations`: maximum number of experiment iterations
- `consecutive_non_improvements_limit`: stop after this many consecutive discards

Check:
1. Has the experiment count reached `max_iterations`? → STOP
2. Have we hit `consecutive_non_improvements_limit` consecutive discards? → STOP
3. If config has metric thresholds, have all been met? → STOP
4. Otherwise → next iteration

### 8. Report When Done

When the loop stops, update the status:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/experiment-log.sh"
ar_log_set_status "complete"
```

Regenerate the dashboard one final time. When status is "complete", the auto-refresh meta tag is removed. Follow the Dashboard Artifact Update procedure after this final generation.

Print a summary to the user:
```
Improvement loop complete.

Baseline:     <baseline_score>
Best:         <best_score> (iteration <N>)
Improvement:  <percentage>%
Iterations:   <total> (<kept> kept, <discarded> discarded)
Reason:       <why it stopped — max iterations / convergence / threshold met>

Dashboard: <dashboard_url>
```

## Research Protocol

When you need external knowledge during the loop:

1. Use WebSearch to find relevant URLs
2. Use Bash to run: `npx defuddle parse <url> --md`
3. Read the output and extract useful knowledge
4. Log the research:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/experiment-log.sh"
ar_log_append_research <next_id> "<query>" '["<url1>", "<url2>"]' "<what you learned>"
```

5. Regenerate the dashboard (research entries show as info rows), then follow the Dashboard Artifact Update procedure
6. Proceed to the next iteration with the new knowledge

Research does NOT count toward the iteration limit or consecutive non-improvement count.
