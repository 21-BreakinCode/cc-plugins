# remotion-maker

A Claude Code plugin for generating Remotion (React) videos with consistent style, automated media sourcing, staged preview, and multi-tier verification.

## Commands

| Command | Purpose |
|---------|---------|
| `/remotion-maker:create` | Full pipeline: style → generate → preview → verify → render |
| `/remotion-maker:define-style` | Create or manage style definitions |
| `/remotion-maker:find-media` | Search free resources for media assets |
| `/remotion-maker:verify` | Verify video against style definition |

## Quick Start

1. Run `/remotion-maker:create`
2. Pick or create a style (from presets or from scratch)
3. Provide your content (script, bullet points, blog post)
4. Review preview frames
5. Approve final render → MP4

## Style Presets

- **tech-minimal** — dark, clean, developer-focused
- **bold-marketing** — high contrast, energetic
- **storyteller-warm** — warm tones, narrative feel

## Project Data

All generated state lives in `.remotion-maker/` inside your Remotion project:

```
.remotion-maker/
├── styles/        # style definitions
├── media/sourced/ # downloaded free resources
├── preview/       # rendered preview frames
└── verify/        # verification reports
```
