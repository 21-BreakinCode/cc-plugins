---
name: storyteller-warm
description: Warm, narrative tone for storytelling and educational content
format: youtube-16-9
fps: 30

palette:
  background: "#FFF8F0"
  primary: "#8B5E3C"
  accent: "#D4A574"
  text: "#2C1810"
  text_secondary: "#6B4F3A"

fonts:
  heading: { family: Merriweather, weight: 700 }
  body: { family: Lato, weight: 400 }

transitions:
  type: [fade]
  duration_frames: 20
  easing: easeInOut

animations:
  entrance: { type: fade-in, duration: 25, easing: "bezier(0.4, 0, 0.2, 1)" }
  emphasis: { type: spring, damping: 20, mass: 1.0 }
  text: typewriter

layout:
  padding: 80
  title_position: center
  content_alignment: left
---

## Qualitative Guidelines

Everything should feel gentle and intentional. Slow fades (20 frames) between scenes. No sudden movements — elements drift into place over 25 frames.

This style is warm and inviting. Think coffee shop, bookshelf, old paper. The cream background and brown palette evoke comfort and trust.

## Component Patterns

Title cards: serif heading (Merriweather) centered, gentle fade-in. Subtitle in lighter brown (accent), appears 15 frames after title.

Content scenes: generous whitespace. Left-aligned text with wide line height (1.8). Images softened with subtle border-radius (12px).

Outro: simple "Thanks for watching" in heading font, no flashy CTA. Fade to cream background.
