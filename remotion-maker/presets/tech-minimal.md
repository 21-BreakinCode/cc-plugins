---
name: tech-minimal
description: Clean, dark developer/tech content series
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

Transitions should feel snappy, not floaty. Keep scene transitions under 15 frames. Text appears via typewriter only — no per-character opacity fades.

Code blocks use JetBrains Mono with a subtle background (#0F172A) and 16px horizontal padding. Syntax highlighting follows the palette — keywords in primary, strings in accent.

## Component Patterns

Title cards: centered heading, subtitle fades in 10 frames after heading completes. No background animation.

Content scenes: left-aligned body text, images/code on right. Stagger element entrances by 8 frames each.

Outro: centered channel name, primary-colored CTA button with spring entrance.
