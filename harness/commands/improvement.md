---
description: "Execute improvement loop on the top-ranked harness issue — auto-generates eval from probes and spawns the autoresearch:experimenter agent"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion"]
---

# /harness:improvement

You are the improvement command for the harness plugin. Your job is to read the harness report, pick the top improvement target, auto-generate a program.md, and hand off to the experimenter agent.

## Step 1: Source Libraries

```bash
source "$(find -L ~/.claude/plugins -path '*/harness/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find -L ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find -L ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find -L ~/.claude/plugins -path '*/autoresearch/lib/eval.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find -L ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

## Step 2: Validate Harness Exists

Check if `.autoresearch/harness.json` exists:
```bash
ar_harness_read > /dev/null
```

If it doesn't exist, tell the user:
> No harness report found. Run `/harness:check` first to scan your project.

If it's stale (>24h old), warn:
> ⚠️ Harness report is over 24 hours old. Consider re-running `/harness:check` for fresh results.
> Proceeding with existing report...

## Step 3: Parse Arguments

Check if the user passed any flags:
- `--rank <N>` — target the Nth ranked improvement (default: 1)
- `--focus <category>` — target a specific category (lint, tests, runtime, architecture)
- `--threshold <N>` — override the default target score
- `--max-iterations <N>` — override default iteration limit

If `--focus <category>` is specified, find the rank for that category from harness.json.

## Step 4: Check Target Viability

Read the harness.json and check the target:
- If the target category's score is already ≥90, suggest the next ranked improvement:
  > <Category> is already at <score>/100. Try `--rank 2` for the next improvement.

## Step 5: Generate program.md

```bash
ar_harness_to_program <rank>
```

Print what's being targeted:
> **Target:** <Category> (rank #<N>, score <score>/100)
> **Goal:** <description>
> **Eval:** ar_probe_<category> (re-run after each iteration)
> **Threshold:** ≥<threshold>/100
> **Max iterations:** <max>

## Step 6: Initialize Experiment Log

Read the generated program.md to extract the goal and eval details, then:

```bash
ar_log_init "<goal>" "shell" "<eval_command>" "" "<max_iterations>" "3"
```

## Step 7: Run Baseline Eval

Run the probe as eval to get the starting score:

```bash
result=$(ar_eval_run "<eval_command>")
exit_code=$(echo "${result}" | head -1)
score=$(echo "${result}" | tail -n +2)
ar_log_set_baseline '{"score": '"${score}"'}'
```

Print:
> Running baseline... <score>/100

## Step 8: Generate Initial Dashboard

```bash
ar_dashboard_generate
ar_dashboard_open
```

If `ar_dashboard_generate` fails, stop and report the error. Do NOT proceed.

## Step 9: Hand Off to Experimenter Agent

Tell the user:
> Baseline established. Dashboard is open. Starting the improvement loop.

Then spawn the experimenter agent using the Agent tool with `subagent_type: "autoresearch:experimenter"`. Pass:
1. The full content of `.autoresearch/program.md`
2. The path to the project root
3. The paths to the lib scripts (harness/lib/probes.sh and harness/lib/harness.sh for probe-based evals, plus autoresearch/lib/* for experiment-log, eval, dashboard)
4. Instruction to read the experiment-loop skill (in autoresearch) for the iteration protocol

The experimenter agent (in autoresearch) handles the edit-eval-keep/discard loop from here.

## Important Notes

- This command reuses the existing experimenter agent and experiment-loop skill unchanged.
- The only difference from `/autoresearch:improve` is that goal/eval/targets come from harness.json, not from the user.
- Probes serve double duty: discovery in harness-check AND eval in harness-improvement.
