---
description: "Full video creation pipeline: style -> generate -> preview -> verify -> render"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "WebSearch", "WebFetch", "mcp__plugin_playwright_playwright__browser_navigate", "mcp__plugin_playwright_playwright__browser_take_screenshot", "mcp__plugin_playwright_playwright__browser_click", "mcp__plugin_playwright_playwright__browser_snapshot", "mcp__plugin_playwright_playwright__browser_wait_for"]
---

# /remotion-maker:create

End-to-end video creation pipeline with user gates at preview and approval.

## Usage
```
/remotion-maker:create                                    # interactive
/remotion-maker:create --format story-9-16                # vertical format
/remotion-maker:create --style tech-minimal               # use specific style
/remotion-maker:create --format youtube-16-9 --style my-brand  # both flags
```

## Pipeline

### Phase 1: Style
1. Parse --style flag. Otherwise check `.remotion-maker/styles/` for existing styles.
2. If style exists, load and confirm: "Using style '[name]'. Proceed?"
3. If none, spawn **style-definer** agent.

### Phase 2: Content
4. Ask: "What content should this video present? Paste a script, bullet points, blog post, or describe scenes."
5. Ask about media: "Do you have images, videos, or audio to include? Provide paths, or I can search free resources later."
6. Confirm format: use --format flag, otherwise ask "YouTube 16:9 (default) or Story 9:16?"

### Phase 3: Generate
7. Spawn **video-generator** agent with: content, style name, format, media assets, project path. The generator will create scene plan (confirm with user), source media if needed, generate TSX, scaffold project if needed, render preview frames.

### Phase 4: Preview Gate
8. Show preview frames from `.remotion-maker/preview/`.
9. Ask: "Options: **approve** — proceed to verification | **adjust [scene N]** — regenerate specific scene | **regenerate** — start over with new instructions"
10. Loop until approved.

### Phase 5: Verify
11. Spawn **video-verifier** agent in default mode (Tier 1+2).
12. Read report from `.remotion-maker/verify/report.md`.
13. If fails: present issues, ask "Fix and re-verify, or proceed anyway?"

### Phase 6: Approval Gate
14. Present summary: style, format (WxH), scenes count, duration, verification status. Ask: "Render the final MP4?"

### Phase 7: Render
15. If approved: `npx remotion render src/index.ts <composition-id> out/<video-name>.mp4`
16. Report: "Video rendered to `out/<video-name>.mp4`."

## Important Rules
- Never skip user gates — always pause at preview and approval
- One phase at a time
- Use existing style if available
- Source lib for directory setup:
  ```bash
  source "${CLAUDE_PLUGIN_ROOT}/lib/common.sh"
  rm_ensure_dirs .
  ```
