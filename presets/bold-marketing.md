---
name: bold-marketing
description: High-energy, high-contrast marketing content
format: youtube-16-9
fps: 30

palette:
  background: "#FFFFFF"
  primary: "#FF6B35"
  accent: "#FFD700"
  text: "#1A1A2E"
  text_secondary: "#4A4A6A"

fonts:
  heading: { family: Poppins, weight: 800 }
  body: { family: Poppins, weight: 400 }

transitions:
  type: [wipe, slide]
  duration_frames: 10
  easing: easeOut

animations:
  entrance: { type: scale-up, duration: 12, easing: "bezier(0.34, 1.56, 0.64, 1)" }
  emphasis: { type: spring, damping: 8, mass: 0.3 }
  text: typewriter

layout:
  padding: 80
  title_position: center
  content_alignment: center
---

## Qualitative Guidelines

Everything should feel energetic and punchy. Transitions are fast (under 10 frames). Overshoot easing on entrances — elements should bounce slightly into place.

Use the accent color (gold) sparingly for highlights and emphasis. Primary orange is for CTAs and key callouts.

White background with dark text — this is a bright, bold style. No dark mode.

## Component Patterns

Title cards: large heading (80px+) centered with slight scale-up entrance. Use accent underline below title.

Content scenes: centered layout, generous padding. Bold headings, short punchy bullet points.

Outro: large CTA button in primary color, pulsing spring animation.
