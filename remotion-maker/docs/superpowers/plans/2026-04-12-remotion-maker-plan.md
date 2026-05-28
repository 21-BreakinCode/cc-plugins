# Remotion-Maker Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that generates Remotion videos with consistent style, automated media sourcing, staged preview, and multi-tier verification.

**Architecture:** Hybrid orchestrator + standalone commands pattern (mirrors autoresearch). 4 agents (style-definer, media-sourcer, video-generator, video-verifier) coordinated by a `/create` orchestrator command. Forked remotion-dev/skills with 4 custom extensions. All state in per-project `.remotion-maker/` directory.

**Tech Stack:** Claude Code plugin system (markdown frontmatter), Remotion (React video framework), shell scripts (bash), Playwright MCP (tier 3 verification).

---

## File Map

| File | Responsibility |
|------|---------------|
| `.claude-plugin/plugin.json` | Plugin metadata (name, version, author) |
| `lib/common.sh` | Shell constants (`RM_*`), directory setup, `rm_` helper functions |
| `presets/tech-minimal.md` | Built-in style preset: dark tech theme |
| `presets/bold-marketing.md` | Built-in style preset: high-energy marketing |
| `presets/storyteller-warm.md` | Built-in style preset: warm narrative tone |
| `templates/youtube-16-9.md` | Format config: 1920x1080, layout rules |
| `templates/story-9-16.md` | Format config: 1080x1920, layout rules |
| `skills/remotion/SKILL.md` | Remotion best practices index (forked + extended) |
| `skills/remotion/rules/*.md` | 35 forked rule files from remotion-dev/skills |
| `skills/remotion/rules/assets/*.tsx` | 3 forked asset files from remotion-dev/skills |
| `skills/remotion/extensions/style-system.md` | How to parse style defs into Remotion code |
| `skills/remotion/extensions/scene-patterns.md` | 6 reusable scene type templates |
| `skills/remotion/extensions/format-layouts.md` | Layout rules per format (16:9, 9:16) |
| `skills/remotion/extensions/verification-rules.md` | Codified checks for 3 verification tiers |
| `agents/style-definer.md` | Hybrid preset + conversation style creation |
| `agents/media-sourcer.md` | Free resource search + download |
| `agents/video-generator.md` | Content to scene plan to TSX gen to preview |
| `agents/video-verifier.md` | 3-tier style + structural verification |
| `commands/define-style.md` | `/remotion-maker:define-style` standalone |
| `commands/find-media.md` | `/remotion-maker:find-media` standalone |
| `commands/verify.md` | `/remotion-maker:verify` standalone |
| `commands/create.md` | `/remotion-maker:create` orchestrator |
| `README.md` | Quick-start and file structure |

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `lib/common.sh`
- Create: `README.md`

- [ ] **Step 1: Create plugin.json**

Create `.claude-plugin/plugin.json`:

```json
{
  "name": "remotion-maker",
  "description": "Generate Remotion videos with consistent style, media sourcing, and multi-tier verification",
  "version": "0.1.0",
  "author": {
    "name": "William Hung"
  }
}
```

- [ ] **Step 2: Create lib/common.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Constants
RM_PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RM_DATA_DIR=".remotion-maker"
RM_STYLES_DIR="${RM_DATA_DIR}/styles"
RM_MEDIA_DIR="${RM_DATA_DIR}/media/sourced"
RM_PREVIEW_DIR="${RM_DATA_DIR}/preview"
RM_VERIFY_DIR="${RM_DATA_DIR}/verify"

# Directory Setup
rm_ensure_dirs() {
  local project_dir="${1:-.}"
  mkdir -p "${project_dir}/${RM_STYLES_DIR}"
  mkdir -p "${project_dir}/${RM_MEDIA_DIR}"
  mkdir -p "${project_dir}/${RM_PREVIEW_DIR}"
  mkdir -p "${project_dir}/${RM_VERIFY_DIR}"
}

# Style Helpers
rm_list_styles() {
  local project_dir="${1:-.}"
  local styles_dir="${project_dir}/${RM_STYLES_DIR}"
  if [ -d "$styles_dir" ]; then
    find "$styles_dir" -name '*.md' -print 2>/dev/null | while read -r f; do
      basename "$f" .md
    done
  fi
}

rm_style_exists() {
  local project_dir="${1:-.}"
  local name="$2"
  [ -f "${project_dir}/${RM_STYLES_DIR}/${name}.md" ]
}

