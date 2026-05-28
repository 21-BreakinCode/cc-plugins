#!/usr/bin/env bash
# Note template generator for zettelkasten-capture

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Generate a Zettelkasten draft note from session content
# Usage: zc_generate_note <title> <summary> <insights> <tags> <excalidraw_name>
# Outputs: note content as string
zc_generate_note() {
  local title="$1"
  local date
  date="$(date +%Y-%m-%d)"
  local summary="${2:-}"
  local insights="${3:-}"
  local tags="${4:-}"
  local excalidraw_name="${5:-}"

  cat <<EOF
---
title: ${title}
date: ${date}
tags: [${tags}]
status: draft
source: claude-session
---

## Summary

${summary}

## Key Insights

${insights}

## Details

<!-- Expand here -->

## Related

<!-- Add wikilinks: [[related-note]] -->

EOF

  if [ -n "$excalidraw_name" ]; then
    echo "## Diagrams"
    echo ""
    echo "![[${excalidraw_name}.excalidraw]]"
    echo ""
  fi
}

# Generate a blank excalidraw stub file
zc_generate_excalidraw_stub() {
  cat <<'EOF'
{
  "type": "excalidraw",
  "version": 2,
  "source": "zettelkasten-capture",
  "elements": [],
  "appState": {
    "gridSize": null,
    "viewBackgroundColor": "#ffffff"
  },
  "files": {}
}
EOF
}
