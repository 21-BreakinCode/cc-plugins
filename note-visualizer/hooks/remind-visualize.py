#!/usr/bin/env python3
import json
import sys

try:
    file_path = json.load(sys.stdin).get("tool_input", {}).get("file_path", "")
except (json.JSONDecodeError, AttributeError):
    sys.exit(0)

ZETTELKASTEN_DIR_MARKER = "/Zettelkasten/"

if file_path.endswith(".md") and ZETTELKASTEN_DIR_MARKER in file_path:
    message = (
        "This edit touched a Zettelkasten note. Apply note-visualizer's visualize "
        "skill: prefer compact ASCII diagrams (never Mermaid) for spatial "
        "concepts (nesting, layers, flow, comparison, branching, sequence), "
        "and wrap key blocks in Obsidian callouts. Skip flat or linear content "
        "where a diagram adds nothing."
    )
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": message}}))
