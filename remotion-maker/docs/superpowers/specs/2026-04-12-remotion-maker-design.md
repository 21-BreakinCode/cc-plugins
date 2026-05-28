# Remotion-Maker Plugin Design

A Claude Code plugin that generates Remotion (React) videos with consistent style, automated media sourcing, staged preview, and multi-tier verification.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Style creation | Hybrid preset + conversation | Presets for speed, conversation for customization |
| Style storage | Per-project `.remotion-maker/styles/` | Co-located with code, git-trackable |
| Style format | Markdown with YAML frontmatter | Token-efficient (~200-350 tokens), machine-parseable + qualitative prose |
| Content input | Script/text + optional media assets | Covers most use cases, media-sourcer fills gaps |
| Output pipeline | Staged: code gen → preview → approval → render | Saves render cost, user stays in control |
| Architecture | Hybrid orchestrator + standalone commands | Guided flow for new users, individual commands for power users |
| Verification | 3-tier: static → frame sample → Playwright | Token-efficient by default, deep verification on request |
| Remotion skills | Fork + extend in separate `extensions/` dir | Full control, clean upstream sync path |

## Plugin Structure

```
remotion-maker/
├── .claude-plugin/plugin.json
├── commands/
│   ├── create.md              # /remotion-maker:create (orchestrator)
│   ├── define-style.md        # /remotion-maker:define-style
│   ├── find-media.md          # /remotion-maker:find-media
│   └── verify.md              # /remotion-maker:verify
├── agents/
│   ├── style-definer.md       # style conversation + preset hybrid
│   ├── media-sourcer.md       # free resource crawler
│   ├── video-generator.md     # TSX code gen + preview render
│   └── video-verifier.md      # 3-tier verification
├── skills/
│   └── remotion/              # forked from remotion-dev/skills
│       ├── SKILL.md           # main index (lazy-loads rules)
│       ├── rules/             # 35 original rule files + 3 assets
│       └── extensions/        # our custom additions
│           ├── style-system.md
│           ├── scene-patterns.md
│           ├── format-layouts.md
│           └── verification-rules.md
├── presets/
│   ├── tech-minimal.md
│   ├── bold-marketing.md
│   └── storyteller-warm.md
├── templates/
│   ├── youtube-16-9/          # 1920x1080 scaffold
│   └── story-9-16/            # 1080x1920 scaffold
├── lib/                       # shell utilities (rm_ prefix)
└── README.md
```

## Data Contract

All agents read/write to `.remotion-maker/` inside the user's Remotion project:

```
.remotion-maker/
├── styles/
│   └── <series-name>.md       # style definition (YAML frontmatter + prose)
├── media/
│   └── sourced/               # downloaded free resources
├── preview/
│   └── frame-*.png            # rendered preview frames
└── verify/
    └── report.md              # verification results
```

## Orchestration Flow

```
/remotion-maker:create [--format youtube-16-9|story-9-16] [--style <name>]
  → Check .remotion-maker/styles/ for existing styles (or use --style flag)
  → If none: spawn style-definer agent
  → User provides content (script, bullet points, etc.)
  → video-generator agent:
      1. Parse content → scene plan
      2. Check media needs → spawn media-sourcer if gaps exist
      3. Generate Remotion TSX (one component per scene)
      4. Scaffold project if needed (npx create-video@latest)
      5. Render preview frames (npx remotion still)
  → ⏸ PREVIEW GATE — user approves or requests changes
  → video-verifier agent:
      Tier 1: static code analysis
      Tier 2: frame sample inspection (reuses preview frames)
  → ⏸ APPROVAL GATE — user confirms final render
  → npx remotion render → MP4
```

Each sub-agent is also callable independently via standalone commands.

## Agent: Style-Definer

**Purpose:** Create and manage style definitions for video series consistency.

**Workflow:**
1. Check `.remotion-maker/styles/` — list existing styles. If user wants to reuse one, done.
2. Offer built-in presets from `presets/` folder as starting points (or blank canvas).
3. Conversation: ask about brand feel, refine palette, transitions, animations. One question at a time.
4. Write final style to `.remotion-maker/styles/<name>.md`.
5. Confirm with user.

**Style definition format:**

