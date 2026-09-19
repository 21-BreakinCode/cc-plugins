#!/usr/bin/env python3
import json
import sys

try:
    file_path = json.load(sys.stdin).get("tool_input", {}).get("file_path", "")
except (json.JSONDecodeError, AttributeError):
    sys.exit(0)

if file_path.endswith(".md"):
    message = (
        "This edit touched a markdown file. Apply note-visualizer's visualize "
        "skill: prefer compact ASCII diagrams (never Mermaid) for spatial "
        "concepts (nesting, layers, flow, comparison, branching, sequence), "
        "and wrap key blocks in Obsidian callouts. Skip flat or linear content "
        "where a diagram adds nothing."
    )
    print(json.dumps({"systemMessage": message}))
