---
description: "Menu-driven scaffolder for harness components — feedback loop, eval loop, sensor, or context-mgmt advisory. Writes Tier-1 artifacts into your project's .claude/."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
---

# /harness:build

You are the build command for the harness plugin. Your job is to help the user
scaffold one harness component at the simplest possible Tier-1 shape.

## Step 1: Source libraries

```bash
source "$(find -L ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find -L ~/.claude/plugins -path '*/harness/lib/build.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

## Step 2: Run the harness-completeness probe silently

```bash
advice_json=$(ar_probe_harness "static")
recommended=$(echo "${advice_json}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(','.join(d.get('recommended', [])))")
echo "RECOMMENDED: ${recommended}"
```

Parse the comma-separated `recommended` list. It will contain zero or more of:
`feedback`, `eval`, `sensor`, `context-mgmt`.

## Step 3: Present the menu

Use AskUserQuestion with a single question. The header is "Component type".
Construct option labels by annotating each with " (recommended)" if the type
appears in `recommended`. Keep the four options in the same order every time.
The user's pick determines the next step.

Options:
1. Feedback loop — hook on a Claude Code event that posts a domain principle
2. Eval loop — script that returns JSON `{pass, metric, reason}`
3. Sensor — wrap a linter, emit agent-tuned fix messages
4. Context-mgmt — generate an advisory report of oversized agent/skill files

## Step 4: Run the focused intake for the chosen type

### If feedback loop

Ask 3 questions via AskUserQuestion (one per call OR a single 3-question batch — your call):

- Q1 (header "Event"): Which Claude Code event? Options: `UserPromptSubmit`, `Stop`, `PostToolUse`, `PreToolUse`.
- Q2 (header "Matcher"): What tool/pattern should fire? Default: `Edit`. Accept free-text.
- Q3 (header "Principle"): One-line description of the principle to enforce. Free-text.

Then call:

```bash
name="<derived from principle, slugified, max 40 chars>"  # e.g. 'all-ts-fns-have-return-types'
ar_harness_build_feedback_loop "${name}" "${event}" "${matcher}" "${principle}"
```

### If eval loop

Ask 3 questions:

- Q1 (header "Description"): What does this eval measure? Free-text.
- Q2 (header "Scope"): single file, whole repo, or command output? Multiple choice.
- Q3 (header "Criterion"): pass/fail criterion in plain English. Free-text.

Then call:

```bash
name="<slugified description>"
ar_harness_build_eval_loop "${name}" "${description}" "${scope}" "${criterion}"
```

### If sensor

Ask 3 questions:

- Q1 (header "Linter"): which linter? Default to the project's detected linter (from `ar_probe_detect_tooling`). Multiple choice: `eslint`, `ruff`, or "other (specify)".
- Q2 (header "Rule"): rule code or category. Free-text.
- Q3 (header "Message"): the agent-tuned fix message. Free-text.

Then call:

```bash
name="<slugified rule>"
ar_harness_build_sensor "${name}" "${linter}" "${rule}" "${message}"
```

### If context-mgmt

No intake. Just call:

```bash
ar_harness_build_context_report
```

## Step 5: Summarize what was created

Read each output path printed by the builder. Print to the user:

> Created at <path>:
> - <one-line description of the artifact>
>
> Tier-1 scaffold complete. The upgrade ladder is documented inline in the file.

**Per-type next steps:**
- **Feedback loop:** the generated `.claude/hooks/<name>.json` is a snippet, not an auto-loaded hook. Tell the user to copy the value of its top-level `"hooks"` key into their `.claude/settings.json` under that file's `"hooks"` key, then restart Claude Code. The generated file's `_install` field repeats this.
- **Eval loop:** the script at `eval/<name>.sh` is the eval. Tell the user they can invoke it directly, or pass it to `/autoresearch:improve` as the `eval_command`.
- **Sensor:** the script at `.claude/sensors/<name>.sh` is invocable on demand. Tell the user to optionally wire it into a hook for automatic firing.
- **Context-mgmt:** the report at `.claude/harness-report-<date>.md` is advisory. Tell the user to read it and act manually — the build command never edits agent files directly.

## Important notes

- Always produce Tier-1 only. Never emit a Tier-2 or Tier-3 scaffold.
- Never edit existing files in `.claude/agents/` or `.claude/skills/` — even for context-mgmt, only the advisory report is written.
- If the user types a component name that already exists at the destination, ask before overwriting (use AskUserQuestion: overwrite / pick new name).
- Always confirm the destination path before writing, e.g. "I'll write `.claude/hooks/<name>.json` — OK?"