```yaml
---
name: tech-minimal
description: Clean dev/tech content series
based_on: presets/tech-minimal.md
format: youtube-16-9
fps: 30

palette:
  background: "#1E293B"
  primary: "#3B82F6"
  accent: "#10B981"
  text: "#F1F5F9"
  text_secondary: "#94A3B8"

fonts:
  heading: { family: Inter, weight: 700 }
  body: { family: Inter, weight: 400 }
  code: { family: JetBrains Mono, weight: 400 }

transitions:
  type: [slide, fade]
  duration_frames: 12
  easing: easeInOut

animations:
  entrance: { type: slide-up, duration: 15, easing: "bezier(0.25, 0.1, 0.25, 1)" }
  emphasis: { type: spring, damping: 12, mass: 0.5 }
  text: typewriter

layout:
  padding: 60
  title_position: center
  content_alignment: left
---

## Qualitative Guidelines

Transitions should feel snappy, not floaty. Keep scene transitions under 15 frames.
Text appears via typewriter only — no per-character opacity fades.

Code blocks use JetBrains Mono with a subtle background (#0F172A) and 16px horizontal padding.

## Component Patterns

Title cards: centered heading, subtitle fades in 10 frames after heading completes.
Content scenes: left-aligned body text, images/code on right. Stagger element entrances by 8 frames.
```

**Token budget:** ~200-350 tokens per style definition. Loaded once at start of video-generator and video-verifier runs.

**Built-in presets (3):**
- **Tech Minimal** — dark, clean, developer-focused. Inter + JetBrains Mono. Slide transitions.
- **Bold Marketing** — high contrast, energetic. Poppins bold. Spring animations, wipe transitions.
- **Storyteller Warm** — warm tones, narrative feel. Merriweather + Lato. Slow fades, gentle easing.

## Agent: Video-Generator

**Purpose:** Transform user content into Remotion TSX components with preview rendering.

**Input:** User content (script, bullet points, blog post) + style definition + optional media assets.

**Workflow:**

1. **Parse content → scene plan.** Break user content into scenes. Each scene gets: type (title, content, code, image, chart, outro), duration estimate, text content, media needs.

2. **Check media needs.** Scan scene plan for media references. If user provided assets, map them to scenes. If gaps exist, ask user: source automatically or skip? Spawns media-sourcer agent if approved.

3. **Generate Remotion TSX.** For each scene, generate a React component following: style definition (colors, fonts, easing), remotion rules (best practices from skills), format template (16:9 or 9:16), and scene plan (content + timing).

4. **Scaffold project (if needed).** If no Remotion project exists: `npx create-video@latest` + install deps. If project exists: add new composition files only.

5. **Render preview frames.** `npx remotion still` at key moments (first frame, mid-scene, transitions, outro) → save to `.remotion-maker/preview/`.

