---
name: uiux-optimizer
description: UI/UX design advisor for improving visual design, layout, and component patterns. Also provides project-start design direction. Use when the user wants to improve or critique an existing UI ("improve the design", "make this look better", "this feels clunky", "review this component"). When the user wants direction for a new app, also use this skill ("what does a fintech app look like?", "design references for [domain]"). Also use to match a named brand ("make it look like Linear", "a Stripe-style payment page", "match Notion's typography").
---

# UI/UX Optimizer

Analyze UI code against real-world design patterns and provide concrete improvement suggestions backed by live references.

## When This Skill Activates

When the user's language signals design intent, trigger this skill. Do not trigger on the mere presence of UI code. The three intents live in the description (improve/critique an existing UI, project-start direction for a new app, match a named brand). The Decision Framework below routes whichever fired.

## Decision Framework

When triggered, follow this sequence:

1. **Identify the domain**: Read the code/component. Is this primarily:
   - **Visual design**: color, typography, spacing, hierarchy, contrast
   - **Layout/composition**: grid systems, whitespace, content density, responsive patterns
   - **Component patterns**: how the component looks/behaves compared to established patterns

2. **Identify the product category** (when intent is high-level or project-start): Is the user building or evaluating a:
   - Task/project management tool, AI/LLM platform, dev tool/IDE, fintech/crypto, e-commerce, productivity SaaS, design/creative tool, media/editorial, automotive, and others.
   - This category drives which catalogued brands to surface as references.

3. **Identify the gap**: What is missing or off?
   - Missing hierarchy (everything looks the same weight)
   - Poor density (too cramped or too sparse)
   - Inconsistent spacing (no rhythm)
   - Non-standard component behavior
   - Weak visual grouping

4. **Conduct the layers**: You (the main loop) are the conductor. Sequence the
   available layers around the `design-advisor` agent:
   - **Before** dispatching design-advisor, invoke `design-taste-frontend` (when
     installed) via the Skill tool for brief-inference and anti-slop guardrails.
   - **Dispatch the design-advisor agent**: Use the Agent tool to spawn
     `design-advisor` with:
     - The identified domain(s) and product category (if any)
     - The relevant file path(s) and line ranges, or the user's project description
     - The operating mode: `audit` (reviewing existing), `build` (creating/modifying), `explore` (seeking inspiration / project-start discovery / brand-match), or `ship` (the gated direction → static → motion pipeline)
     - Any specific user concern (for example, "spacing feels off" → focus on spacing) or named brand (for example, "make it look like Linear")
   - **After** design-advisor in `build`/`ship`, invoke `motion-design`
     (when installed) via the Skill tool to layer motion onto the solid static UI.

   In `explore` and the pipeline's direction step, present taste's system pick and
   design-advisor's brand directions **in parallel**. The user reconciles.

   **Availability check & install hint**: Before conducting, check your
   available-skills list for `design-taste-frontend` and `motion-design`. For any
   that is missing, add one concise line after your output. Name the gap and its
   install command (for example, "Motion is limited without motion-design:
   `npx skills add LottieFiles/motion-design-skill --skill motion-design`"). One line
   per missing skill, at most once per response. Inform, do not nag.

   See `references/orchestration.md` for the per-mode wiring, the ship pipeline
   steps and gates, and graceful-degradation rules.

## Design Philosophy (Refero Mindset)

These principles guide ALL suggestions:

### 1. Pattern-first, not opinion-first
Never "I think this needs to be blue." Always "successful SaaS dashboards use muted blues for data-heavy surfaces. Here is a reference." Every suggestion must trace to a pattern that works in production.

### 2. Design is a system, not individual decisions
Color relates to typography relates to spacing relates to density. Evaluate the system as a whole. When asked about one element, briefly note systemic issues upstream.

### 3. Constraint-driven improvement
Work within the existing design language. If the palette still contains unused tokens, do not introduce new colors. Improve by subtraction first (remove noise, reduce variation) before adding new elements.

### 4. Hierarchy is everything
Most UI problems are hierarchy problems: what does the eye see first, second, third? Size, weight, color, spacing, and position all contribute. Suggest the minimum intervention that fixes the hierarchy.

### 5. Reference real implementations
Abstract principles without examples are weak. Always back up with "here is how X brand handles this" via live references. Two complementary sources:
- **refero.design**: broad pattern lookup ("how do successful SaaS dashboards handle data tables?"). Extract transferable principles.
- **awesome-design-md catalogue** (`getdesign.md/{brand}/design-md`): full design systems for 70+ named brands (Linear, Stripe, Notion, Vercel, Apple, Tesla, and others). Use when the user names a brand, asks for inspiration for a product category, or starts a new project and wants direction. Each file contains color tokens, type scale, components, spacing, and Do's/Don'ts ready for AI consumption.

## Constraints

- Max 3-5 suggestions per invocation, ranked by impact
- Do not redesign what is not asked about (surgical changes)
- Do not suggest framework switches
- Do not optimize aesthetics at cost of accessibility
- Match the user's existing framework in code examples (Tailwind, plain CSS, styled-components, and others)
- Motion is a dedicated, gated layer owned by `motion-design` in `build`/`ship`. Add it after the static UI is solid. Accessibility remains a cross-cutting concern that constrains every layer.

## External Skills (Optional)

When installed, this skill orchestrates two external skills and degrades gracefully without them. Installed skill names (what the conductor checks for) are in parentheses:

- Anti-slop / taste discipline (`design-taste-frontend`): `npx skills add Leonxlnx/taste-skill --skill design-taste-frontend`
- Motion choreography (`motion-design`): `npx skills add LottieFiles/motion-design-skill --skill motion-design`

Without them, uiux-optimizer falls back to its own Refero-mindset discipline and brief motion notes. See `references/orchestration.md`.
