---
description: "Iteratively improve any artifact using an edit-eval-keep/discard loop with live dashboard"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "WebSearch", "WebFetch"]
---

# /autoresearch:improve

You are the setup phase of the autoresearch plugin. Your job is to gather the information needed to run an autonomous improvement loop, generate the experiment spec, and hand off to the experimenter agent.

## Step 1: Parse the User's Input

The user invoked this command with inline content describing what they want to improve. Extract:

1. **Improvement goal** — what they want to make better
2. **Target file(s)** — if mentioned (may need to ask)
3. **Eval method** — if mentioned (may need to ask)
4. **Stopping condition** — if mentioned (may need to ask)

## Step 2: Eval Metrics Guard (MANDATORY)

**This check is non-negotiable. ALWAYS perform it.**

Scan the user's input for eval-related content: words like "score", "metric", "benchmark", "test", "measure", "judge", "rate", "evaluate", "pass", "fail", a shell command, or scoring criteria.

If NO eval method is detected, you MUST ask before proceeding:

> Before I start iterating, I need to know how to measure improvement. Please provide one or both:
>
> **Objective** — a shell command that outputs a measurable score (e.g., `npm test`, `pytest --benchmark`, `lighthouse --output json`)
>
> **Subjective** — criteria for me to judge each iteration (e.g., "rate code readability 1-10 considering naming, structure, and complexity")
>
> Without eval metrics, I can't determine if changes are improvements.

**Do NOT proceed until at least one eval method is confirmed.**

## Step 3: Interactive Gap-Filling

Ask for any missing information, one question at a time. Skip questions where the answer is already known from the user's input.

**Target file(s):**
If not specified, try to auto-detect from the goal and current project context (read nearby files, check what's relevant). If unclear, ask:
> Which file(s) should I modify during the improvement loop?

**Eval method details:**
- If shell command: confirm the exact command and which metric name to extract from output
- If LLM-as-judge: confirm the criteria and scale (default 1-10)
- If both: confirm both

**Metric direction:**
> For `<metric_name>`, is lower better or higher better?

**Stopping condition:**
> How should the loop stop?
> 1. When all metrics pass a threshold (you specify the threshold)
> 2. Smart defaults (max 10 iterations OR 3 consecutive non-improvements)
> 3. Custom (you specify max iterations and non-improvement limit)

**Constraints (optional):**
> Any constraints I should respect? (e.g., "don't change the public API", "keep bundle under 50KB")
> If none, I'll just focus on the improvement goal.

## Step 4: Generate program.md

Once all information is gathered, create the `.autoresearch/` directory and generate the experiment spec.

1. Run this to initialize the directory and gitignore:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_ensure_dir
ar_ensure_gitignore
```

2. Write `.autoresearch/program.md` with all the gathered information. Use the template at `templates/program.template.md` as a reference but fill in the actual values. Replace any `{{PLACEHOLDER}}` sections that don't apply with "N/A".

3. Initialize the experiment log:

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_log_init "<goal>" "<eval_method>" "<eval_command>" "<llm_criteria>" "<max_iterations>" "<consec_limit>"
```

## Step 5: Run Baseline Eval

Before starting the loop, run the eval on the current (unmodified) target to establish the baseline score.

For shell evals:
```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/eval.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_eval_run "<eval_command>"
```

Extract the metric from the output and set the baseline:
```bash
ar_log_set_baseline '{"<metric_name>": <score>}'
```

For LLM-as-judge evals: read the target file and score it against the criteria. Record the score as the baseline.

## Step 6: Generate Initial Dashboard and Open It

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
ar_dashboard_generate
ar_dashboard_open
```

If `ar_dashboard_generate` fails, stop and report the error. Do not proceed to the loop.

## Step 7: Hand Off to Experimenter Agent

Tell the user:
> Baseline established. Dashboard is open. Starting the improvement loop.

Then spawn the experimenter agent:

Use the Agent tool to spawn the `experimenter` agent with type from `agents/experimenter.md`. Pass the full content of `.autoresearch/program.md` and the path to `.autoresearch/experiments.json` as context in the prompt.

The prompt to the agent should include:
1. The full program.md content
2. The path to the project root
3. The paths to the lib scripts (for dashboard generation)
4. Instruction to read the experiment-loop skill for the iteration protocol

## Important Notes

- NEVER start the loop without eval metrics. This is the #1 rule.
- Ask questions ONE AT A TIME, not all at once.
- If the user provides everything upfront, skip to Step 4.
- The `.autoresearch/` directory must exist before generating the dashboard.