**Output file structure (in user's Remotion project):**

```
src/
├── compositions/
│   └── <video-name>/
│       ├── index.tsx           # main composition (registers scenes)
│       ├── scenes/
│       │   ├── TitleCard.tsx
│       │   ├── ContentScene.tsx
│       │   ├── CodeScene.tsx
│       │   └── Outro.tsx
│       └── styles.ts           # parsed from style def → TS constants
└── Root.tsx                    # updated to register new composition
```

**Format support:**
- YouTube 16:9 (default): 1920x1080, 30fps. Template: `templates/youtube-16-9/`
- Story 9:16: 1080x1920, 30fps. Template: `templates/story-9-16/`

**Skills referenced:** SKILL.md (lazy-loads relevant rules) + extensions/scene-patterns.md + extensions/format-layouts.md + extensions/style-system.md

## Agent: Media-Sourcer

**Purpose:** Find and download free media assets for scenes with unresolved media needs.

**Trigger:** Spawned by video-generator when scene plan has gaps and user approves auto-sourcing.

**Sources (free, attribution-friendly):**
- Unsplash — photos
- Pexels — photos + videos
- Pixabay — illustrations + vectors
- Freesound — audio/sfx

**Workflow:**
1. For each unresolved media need → WebSearch for matching free resources.
2. Download candidates to `.remotion-maker/media/sourced/`.
3. Present options to user: "Found these for Scene 2 — use any?"
4. User picks → agent maps to scene plan. User declines → scene uses text-only fallback.

**Skills referenced:** None — uses WebSearch directly.

## Agent: Video-Verifier

**Purpose:** Verify generated video matches style definition and Remotion best practices.

### Tier 1: Static Code Analysis (always runs)

Tools: Read, Grep only. ~0 extra tokens. ~2-5 seconds.

Checks:
- **Palette:** All hex colors in TSX match style def palette values. Flag hardcoded colors not in palette.
- **Fonts:** loadFont imports match style def font families. No unregistered font usage.
- **Transitions:** TransitionSeries uses only allowed transition types. Duration within spec range.
- **Animations:** No CSS transitions/animate classes. All motion via useCurrentFrame(). Easing matches spec.
- **Remotion rules:** Uses `<Img>` not `<img>`. Uses `<Video>`/`<Audio>` from @remotion/media. `staticFile()` for assets.
- **Structure:** Composition registered in Root.tsx. Duration/fps matches style def. Correct resolution.

### Tier 2: Frame Sampling (default on, skippable)

Reuses preview frames from `.remotion-maker/preview/` — no extra render cost. ~500 tokens/frame. ~10-25 seconds.

Checks:
- **Layout:** Text not cut off, elements not overlapping, proper padding/margins.
- **Visual consistency:** Colors render correctly, fonts render properly, images sized correctly.
- **Composition:** Title cards centered, content scenes balanced, no empty/broken frames.
- **Render health:** No black frames, no error states, no missing assets.

### Tier 3: Playwright Playback (on request via --deep)

Launches Remotion Studio in browser via Playwright MCP. ~2000+ tokens. ~30-60 seconds.

Steps:
1. `npx remotion studio` → starts dev server.
2. Playwright navigates to composition preview.
3. Playwright plays composition from start.
4. Screenshots at transition points + every N frames.
5. Agent reviews screenshots for motion/timing quality.

Checks:
- **Animation timing:** Transitions feel right, elements don't jump, stagger timing smooth.
- **Audio sync:** If audio present, visual elements align with audio cues.

### Verification Report

Written to `.remotion-maker/verify/report.md`:

```yaml
---
video: building-cli-rust
style: tech-minimal
tiers_run: [1, 2]
pass: true
warnings: 1
---
```

With per-tier pass/fail details and actionable recommendations.

### Invocation Modes

- `/remotion-maker:verify` → Tier 1 + Tier 2 (default)
- `/remotion-maker:verify --deep` → all 3 tiers
- `/remotion-maker:verify --static-only` → Tier 1 only (fastest)

## Skills Integration

### Fork Strategy

- **Copy** all 35 rule files + 3 asset files from `remotion-dev/skills` verbatim into `skills/remotion/rules/`.
- **Extend** SKILL.md index to reference both `rules/` and `extensions/`.
- **Separate** custom rules into `extensions/` — never edit originals.
- **Sync** upstream updates by diffing `remotion-dev/skills` against `rules/`, applying changes. Extensions untouched.

### Custom Extensions

**style-system.md** — How to read `.remotion-maker/styles/*.md` frontmatter. Parse YAML → create `styles.ts` constants file. Map palette keys to Remotion interpolate colors. Map font entries to `loadFont()` calls. Map animation specs to `interpolate()` + `spring()` configs.

**scene-patterns.md** — Reusable scene type templates: title-card (centered text + subtitle fade), content (text + media split), code (code block + typewriter), chart (animated data viz), image-showcase (full-bleed image + caption), outro (CTA + subscribe). Each with Sequence/timing patterns.

**format-layouts.md** — Layout rules per format. 16:9: safe zones, title positioning, content grid, sidebar patterns. 9:16: vertical stacking, larger text sizes, centered alignment, thumb-safe tap zones. How to adapt a scene from one format to the other.

**verification-rules.md** — Codified checks for the verifier agent. Tier 1 grep patterns (hex color regex, font import pattern, transition type extraction). Tier 2 frame inspection checklist. Tier 3 Playwright action sequences. Pass/fail criteria and report format.

### Token Efficiency

SKILL.md index: ~300 tokens (one-line descriptions + load instructions). Each rule file: ~200-800 tokens. Agents only load rules relevant to current scene types.

Typical video generation budget:

| File | Tokens | When |
|------|--------|------|
| SKILL.md | ~300 | always |
| extensions/style-system.md | ~400 | always |
| extensions/scene-patterns.md | ~500 | always |
| rules/timing.md | ~600 | always |
| rules/text-animations.md | ~400 | code scenes |
| rules/charts.md | ~500 | chart scenes |
| rules/sequencing.md | ~400 | multi-scene |
| rules/transitions.md | ~500 | scene changes |
| **Total** | **~3,600** | vs ~12,000 loading all |

### Agent → Skill Mapping

| Agent | Skills |
|-------|--------|
| style-definer | extensions/style-system.md |
| video-generator | SKILL.md + extensions/scene-patterns.md + extensions/format-layouts.md + extensions/style-system.md |
| video-verifier | extensions/verification-rules.md + extensions/style-system.md |
| media-sourcer | None (WebSearch only) |

## Shell Library Conventions

- Prefix: `rm_` (remotion-maker)
- `lib/common.sh` — constants (`RM_STYLES_DIR`, `RM_PREVIEW_DIR`, `RM_VERIFY_DIR`), directory setup
- `set -euo pipefail`
- Sourced via: `source "$(find ~/.claude/plugins -path '*/remotion-maker/lib/*.sh' -print -quit 2>/dev/null || echo '/dev/null')"`

## Marketplace Integration

Published as `remotion-maker` under the `21-BreakinCode` GitHub org. Entry in `workflow-plugins-marketplace/.claude-plugin/marketplace.json`:

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