# Preset Helpers
rm_list_presets() {
  find "${RM_PLUGIN_DIR}/presets" -name '*.md' -print 2>/dev/null | while read -r f; do
    basename "$f" .md
  done
}

rm_read_preset() {
  local name="$1"
  local preset_file="${RM_PLUGIN_DIR}/presets/${name}.md"
  if [ -f "$preset_file" ]; then
    cat "$preset_file"
  else
    echo "ERROR: Preset '${name}' not found" >&2
    return 1
  fi
}

# Preview Helpers
rm_clear_preview() {
  local project_dir="${1:-.}"
  rm -f "${project_dir}/${RM_PREVIEW_DIR}"/frame-*.png
}

rm_list_preview_frames() {
  local project_dir="${1:-.}"
  find "${project_dir}/${RM_PREVIEW_DIR}" -name 'frame-*.png' -print 2>/dev/null | sort
}
```

- [ ] **Step 3: Create README.md**

See spec for content. Include: commands table, quick start steps, style presets list, project data structure.

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json lib/common.sh README.md
git commit -m "feat: scaffold remotion-maker plugin with metadata, shell lib, and README"
```

---

### Task 2: Fork Remotion Skills

**Files:**
- Create: `skills/remotion/rules/*.md` (35 files)
- Create: `skills/remotion/rules/assets/*.tsx` (3 files)

- [ ] **Step 1: Clone and copy rule files**

```bash
TEMP_DIR=$(mktemp -d)
git clone --depth 1 https://github.com/remotion-dev/skills.git "$TEMP_DIR"
mkdir -p skills/remotion/rules/assets
cp "$TEMP_DIR"/skills/remotion/rules/*.md skills/remotion/rules/
cp "$TEMP_DIR"/skills/remotion/rules/assets/*.tsx skills/remotion/rules/assets/
rm -rf "$TEMP_DIR"
```

- [ ] **Step 2: Verify file count**

Run: `ls skills/remotion/rules/*.md | wc -l && ls skills/remotion/rules/assets/*.tsx | wc -l`
Expected: ~35 rule files, 3 asset files

- [ ] **Step 3: Commit**

```bash
git add skills/remotion/rules/
git commit -m "feat: fork remotion-dev/skills rules and assets verbatim"
```

---

### Task 3: SKILL.md Index

**Files:**
- Create: `skills/remotion/SKILL.md`

- [ ] **Step 1: Fetch original SKILL.md**

```bash
curl -sL https://raw.githubusercontent.com/remotion-dev/skills/main/skills/remotion/SKILL.md > skills/remotion/SKILL.md
```

- [ ] **Step 2: Append extensions section**

Add at the end of SKILL.md:

