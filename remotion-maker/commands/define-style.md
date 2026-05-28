---
description: "Create or manage video style definitions for consistent series look and feel"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion"]
---

# /remotion-maker:define-style

Create, view, or modify style definitions for your video series.

## Usage
```
/remotion-maker:define-style              # create new or pick existing
/remotion-maker:define-style <name>       # view/edit a specific style
```

## What This Does
Spawns the **style-definer** agent which guides you through creating a style definition — a markdown file that defines colors, fonts, transitions, animations, and qualitative guidelines for a series of videos. Styles are stored in `.remotion-maker/styles/` and reused across videos.

## Execution
1. Ensure project data directory exists:
   ```bash
   source "$(find ~/.claude/plugins -path '*/remotion-maker/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
   rm_ensure_dirs .
   ```
2. If a style name was provided as argument, check if it exists. If exists: read and display, ask what to change. If not: start creation with that name pre-filled.
3. Spawn the style-definer agent via Agent tool with subagent_type "general-purpose". Include the full style-definer agent instructions, the project path, and any user-provided style name.
4. Report result: "Style '[name]' saved to `.remotion-maker/styles/<name>.md`."
