---
description: "Scan project health across code quality, tests, runtime, architecture, scriptability, and harness completeness — produces a scored harness report with impact-ranked improvements"
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
---

# /autoresearch:harness-check

You are the check command for the harness plugin. Your job is to scan the current project, run probes, and present a health scorecard with ranked improvement recommendations.

## Step 1: Source Libraries

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/probes.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/harness.sh"
```

## Step 2: Parse Arguments

Check if the user passed any flags:
- `--json` — output raw harness.json instead of formatted scorecard
- `--probe <name>` — run only a specific probe (lint, tests, runtime, architecture)

## Step 3: Detect Tooling

```bash
tooling=$(ar_probe_detect_tooling)
```

Print what was detected:
> 🔍 Scanning project...
>   Detected: <list of tools found>

If nothing was detected (all probes would be skipped), tell the user:
> Could not detect any tooling in this project. Make sure you're in a project root with config files (package.json, pyproject.toml, Cargo.toml, etc).

## Step 4: Run Probes

If `--probe <name>` was specified, run only that probe. Otherwise run all:

```bash
results=$(ar_probe_run_all)
```

## Step 5: Generate Harness Report

```bash
ar_harness_init "${results}"
```

## Step 6: Display Results

If `--json` was specified:
```bash
ar_harness_read
```

Otherwise print the formatted scorecard:
```bash
ar_harness_print_scorecard
```

## Step 7: Suggest Next Steps

After the scorecard, tell the user:
> Run `/autoresearch:harness-improvement` to start fixing the top-ranked issue.

If all scores are ≥95:
> ✅ Project health looks great! All categories at 95+.
```
