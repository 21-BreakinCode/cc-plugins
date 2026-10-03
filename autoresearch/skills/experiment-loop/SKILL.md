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

After any dashboard generation, Read the complete `.autoresearch/dashboard.html` with Read before you call Artifact. Call Artifact with:
- `file_path`: `.autoresearch/dashboard.html`
- `url`: `<dashboard_url>`
- `favicon`: `📈`

The stable update arguments are `url: <dashboard_url>` and `favicon: 📈`. If the Artifact publish fails, retry once. If the retry fails, stop the loop and report the publish error. Use this procedure after a normal iteration, after research dashboard regeneration, and after final completion.

## The Iteration Protocol

### 1. Plan

Write a one-line hypothesis: what you plan to change and why you expect it to improve the metric.

### 2. Edit

Make the edit to the target file(s). **One hypothesis per iteration.** Keep changes focused and minimal, one idea at a time.

If the Constraints in program.md set a size cap, check each capped file with `wc -c < <file>`. A file over its cap is a discard without eval: run `ar_snapshot_restore <target_files>` and log `status: "discarded"` with "over size cap" in reasoning.

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

**For LLM-as-judge evals (blind paired judges):**

Three fresh `autoresearch:judge` agents compare the last kept version with your edit. The editor's own score is biased toward its edit, so the judges decide.

1. Stage one blind copy per judge:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/lib/judge.sh"
   for judge_id in 1 2 3; do
     echo "judge ${judge_id}: edited=$(ar_judge_stage "${judge_id}" <target_files>)"
   done
   ```
   Note each judge's `edited` label from the output.
2. Spawn the three judges in parallel, in one message, with `subagent_type: "autoresearch:judge"` and `run_in_background: false`. A background judge reports to the main session instead of to you, and the tally never happens. Give judge `<id>` exactly two things:
   - The LLM Judge Criteria from program.md, word for word
   - Each target path under `.autoresearch/judge/<id>/A/` and under `.autoresearch/judge/<id>/B/`

   Keep the judge blind: the prompt holds only those two things.
3. Tally the votes:
   ```bash
   ar_judge_tally "<edited_1>:<verdict_1>" "<edited_2>:<verdict_2>" "<edited_3>:<verdict_3>"
   ```
   Log `{"better_votes": <better>}` as scores and `{"better_votes": <better - worse>}` as delta. Put each judge's reason in `reasoning`.

| Trigger | First fix | Still failing |
|---|---|---|
| A judge returns `error` or no valid JSON line | Re-spawn that judge once | Count it as an eval error |
| The Agent tool is missing or refuses to spawn | None | STOP and report: "Judges cannot spawn. Check `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (needs 2 or more)." |

A judge failure never falls back to scoring the edit yourself.

**For composite evals:**

Run the shell command first, then the blind paired judges. Log both. The shell metric decides keep or discard.

### 4. Compare

**LLM-as-judge evals:** the tally's `keep` field is the decision. Skip the rest of this step.

**Shell and composite evals:** compare the new score against the previous best score (not baseline, the running best).

Calculate the delta: `new_score - previous_best_score`

Decide with the metric direction and `min_delta` from the experiments.json config:
```bash
ar_eval_is_improvement "<new_score>" "<previous_best_score>" "<direction>" "<min_delta>"
```
Exit code 0 means improved. A gain at or below `min_delta` is a discard, so it counts toward the stopping limit.

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

Regenerate the dashboard one final time. Follow the Dashboard Artifact Update procedure after this final generation.

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
