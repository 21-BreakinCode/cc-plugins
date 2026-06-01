---
name: uiux-optimizer
description: UI/UX design advisor for improving visual design, layout, and component patterns. Use when the user seeks to improve UI/UX, says things like "improve the design", "optimize this UI", "how should this look", "make this look better", "this looks off", "feels clunky", "not polished", "spacing is weird", "review this component", "what would you change about this UI", or is reading/reviewing UI code and expressing design dissatisfaction. Also triggers on "design feedback", "needs visual work", "layout feels wrong".
---

# UI/UX Optimizer

Analyze UI code against real-world design patterns and provide concrete improvement suggestions backed by live references.

## When This Skill Activates

- Direct requests: "improve the design", "optimize this UI", "how should this look", "make this look better", "design feedback"
- Design dissatisfaction: "this looks off", "feels clunky", "not polished", "spacing is weird", "needs visual work"
- Review mode: "review this component", "what would you change about this UI"

Do NOT auto-trigger on all UI code. Only when the user's language signals design intent.

## Decision Framework

When triggered, follow this sequence:

1. **Identify the domain** — Read the code/component. Is this primarily:
   - **Visual design** — color, typography, spacing, hierarchy, contrast
   - **Layout/composition** — grid systems, whitespace, content density, responsive patterns
   - **Component patterns** — how the component should look/behave compared to established patterns

2. **Identify the gap** — What's missing or off?
   - Missing hierarchy (everything looks the same weight)
   - Poor density (too cramped or too sparse)
   - Inconsistent spacing (no rhythm)
   - Non-standard component behavior
   - Weak visual grouping

3. **Dispatch the design-advisor agent** — Use the Agent tool to spawn `design-advisor` with:
   - The identified domain(s)
   - The relevant file path(s) and line ranges
   - The operating mode: `audit` (reviewing existing), `build` (creating/modifying), or `explore` (seeking inspiration)
   - Any specific user concern (e.g., "spacing feels off" → focus on spacing)

## Design Philosophy (Refero Mindset)

These principles guide ALL suggestions:

### 1. Pattern-first, not opinion-first
Never "I think this should be blue." Always "successful SaaS dashboards use muted blues for data-heavy surfaces — here's a reference." Every suggestion must be traceable to a pattern that works in production.

### 2. Design is a system, not individual decisions
Color relates to typography relates to spacing relates to density. Evaluate holistically. If asked about one element, briefly note systemic issues upstream.

### 3. Constraint-driven improvement
Work within the existing design language. Don't introduce new colors if the palette has underused tokens. Improve by subtraction first (remove noise, reduce variation) before adding new elements.

### 4. Hierarchy is everything
Most UI problems are hierarchy problems: what should the eye see first, second, third? Size, weight, color, spacing, and position all contribute. Suggest the minimum intervention that fixes the hierarchy.

### 5. Reference real implementations
Abstract principles without examples are weak. Always back up with "here's how X brand handles this" via live references from refero.design. Extract transferable principles, not specific aesthetics.

## Constraints

- Max 3-5 suggestions per invocation, ranked by impact
- Don't redesign what isn't asked about (surgical changes)
- Don't suggest framework switches
- Don't optimize aesthetics at cost of accessibility
- Match the user's existing framework in code examples (Tailwind, plain CSS, styled-components, etc.)
- Secondary domains (motion, interaction design, accessibility) — note briefly when relevant, don't lead with them