```markdown

## Remotion-Maker Extensions

These extensions are specific to the remotion-maker plugin and provide guidance on style-driven video generation.

- **Style System** — load [./extensions/style-system.md](./extensions/style-system.md) when working with `.remotion-maker/styles/*.md` definitions, parsing YAML frontmatter into Remotion code, or generating `styles.ts` files.
- **Scene Patterns** — load [./extensions/scene-patterns.md](./extensions/scene-patterns.md) when generating scene components (title-card, content, code, chart, image-showcase, outro).
- **Format Layouts** — load [./extensions/format-layouts.md](./extensions/format-layouts.md) when creating compositions for different aspect ratios (16:9, 9:16) or adapting scenes between formats.
- **Verification Rules** — load [./extensions/verification-rules.md](./extensions/verification-rules.md) when verifying generated code against a style definition.
```

- [ ] **Step 3: Commit**

```bash
git add skills/remotion/SKILL.md
git commit -m "feat: add SKILL.md index with extensions section"
```

---

### Task 4: Extension — style-system.md

**Files:**
- Create: `skills/remotion/extensions/style-system.md`

- [ ] **Step 1: Create style-system.md**

Frontmatter:
```yaml
---
name: style-system
description: "How to parse .remotion-maker/styles/*.md definitions into Remotion TypeScript code"
metadata:
  tags: style, palette, fonts, animations, config
---
```

Content sections:
1. **Reading a Style Definition** — explain the two-part format (YAML frontmatter + prose body)
2. **Generating styles.ts** — full TSX example showing how to export typed constants (PALETTE, FONTS, TRANSITIONS, ANIMATIONS, LAYOUT) from frontmatter values
3. **Mapping to Remotion APIs:**
   - Palette to component colors (always use `PALETTE` constants, never hardcode hex)
   - Fonts to `@remotion/google-fonts` `loadFont()` calls with weight selection
   - Animations entrance to `interpolate()` with `Easing.bezier()`, emphasis to `spring()` config
   - Transitions to `@remotion/transitions` imports (slide, fade, wipe, flip, clockWipe) with `linearTiming`/`springTiming`
4. **Important Rules** — never hardcode colors, never use CSS animations, one styles.ts per composition, respect prose guidelines

Each section includes complete copy-paste TSX code blocks.

- [ ] **Step 2: Commit**

```bash
git add skills/remotion/extensions/style-system.md
git commit -m "feat: add style-system extension for parsing style defs into Remotion code"
```

---

### Task 5: Extension — scene-patterns.md

**Files:**
- Create: `skills/remotion/extensions/scene-patterns.md`

- [ ] **Step 1: Create scene-patterns.md**

Frontmatter:
```yaml
---
name: scene-patterns
description: "Reusable Remotion scene component templates for 6 scene types: title-card, content, code, chart, image-showcase, outro"
metadata:
  tags: scenes, components, templates, composition
---
```

Content: 6 complete scene component implementations, each as a full TSX code block:

1. **title-card** — `TitleCard` component. Props: `title`, `subtitle?`. AbsoluteFill centered, heading with bezier entrance (opacity + translateY), subtitle fade-in delayed by entrance duration + 10 frames.

2. **content** — `ContentScene` component. Props: `heading`, `bullets[]`, `mediaUrl?`, `mediaPosition?`. Two-column flexbox (55/45 split), staggered bullet entrance (8 frame delay each), `<Img>` for media.

3. **code** — `CodeScene` component. Props: `title`, `code`, `charsPerFrame?`. Typewriter effect via string slicing (`code.slice(0, charsVisible)`), blinking cursor with frame % 30, dark code block background (#0F172A).

4. **chart** — `ChartScene` component. Props: `title`, `data: {label, value}[]`. Spring-animated bar heights with staggered delay per bar (`frame - i * 5`), alternating primary/accent colors.

5. **image-showcase** — `ImageShowcase` component. Props: `imageUrl`, `caption`. Full-bleed `<Img>` with Ken Burns zoom (`scale` interpolate 1 to 1.05 over 150 frames), gradient overlay at bottom for caption.

6. **outro** — `Outro` component. Props: `channelName`, `callToAction?`. Centered name with entrance animation, CTA button with spring scale.

Final section: **Usage in Compositions** — `<TransitionSeries>` example wiring scenes together.

All components import from `../styles` and use `PALETTE`, `FONTS`, `ANIMATIONS`, `LAYOUT` constants.

- [ ] **Step 2: Commit**

```bash
git add skills/remotion/extensions/scene-patterns.md
git commit -m "feat: add scene-patterns extension with 6 reusable scene templates"
```

---

### Task 6: Extension — format-layouts.md

**Files:**
- Create: `skills/remotion/extensions/format-layouts.md`

- [ ] **Step 1: Create format-layouts.md**

Frontmatter:
```yaml
---
name: format-layouts
description: "Layout rules for YouTube 16:9 and Story 9:16 formats with adaptation patterns"
metadata:
  tags: layout, format, aspect-ratio, responsive
---
```

Content sections:

1. **YouTube 16:9** — 1920x1080, safe zone diagram (96px sides, 84px top/bottom), title card rules (64-80px heading, centered), content scenes (55/45 column split, 40px gap), code scenes (85% max width, 16-20px mono).

2. **Story 9:16** — 1080x1920, safe zone diagram (120px top for status bar, 180px bottom for gestures), title card (56-64px heading, 35% from top), content scenes (vertical stack not columns), code scenes (14-16px mono, full width - 40px padding).

3. **Adapting Between Formats** — 6 rules: reduce font ~15%, side-by-side becomes vertical stack, reduce code font, max 4 chart bars in 9:16, same image-showcase approach, reduce CTA button width.

4. **Composition Config** — `<Composition>` registration TSX for each format.

- [ ] **Step 2: Commit**

```bash
git add skills/remotion/extensions/format-layouts.md
git commit -m "feat: add format-layouts extension for 16:9 and 9:16 layout rules"
```

---

### Task 7: Extension — verification-rules.md

**Files:**
- Create: `skills/remotion/extensions/verification-rules.md`

- [ ] **Step 1: Create verification-rules.md**

Frontmatter:
```yaml
---
name: verification-rules
description: "Codified verification checks for the video-verifier agent across 3 tiers: static code analysis, frame sampling, and Playwright playback"
metadata:
  tags: verification, testing, quality, style-drift
---
```

Content — 3 major sections:

**Tier 1: Static Code Analysis** (6 checks with exact regex patterns):
- 1.1 Palette Check: `/#[0-9A-Fa-f]{6}\b/` — match all hex colors, compare to style def palette. Exception: #FFFFFF, #000000, and code block bg.
- 1.2 Font Check: `/fontFamily:\s*["']([^"']+)["']/` and `/loadFont.*@remotion\/google-fonts\/(\w+)/` — bidirectional match.
- 1.3 Transition Check: `/import.*@remotion\/transitions\/([\w]+)/` — only allowed types. Duration within +/-3 frames.
- 1.4 Animation Check: Forbidden patterns (`animate-`, `transition:`, `animation:`). Required: `useCurrentFrame` in every scene file.
- 1.5 Remotion Practices: Forbidden `<img\s`, `<video\s`, `<audio\s`. Required: `staticFile`.
- 1.6 Structure: Root.tsx registration with correct id, width, height, fps.
- Report format template.

**Tier 2: Frame Sampling** (4 visual checks):
- 2.1 Layout (text cut-off, overlaps, padding, safe zones)
- 2.2 Visual consistency (colors, fonts, image sizing)
- 2.3 Composition (centering, balance, empty frames)
- 2.4 Render health (error states, broken images, loading messages)
- Report format template.

**Tier 3: Playwright Playback** (setup + 2 checks):
- 3.1 Setup: `npx remotion studio &`, wait 5s, Playwright navigate to localhost:3000
- 3.2 Playback: screenshot at frame 0, each transition, mid-scenes, last frame. Compare sequential screenshots for jump detection.
- 3.3 Audio sync (if applicable)
- 3.4 Cleanup: kill studio process
- Report format template.

**Overall Report** — frontmatter format (video, style, tiers_run, pass, warnings, errors) + pass criteria.

- [ ] **Step 2: Commit**

```bash
git add skills/remotion/extensions/verification-rules.md
git commit -m "feat: add verification-rules extension with 3-tier check definitions"
```

---

### Task 8: Style Presets

**Files:**
- Create: `presets/tech-minimal.md`
- Create: `presets/bold-marketing.md`
- Create: `presets/storyteller-warm.md`

- [ ] **Step 1: Create presets/tech-minimal.md**

YAML frontmatter with: name `tech-minimal`, palette (background #1E293B, primary #3B82F6, accent #10B981, text #F1F5F9, text_secondary #94A3B8), fonts (Inter heading 700, Inter body 400, JetBrains Mono code 400), transitions ([slide, fade], 12 frames, easeInOut), animations (slide-up entrance 15 frames bezier, spring emphasis damping 12, typewriter text), layout (padding 60, center title, left content).

Prose: snappy transitions under 15 frames, typewriter text only, code blocks with #0F172A background, stagger 8 frames.

- [ ] **Step 2: Create presets/bold-marketing.md**

YAML frontmatter with: name `bold-marketing`, palette (background #FFFFFF, primary #FF6B35, accent #FFD700, text #1A1A2E, text_secondary #4A4A6A), fonts (Poppins heading 800, Poppins body 400), transitions ([wipe, slide], 10 frames, easeOut), animations (scale-up entrance 12 frames overshoot bezier, spring emphasis damping 8, typewriter text), layout (padding 80, center title, center content).

Prose: energetic, punchy, overshoot easing, accent gold sparingly, bright white background.

- [ ] **Step 3: Create presets/storyteller-warm.md**

YAML frontmatter with: name `storyteller-warm`, palette (background #FFF8F0, primary #8B5E3C, accent #D4A574, text #2C1810, text_secondary #6B4F3A), fonts (Merriweather heading 700, Lato body 400), transitions ([fade], 20 frames, easeInOut), animations (fade-in entrance 25 frames gentle bezier, spring emphasis damping 20, typewriter text), layout (padding 80, center title, left content).

Prose: gentle, intentional, slow fades, warm and inviting, generous whitespace, line-height 1.8.

- [ ] **Step 4: Commit**

```bash
git add presets/
git commit -m "feat: add 3 built-in style presets (tech-minimal, bold-marketing, storyteller-warm)"
```

---

### Task 9: Format Templates

**Files:**
- Create: `templates/youtube-16-9.md`
- Create: `templates/story-9-16.md`

- [ ] **Step 1: Create templates/youtube-16-9.md**

Frontmatter: name `youtube-16-9`, width 1920, height 1080, fps 30, safe_zone (top 84, bottom 84, left 96, right 96).

Body: Composition registration TSX snippet, render command (`npx remotion render`), preview command (`npx remotion still`).

- [ ] **Step 2: Create templates/story-9-16.md**

Frontmatter: name `story-9-16`, width 1080, height 1920, fps 30, safe_zone (top 120, bottom 180, left 60, right 60).

Body: Same structure as youtube-16-9 but with 9:16 dimensions.

- [ ] **Step 3: Commit**

```bash
git add templates/
git commit -m "feat: add format templates for youtube-16-9 and story-9-16"
```

---

### Task 10: Agent — style-definer.md

**Files:**
- Create: `agents/style-definer.md`

- [ ] **Step 1: Create agents/style-definer.md**

Frontmatter:
```yaml
---
name: style-definer
description: "Style definition agent. Creates and manages .remotion-maker/styles/*.md files through a hybrid preset + conversation workflow. Spawned by /remotion-maker:create when no style exists, or directly via /remotion-maker:define-style."
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
---
```

Body sections:
1. **Before You Start** — read style-system extension, source lib/common.sh
2. **Workflow Step 1: Check Existing Styles** — `rm_list_styles .`, offer reuse/modify/create
3. **Workflow Step 2: Offer Presets** — `rm_list_presets`, present 3 presets + blank option
4. **Workflow Step 3: Refine Through Conversation** — two question flows (blank canvas: 6 questions about feel/background/color/fonts/transitions/format; preset customization: 2 questions about what to change)
5. **Workflow Step 4: Write Style File** — `rm_ensure_dirs .`, write to `.remotion-maker/styles/<name>.md`
6. **Workflow Step 5: Confirm** — show complete style, ask for adjustments
7. **Important Rules** — one question at a time, show concrete values, validate hex codes, write immutably

- [ ] **Step 2: Commit**

```bash
git add agents/style-definer.md
git commit -m "feat: add style-definer agent with hybrid preset + conversation workflow"
```

---

### Task 11: Agent — media-sourcer.md

**Files:**
- Create: `agents/media-sourcer.md`

- [ ] **Step 1: Create agents/media-sourcer.md**

Frontmatter:
```yaml
---
name: media-sourcer
description: "Media sourcing agent. Searches free resource sites (Unsplash, Pexels, Pixabay, Freesound) for images, videos, and audio matching scene requirements. Spawned by video-generator when scenes have unresolved media needs."
tools: ["Read", "Write", "Bash", "WebSearch", "WebFetch", "AskUserQuestion"]
---
```

Body sections:
1. **Input** — list of unresolved media needs with scene number, type, description, media type
2. **Sources** — table of 4 sources with search strategy (`site:unsplash.com <query>`, etc.)
3. **Workflow per media need** — craft specific query, WebSearch, evaluate results (resolution, relevance, license), download to `.remotion-maker/media/sourced/scene-<N>-<desc>.jpg`, present to user for approval
4. **Important Rules** — always ask before using, one scene at a time, free licenses only, descriptive filenames, report skipped scenes

- [ ] **Step 2: Commit**

```bash
git add agents/media-sourcer.md
git commit -m "feat: add media-sourcer agent for free resource search and download"
```

---

### Task 12: Agent — video-generator.md

**Files:**
- Create: `agents/video-generator.md`

- [ ] **Step 1: Create agents/video-generator.md**

Frontmatter:
```yaml
---
name: video-generator
description: "Video generation agent. Transforms user content into Remotion TSX components with preview rendering. Spawned by /remotion-maker:create after style is defined, or handles the full generation pipeline."
tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion"]
---
```

Body sections:
1. **Before You Start** — load 4 skill files (SKILL.md, style-system, scene-patterns, format-layouts) + read user's style definition
2. **Input** — user content, style name, format, optional media assets
3. **Workflow Step 1: Parse Content into Scene Plan** — determine type/duration/text/media for each scene, present plan for user confirmation
4. **Workflow Step 2: Check Media Needs** — map user assets to scenes, ask about auto-sourcing for gaps, spawn media-sourcer agent if approved
5. **Workflow Step 3: Generate Remotion TSX** — generate styles.ts from style def, scene components from scene-patterns, composition index.tsx with TransitionSeries, update Root.tsx
6. **Workflow Step 4: Scaffold Project** — check for existing Remotion project (remotion.config.ts), `npx create-video@latest` if needed, install @remotion/transitions @remotion/google-fonts
7. **Workflow Step 5: Render Preview Frames** — `npx remotion still` at key moments, save to `.remotion-maker/preview/`
8. **Output structure** — `src/compositions/<name>/` with index.tsx, scenes/*.tsx, styles.ts
9. **Important Rules** — follow style def exactly, follow Remotion rules, never CSS animations, use Img/Video/Audio/staticFile, one component per file, show scene plan before generating

- [ ] **Step 2: Commit**

```bash
git add agents/video-generator.md
git commit -m "feat: add video-generator agent for content-to-TSX pipeline"
```

---

### Task 13: Agent — video-verifier.md

**Files:**
- Create: `agents/video-verifier.md`

- [ ] **Step 1: Create agents/video-verifier.md**

Frontmatter:
```yaml
---
name: video-verifier
description: "Video verification agent. Checks generated Remotion code against style definitions using 3 tiers: static code analysis, frame sampling, and Playwright playback. Spawned by /remotion-maker:create after preview, or directly via /remotion-maker:verify."
tools: ["Read", "Write", "Bash", "Glob", "Grep", "AskUserQuestion", "mcp__plugin_playwright_playwright__browser_navigate", "mcp__plugin_playwright_playwright__browser_take_screenshot", "mcp__plugin_playwright_playwright__browser_click", "mcp__plugin_playwright_playwright__browser_snapshot", "mcp__plugin_playwright_playwright__browser_wait_for"]
---
```

Body sections:
1. **Before You Start** — load verification-rules and style-system extensions, read style definition
2. **Input** — composition path, style name, mode (default/deep/static-only)
3. **Tier 1: Static Code Analysis** — read style def frontmatter, grep TSX files for all 6 checks from verification-rules, compile report
4. **Tier 2: Frame Sampling** — list preview frames, read each PNG, inspect visually for 4 checks, compile report
5. **Tier 3: Playwright Playback** — start remotion studio in background, Playwright navigate + play + screenshot, inspect motion/timing, cleanup (kill studio), compile report
6. **Write Report** — combine tiers into `.remotion-maker/verify/report.md`, present summary to user
7. **Important Rules** — read verification-rules extension first, be specific about failures (file, line, expected vs actual), warnings non-blocking, don't auto-fix

- [ ] **Step 2: Commit**

```bash
git add agents/video-verifier.md
git commit -m "feat: add video-verifier agent with 3-tier verification"
```

---

### Task 14: Command — define-style.md

**Files:**
- Create: `commands/define-style.md`

- [ ] **Step 1: Create commands/define-style.md**

Frontmatter:
```yaml
---
description: "Create or manage video style definitions for consistent series look and feel"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion"]
---
```

Body: Usage section (with/without name argument), what it does (spawns style-definer agent), execution steps (ensure dirs, check if name exists, spawn agent, report result).

- [ ] **Step 2: Commit**

```bash
git add commands/define-style.md
git commit -m "feat: add /remotion-maker:define-style command"
```

---

### Task 15: Command — find-media.md

**Files:**
- Create: `commands/find-media.md`

- [ ] **Step 1: Create commands/find-media.md**

Frontmatter:
```yaml
---
description: "Search free resources for media assets (images, videos, audio) for video scenes"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "WebSearch", "WebFetch"]
---
```

Body: Usage section (with/without description), what it does (spawns media-sourcer agent), execution steps (ensure dirs, ask for description if not provided, spawn agent, report results).

- [ ] **Step 2: Commit**

```bash
git add commands/find-media.md
git commit -m "feat: add /remotion-maker:find-media command"
```

---

### Task 16: Command — verify.md

**Files:**
- Create: `commands/verify.md`

- [ ] **Step 1: Create commands/verify.md**

Frontmatter:
```yaml
---
description: "Verify generated Remotion video against style definition (3-tier: static, frame sampling, Playwright)"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "mcp__plugin_playwright_playwright__browser_navigate", "mcp__plugin_playwright_playwright__browser_take_screenshot", "mcp__plugin_playwright_playwright__browser_click", "mcp__plugin_playwright_playwright__browser_snapshot", "mcp__plugin_playwright_playwright__browser_wait_for"]
---
```

Body: Usage section (5 invocation forms: default, --deep, --static-only, --style, --composition), what it does (spawns video-verifier agent), execution steps (parse flags, find most recent style/composition if not specified, spawn agent, display report).

- [ ] **Step 2: Commit**

```bash
git add commands/verify.md
git commit -m "feat: add /remotion-maker:verify command with 3 modes"
```

---

### Task 17: Command — create.md (Orchestrator)

**Files:**
- Create: `commands/create.md`

- [ ] **Step 1: Create commands/create.md**

Frontmatter:
```yaml
---
description: "Full video creation pipeline: style -> generate -> preview -> verify -> render"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "WebSearch", "WebFetch", "mcp__plugin_playwright_playwright__browser_navigate", "mcp__plugin_playwright_playwright__browser_take_screenshot", "mcp__plugin_playwright_playwright__browser_click", "mcp__plugin_playwright_playwright__browser_snapshot", "mcp__plugin_playwright_playwright__browser_wait_for"]
---
```

Body — 7 phases:
1. **Phase 1: Style** — parse --style flag, check existing styles, spawn style-definer agent if needed
2. **Phase 2: Content** — ask for content (script/bullets/blog), ask about media assets, confirm format (--format or ask)
3. **Phase 3: Generate** — spawn video-generator agent with all inputs
4. **Phase 4: Preview Gate** — show preview frames, ask approve/adjust/regenerate, loop until approved
5. **Phase 5: Verify** — spawn video-verifier agent in default mode, read report, present issues if any
6. **Phase 6: Approval Gate** — present final summary (style, format, scenes, duration, verification status), ask to render
7. **Phase 7: Render** — `npx remotion render src/index.ts <id> out/<name>.mp4`, report result

Important rules: never skip user gates, one phase at a time, use existing style if available, source lib for directory setup.

- [ ] **Step 2: Commit**

```bash
git add commands/create.md
git commit -m "feat: add /remotion-maker:create orchestrator command with full pipeline"
```

---

### Task 18: Marketplace Integration

**Files:**
- Modify: `../workflow-plugins-marketplace/.claude-plugin/marketplace.json`

- [ ] **Step 1: Read current marketplace.json**

```bash
cat ../workflow-plugins-marketplace/.claude-plugin/marketplace.json
```

- [ ] **Step 2: Add remotion-maker entry to plugins array**

```json
{
  "name": "remotion-maker",
  "source": {
    "source": "url",
    "url": "https://github.com/21-BreakinCode/remotion-maker.git"
  },
  "description": "Generate Remotion videos with consistent style, media sourcing, and multi-tier verification",
  "version": "0.1.0",
  "strict": true
}
```

- [ ] **Step 3: Commit marketplace change**

```bash
cd ../workflow-plugins-marketplace
git add .claude-plugin/marketplace.json
git commit -m "feat: add remotion-maker plugin to marketplace"
```

---

## Self-Review

**Spec coverage:**
- [x] Plugin structure (Task 1)
- [x] Fork remotion-dev/skills (Tasks 2-3)
- [x] 4 custom extensions (Tasks 4-7)
- [x] 3 presets (Task 8)
- [x] 2 format templates (Task 9)
- [x] Style-definer agent (Task 10)
- [x] Media-sourcer agent (Task 11)
- [x] Video-generator agent (Task 12)
- [x] Video-verifier agent (Task 13)
- [x] 4 commands including orchestrator (Tasks 14-17)
- [x] Shell library with rm_ prefix (Task 1)
- [x] Marketplace integration (Task 18)
- [x] Data contract directories (Task 1 lib)
- [x] 3-tier verification with modes (Tasks 7, 13, 16)
- [x] Orchestration with preview + approval gates (Task 17)

**Placeholder scan:** No TBDs, TODOs, or vague references.

**Type consistency:**
- Style definition format: consistent across presets, style-system, style-definer, video-generator
- File paths: `.remotion-maker/styles/`, `media/sourced/`, `preview/`, `verify/` consistent everywhere
- Shell prefix: `rm_` in lib/common.sh and referenced in agents/commands
- Agent names: style-definer, media-sourcer, video-generator, video-verifier match between agent files and command references
