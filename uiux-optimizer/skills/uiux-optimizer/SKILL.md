---
name: uiux-optimizer
description: UI/UX design advisor for improving visual design, layout, and component patterns AND for project-start design discovery. Use when the user seeks to improve UI/UX ("improve the design", "optimize this UI", "how should this look", "make this look better", "this looks off", "feels clunky", "not polished", "spacing is weird", "review this component", "what would you change about this UI", "design feedback", "needs visual work", "layout feels wrong"), wants project-start direction ("I want to build a [task management / fintech / dev tool / AI chat / e-commerce / etc.] app", "what should this kind of app look like?", "show me design references for [domain]", "I need inspiration for a [product type]"), or wants to match a known brand's design language ("make it look like Linear", "I want a Stripe-style payment page", "match Notion's typography"). Pulls live references from the awesome-design-md catalogue (getdesign.md) and styles.refero.design.
---

# UI/UX Optimizer

Analyze UI code against real-world design patterns and provide concrete improvement suggestions backed by live references.

## When This Skill Activates

- Direct requests: "improve the design", "optimize this UI", "how should this look", "make this look better", "design feedback"
- Design dissatisfaction: "this looks off", "feels clunky", "not polished", "spacing is weird", "needs visual work"
- Review mode: "review this component", "what would you change about this UI"
- **Project-start discovery:** "I want to build a [task management / fintech dashboard / dev tool / AI chat / e-commerce / etc.] app", "what should this kind of app look like?", "show me design references for [domain]", "I need inspiration for a [product type]"
- **Brand-match intent:** "make it look like Linear", "I want a Stripe-style payment page", "match Notion's typography"

Do NOT auto-trigger on all UI code. Only when the user's language signals design intent.

## Decision Framework

When triggered, follow this sequence:

1. **Identify the domain** — Read the code/component. Is this primarily:
   - **Visual design** — color, typography, spacing, hierarchy, contrast
   - **Layout/composition** — grid systems, whitespace, content density, responsive patterns
   - **Component patterns** — how the component should look/behave compared to established patterns

2. **Identify the product category** (when intent is high-level or project-start) — Is the user building or evaluating a:
   - Task/project management tool, AI/LLM platform, dev tool/IDE, fintech/crypto, e-commerce, productivity SaaS, design/creative tool, media/editorial, automotive, etc.
   - This category drives which catalogued brands to surface as references.

3. **Identify the gap** — What's missing or off?
   - Missing hierarchy (everything looks the same weight)
   - Poor density (too cramped or too sparse)
   - Inconsistent spacing (no rhythm)
   - Non-standard component behavior
   - Weak visual grouping

4. **Dispatch the design-advisor agent** — Use the Agent tool to spawn `design-advisor` with:
   - The identified domain(s) and product category (if any)
   - The relevant file path(s) and line ranges, or the user's project description
   - The operating mode: `audit` (reviewing existing), `build` (creating/modifying), or `explore` (seeking inspiration / project-start discovery / brand-match)
   - Any specific user concern (e.g., "spacing feels off" → focus on spacing) or named brand (e.g., "make it look like Linear")

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
Abstract principles without examples are weak. Always back up with "here's how X brand handles this" via live references. Two complementary sources:
- **refero.design** — broad pattern lookup ("how do successful SaaS dashboards handle data tables?"). Extract transferable principles.
- **awesome-design-md catalogue** (`getdesign.md/{brand}/design-md`) — full design systems for 70+ named brands (Linear, Stripe, Notion, Vercel, Apple, Tesla, etc.). Use when the user names a brand, asks for inspiration for a product category, or is starting a new project and wants direction. Each file contains color tokens, type scale, components, spacing, and Do's/Don'ts ready for AI consumption.

## Constraints

- Max 3-5 suggestions per invocation, ranked by impact
- Don't redesign what isn't asked about (surgical changes)
- Don't suggest framework switches
- Don't optimize aesthetics at cost of accessibility
- Match the user's existing framework in code examples (Tailwind, plain CSS, styled-components, etc.)
- Secondary domains (motion, interaction design, accessibility) — note briefly when relevant, don't lead with them
