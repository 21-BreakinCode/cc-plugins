---
description: "Iteratively improve any artifact using an edit-eval-keep/discard loop with live dashboard"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "Artifact", "AskUserQuestion", "WebSearch", "WebFetch"]
---

# /autoresearch:improve

You are the setup phase of the autoresearch plugin. Your job is to gather the information needed to run an autonomous improvement loop, generate the experiment spec, and hand off to the experimenter agent.

## Step 1: Parse the User's Input

The user invoked this command with inline content describing what they want to improve. Extract:

1. **Improvement goal**: what they want to make better
2. **Target file(s)**: if mentioned (ask if not)
3. **Eval method**: if mentioned (ask if not)
4. **Stopping condition**: if mentioned (ask if not)

## Step 2: Eval Metrics Guard (MANDATORY)

**This check is non-negotiable. ALWAYS perform it.**

Scan the user's input for eval-related content: words like "score", "metric", "benchmark", "test", "measure", "judge", "rate", "evaluate", "pass", "fail", a shell command, or scoring criteria.

If NO eval method is detected, you MUST ask before proceeding:

> Before I start iterating, I need to know how to measure improvement. Please provide one or both:
>
> **Objective**: a shell command that outputs a measurable score (for example, `npm test`, `pytest --benchmark`, `lighthouse --output json`)
>
> **Subjective**: criteria for me to judge each iteration.
> For example: "rate code readability 1-10 considering naming, structure, and complexity."
>
> Without eval metrics, I cannot tell whether changes are improvements.

**Do NOT proceed until you check that at least one eval method is set.**

## Step 3: Interactive Gap-Filling

Ask for any missing information, one question at a time. Skip questions where the answer is already known from the user's input.

**Target file(s):**

If not specified, try to auto-detect from the goal and current project context (read nearby files, check what is relevant). If unclear, ask:
> Which file(s) do I modify during the improvement loop?

**Eval method details:**

- Shell command: check the exact command and which metric name to extract from output.
- LLM-as-judge: check the criteria and scale (default 1-10).
- Both: check both.

**Metric direction:**
> For `<metric_name>`, is lower better or higher better?

**Stopping condition:**
> How does the loop stop?
> 1. When all metrics pass a threshold (you specify the threshold)
> 2. Smart defaults (max 10 iterations OR 3 consecutive non-improvements)
> 3. Custom (you specify max iterations and non-improvement limit)

**Constraints (optional):**
> Any constraints I must respect? (for example, "do not change the public API", "keep bundle under 50KB")
> If none, I will focus on the improvement goal.

## Step 4: Generate program.md

Once all information is gathered, create the `.autoresearch/` directory and generate the experiment spec.

1. Run this to initialize the directory and gitignore:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/common.sh"
ar_ensure_dir
ar_ensure_gitignore
```

2. Write `.autoresearch/program.md` with all the gathered information. Use the template at `templates/program.template.md` as a reference but fill in the actual values. Replace any `{{PLACEHOLDER}}` sections that do not apply with "N/A".

3. Initialize the experiment log:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/experiment-log.sh"
ar_log_init "<goal>" "<eval_method>" "<eval_command>" "<llm_criteria>" "<max_iterations>" "<consec_limit>"
```

## Step 5: Run Baseline Eval

Before starting the loop, run the eval on the current (unmodified) target to establish the baseline score.

For shell evals:
```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/eval.sh"
ar_eval_run "<eval_command>"
```

Extract the metric from the output and set the baseline:
```bash
ar_log_set_baseline '{"<metric_name>": <score>}'
```

For LLM-as-judge evals: read the target file and score it against the criteria. Record the score as the baseline.

## Step 6: Generate and Publish Initial Dashboard

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/dashboard.sh"
ar_dashboard_generate
```

If `ar_dashboard_generate` fails, stop and report the error. Do not proceed to the loop.

Read the complete `.autoresearch/dashboard.html` with Read before you call Artifact.

Call Artifact with:
- `file_path`: `.autoresearch/dashboard.html`
- `favicon`: `📈`
- `title`: `Autoresearch Dashboard`
- `description`: `Live progress for the current autoresearch improvement run.`

If the initial Artifact publish fails, stop and report the error. Do not proceed to the loop.

Save the returned URL as `<dashboard_url>`.

## Step 7: Hand Off to Experimenter Agent

Tell the user:
> Baseline established. Dashboard: <dashboard_url>. Starting the improvement loop.

Then spawn the experimenter agent:

Use the Agent tool to spawn the `experimenter` agent with type from `agents/experimenter.md`. Pass the full content of `.autoresearch/program.md`, the path to `.autoresearch/experiments.json`, and `<dashboard_url>` as context in the prompt.

The prompt to the agent must include:
1. The full program.md content
2. The path to the project root
3. The paths to the lib scripts (for dashboard generation)
4. The `<dashboard_url>` from the initial Artifact publish
5. Instruction to read the experiment-loop skill for the iteration protocol

## Important Notes

- NEVER start the loop without eval metrics. This is the #1 rule.
- Ask questions ONE AT A TIME, not all at once.
- If the user provides everything upfront, skip to Step 4.
- The `.autoresearch/` directory must exist before generating the dashboard.
