---
name: experiment-loop
description: "Core iteration logic for autoresearch: edit target, run eval, keep or discard, update dashboard, repeat."
---

# Experiment Loop

You are running an autonomous improvement loop. Each iteration follows a strict protocol.

## Before Each Iteration

1. Read `.autoresearch/experiments.json` to understand:
   - The goal and constraints from the config
   - What has been tried before (avoid repeating failed approaches)
   - The current best score
   - How many consecutive non-improvements have occurred

2. Read the target file(s) listed in `.autoresearch/program.md`

3. Decide what to try next:
   - **If first iteration:** Make the most obvious improvement based on the goal
   - **If previous iterations improved:** Continue in a similar direction, refine further
   - **If 2+ consecutive non-improvements:** Shift strategy entirely. Don't tweak — try a fundamentally different approach.
   - **If stuck and need knowledge:** Use WebSearch + `npx defuddle parse <url> --md` to research. Log as a research entry (see Research Protocol below). This does NOT count as an iteration.

## The Iteration Protocol

### 1. Plan

Write a one-line hypothesis: what you're going to change and why you expect it to improve the metric.

### 2. Edit

Make the edit to the target file(s). **One hypothesis per iteration.** Keep changes focused and minimal. Do not combine multiple unrelated changes.

### 3. Eval

**For shell command evals:**

Run the eval command using Bash:
```bash
<eval_command> 2>&1
```

Extract the metric score from the output. Look for patterns like `metric_name: value`, `metric_name=value`, or `metric_name value`.

If the command crashes (non-zero exit without a score):
- This counts as an eval error
- Revert the edit: `git checkout -- <target_files>`
- Log the iteration as `status: "discarded"` with the error in reasoning
- If 2 consecutive eval errors, STOP and ask the user

**For LLM-as-judge evals:**

Read the modified target file. Score it against the criteria specified in program.md on a 1-10 scale. Write a one-line justification for the score.

**For composite evals:**

Run the shell command first, then do the LLM-as-judge scoring. Log both scores. Use the shell metric as the primary keep/discard signal.

### 4. Compare

Compare the new score against the previous best score (not baseline — the running best).

Calculate the delta: `new_score - previous_best_score`

Determine if this is an improvement based on the metric direction (lower_is_better or higher_is_better).

### 5. Keep or Discard

**If improved (keep):**
```bash
git add <target_files>
git commit -m "autoresearch: iteration <N> — <metric_name> <old>→<new> (kept)"
```

Log the iteration to experiments.json with `status: "kept"` and the commit SHA.

**If not improved (discard):**
```bash
git checkout -- <target_files>
```

Log the iteration to experiments.json with `status: "discarded"`. Include the diff that was attempted in `diff_summary` so the dashboard can show what was tried.

### 6. Update Dashboard

This step is **BLOCKING**. If it fails, stop the loop.

Generate the updated dashboard:
```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_dashboard_generate
```

If `ar_dashboard_generate` returns non-zero:
1. Attempt to fix the issue (e.g., re-read the template, check experiments.json validity)
2. Try generating again
3. If it still fails, STOP the loop and report: "Dashboard generation failed. Iteration paused. Error: <details>"

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
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_log_set_status "complete"
```

Regenerate the dashboard one final time (the auto-refresh meta tag is removed when status is "complete").

Print a summary to the user:
```
Improvement loop complete.

Baseline:     <baseline_score>
Best:         <best_score> (iteration <N>)
Improvement:  <percentage>%
Iterations:   <total> (<kept> kept, <discarded> discarded)
Reason:       <why it stopped — max iterations / convergence / threshold met>

Dashboard: .autoresearch/dashboard.html
```

## Research Protocol

When you need external knowledge during the loop:

1. Use WebSearch to find relevant URLs
2. Use Bash to run: `npx defuddle parse <url> --md`
3. Read the output and extract useful knowledge
4. Log the research:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_log_append_research <next_id> "<query>" '["<url1>", "<url2>"]' "<what you learned>"
```

5. Regenerate the dashboard (research entries show as info rows)
6. Proceed to the next iteration with the new knowledge

Research does NOT count toward the iteration limit or consecutive non-improvement count.

## Rules

- **One hypothesis per iteration.** Never combine unrelated changes.
- **Never skip eval.** Every edit must be evaluated before deciding keep/discard.
- **Never skip dashboard update.** The user must be able to see progress.
- **Always log reasoning.** The dashboard shows your thought process, not just scores.
- **Revert completely on discard.** `git checkout -- <files>` must leave the working tree identical to before the edit.
- **Compare against running best, not baseline.** The bar rises with each kept iteration.
