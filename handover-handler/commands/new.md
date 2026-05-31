---
description: "Create a well-formed handover document under ./handover/ (= LifeOS via symlink) seeded from the current conversation context."
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion"]
argument-hint: "<topic>"
---

# /hh:new

Create a new handover document. The topic argument becomes the slug. Frontmatter, filename, and a seed body are filled in automatically. The new file lands under the canonical LifeOS path via the `./handover` symlink.

## Vault location

```bash
LIFEOS="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

## Flow

### Phase 1 — Verify the symlink

```bash
[ -L "./handover" ] || { echo "Run /hh:init-service first — ./handover is not a symlink."; exit 1; }
readlink -e "./handover" >/dev/null || { echo "LifeOS target unreachable — check iCloud sync."; exit 3; }
```

If either check fails, stop and report.

### Phase 2 — Resolve ORG + APP_NAME

```bash
ORG=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh") || { echo "Could not resolve ORG"; exit 1; }
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-service.sh" "$PWD" "$ORG") || { echo "Could not resolve service"; exit 1; }
APP_NAME="${RESULT%%|*}"
```

### Phase 3 — Build filename

- `TOPIC` = the slash-command argument (`$ARGUMENTS`). If missing, `AskUserQuestion` for a free-form topic.
- `PREFIX` = `$APP_NAME` converted from PascalCase/camelCase to kebab-case.
  - Examples: `CreativeStudio` → `creative-studio`, `CrPerf2` → `cr-perf-2`, `BustDice` → `bust-dice`, `bustBackend` → `bust-backend`.
  - Algorithm: insert `-` before each uppercase letter (except position 0), lowercase the result, collapse repeated `-`.
- `SLUG` = topic kebab-cased, lowercased, non-alphanumerics → `-`, collapsed repeats, trimmed to 60 chars.
- `DATE` = `$(date +%Y-%m-%d)`.
- `FILENAME` = `${PREFIX}__${DATE}-${SLUG}.md`.

### Phase 4 — Seed body

Read the current conversation context, then fill the template below. The whole document must read in **≤ 1.5 min** (target ≤ 330 words total). Keep each section to its budget — if you run long, cut.

Capture, from the conversation:
- Working directory (the value of `$PWD` at the time of the handover).
- Key file paths touched or referenced.
- The last concrete action that was taken.
- The intended next action.
- Any open decisions or blockers.

Build the file content:

```markdown
---
created: $DATE
project: $APP_NAME
status: open
tags:
  - handover
  - <PREFIX-as-tag>
---

# $APP_NAME — $TOPIC

<!-- Total target: ≤ 330 words / ≤ 1.5 min read. Trim aggressively. -->

## TL;DR

<!-- ≤ 1 line. One sentence: what this handover is about + current state. -->

## Context/Background

<!-- ≤ 60 words / 3–5 lines. Why this work exists, who/what it touches, why now. No history dump — just enough so a fresh reader understands the stakes. -->

## As-Is

<!-- ≤ 60 words / 3–6 bullets. The current state of the world right now: what exists, what works, what's broken. Concrete, observable. No opinions. -->

- 

## To-Be

<!-- ≤ 60 words / 3–6 bullets. The target state: what "done" looks like. Outcomes, not tasks. -->

- 

## Implementation Note

<!-- ≤ 120 words. Paste-ready prompt for a *new* Claude session. Present-tense, addresses Claude directly. Must name: cwd, key file paths, last action, next action. Self-contained — a fresh session with zero prior context should be able to continue from this block alone. -->

I'm continuing work on **$APP_NAME — $TOPIC**.

- Working directory: `{cwd}`
- Key files: `{path/one}`, `{path/two}`
- Last action: `{what was just done}`
- Next action: `{what to do next}`

Please read the files above, confirm you understand the state, then proceed with the next action. Ask before changing anything outside the listed files.
```

### Phase 5 — Write

```bash
TARGET="./handover/$FILENAME"
[ -e "$TARGET" ] && { echo "File already exists: $TARGET"; exit 1; }
```

Use `Write` to create the file at `$TARGET`.

### Phase 6 — Report

Print:
```
Created: $TARGET
  Resolved to LifeOS: $(readlink -e "$TARGET")

Open it in Obsidian to refine TL;DR / To-Be.
```

## Non-negotiable rules

- Never overwrite an existing file. If filename collides, stop and report.
- Filename pattern is fixed: `<prefix>__<YYYY-MM-DD>-<slug>.md`. Do not invent variations.
- `tags` always includes `handover`. Never include `archive` here.
- `status: open` is the only initial status. Wrap-up changes it later.
