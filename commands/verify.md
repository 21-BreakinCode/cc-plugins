---
description: "Verify generated Remotion video against style definition (3-tier: static, frame sampling, Playwright)"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "mcp__plugin_playwright_playwright__browser_navigate", "mcp__plugin_playwright_playwright__browser_take_screenshot", "mcp__plugin_playwright_playwright__browser_click", "mcp__plugin_playwright_playwright__browser_snapshot", "mcp__plugin_playwright_playwright__browser_wait_for"]
---

# /remotion-maker:verify

Verify that generated Remotion video code matches the style definition and follows best practices.

## Usage
```
/remotion-maker:verify                        # default: Tier 1 + 2
/remotion-maker:verify --deep                 # all 3 tiers (includes Playwright)
/remotion-maker:verify --static-only          # Tier 1 only (fastest)
/remotion-maker:verify --style <name>         # verify against specific style
/remotion-maker:verify --composition <path>   # verify specific composition
```

## What This Does
Spawns the **video-verifier** agent which runs up to 3 tiers:
- **Tier 1 (Static):** Grep-based code analysis — palette, fonts, transitions, animations, Remotion rules, structure. Always runs.
- **Tier 2 (Frames):** Visual inspection of preview frames from `.remotion-maker/preview/`. Default on.
- **Tier 3 (Playwright):** Launch Remotion Studio, play composition, screenshot and inspect. Only with `--deep`.

## Execution
1. Parse flags: `--deep` → mode "deep", `--static-only` → mode "static-only", `--style <name>`, `--composition <path>`. Default → mode "default" (Tier 1+2).
2. If no style specified, find most recently modified style in `.remotion-maker/styles/`.
3. If no composition specified, find most recently modified in `src/compositions/`.
4. Spawn video-verifier agent with mode, style path, composition path, project path.
5. Read and display report from `.remotion-maker/verify/report.md`.
