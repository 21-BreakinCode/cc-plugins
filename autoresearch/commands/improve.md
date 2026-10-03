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

## Step 2: Eval Metrics Guard

Scan the user's input for eval-related content: words like "score", "metric", "benchmark", "test", "measure", "judge", "rate", "evaluate", "pass", "fail", a shell command, or scoring criteria.

If no eval method is detected, ask before proceeding:

> Before I start iterating, I need to know how to measure improvement. Please provide one or both:
>
> **Objective**: a shell command that outputs a measurable score (for example, `npm test`, `pytest --benchmark`, `lighthouse --output json`)
>
> **Subjective**: criteria that independent judges use to compare each edit with the last kept version.
> For example: "code readability: naming, structure, and complexity."
>
> Without eval metrics, I cannot tell whether changes are improvements.

Start the loop only after at least one eval method is set.

## Step 3: Interactive Gap-Filling

Ask for any missing information, one question at a time. Skip questions where the answer is already known from the user's input.

**Target file(s):**

If not specified, try to auto-detect from the goal and current project context (read nearby files, check what is relevant). If unclear, ask:
> Which file(s) do I modify during the improvement loop?

**Eval method details:**

- Shell command: check the exact command and which metric name to extract from output.
  - For a skill or plugin target with an `evals/` suite, offer `claude plugin eval <plugin> --json --no-publish --max-cost-usd <budget>`. It runs each case with and without the plugin. Run it once, pick the score field from the JSON, and wrap the command so it prints `<metric>: <value>`, for example `... | jq -r '"score: \(.<field>)"'`.
- LLM-as-judge: check the criteria. Blind judges compare each edit with the last kept version against these criteria, so write them as concrete checks.
- Both: check both.

**Metric direction:**
> For `<metric_name>`, is lower better or higher better?

**Minimum gain (shell metrics only):**
> What is the smallest gain in `<metric_name>` that counts? A gain at or below it is discarded. The default is 0: any gain counts. For a noisy metric such as a benchmark, use its run-to-run variation.

**Stopping condition:**
> How does the loop stop?
> 1. When all metrics pass a threshold (you specify the threshold)
> 2. Smart defaults (max 10 iterations OR 3 consecutive non-improvements)
> 3. Custom (you specify max iterations and non-improvement limit)

**Constraints (optional):**
> Any constraints I must respect? (for example, "do not change the public API", "keep bundle under 50KB")
> If none, I will focus on the improvement goal.

For a text target (prose, a prompt, or a skill file), add a size cap unless the user declines it. A judge can favor longer text, and the cap stops the loop from growing a file to win votes. Set each cap to 150% of the baseline size from `wc -c < <file>`, and write it in bytes, for example `Size cap: docs/guide.md ≤ 6000 bytes (baseline 4000)`.

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
ar_log_init "<goal>" "<eval_method>" "<eval_command>" "<llm_criteria>" "<max_iterations>" "<consec_limit>" "<min_delta>"
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

For LLM-as-judge evals: the judges compare versions, so there is no absolute baseline score. Record `ar_log_set_baseline '{"better_votes": null}'`. For composite evals, add `"better_votes": null` after the shell metric.

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

- Ask questions ONE AT A TIME, not all at once.
- If the user provides everything upfront, skip to Step 4.
- The `.autoresearch/` directory must exist before generating the dashboard.
