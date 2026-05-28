---
name: style-system
description: "How to parse .remotion-maker/styles/*.md definitions into Remotion TypeScript code"
metadata:
  tags: style, palette, fonts, animations, config
---

## Reading a Style Definition

Style definition files live at `.remotion-maker/styles/*.md`. Each file has two parts:

1. **YAML frontmatter** — structured values consumed by code generation. This is the source of truth for all typed constants in `styles.ts`.
2. **Prose body** — qualitative guidelines (mood, motion vocabulary, visual personality) that inform decisions the code cannot encode: contrast choices, layout emphasis, when to use emphasis animations vs. entrance animations, etc.

Example style file structure:

```yaml
---
palette:
  background: "#0A0A0F"
  primary: "#6366F1"
  accent: "#F59E0B"
  text: "#F8FAFC"
  textSecondary: "#94A3B8"
fonts:
  heading:
    family: "Inter"
    weight: 700
  body:
    family: "Inter"
    weight: 400
  code:
    family: "JetBrains Mono"
    weight: 400
transitions:
  types: ["slide", "fade"]
  durationFrames: 18
  easing: "easeInOut"
animations:
  entrance:
    type: "fadeUp"
    durationFrames: 24
    easing: [0.16, 1, 0.3, 1]
  emphasis:
    spring:
      damping: 14
      stiffness: 180
      mass: 1
  text:
    type: "typewriter"
layout:
  padding: 80
  titlePosition: "center"
  contentAlignment: "left"
---

A dark, developer-focused aesthetic. Motion should feel intentional and snappy — 
avoid slow fades. Heading animations should establish presence immediately. 
Use accent color sparingly: only for CTAs and key data points, never decoratively.
The prose guidelines apply when choosing between animation variants or deciding 
whether to add micro-interactions beyond the required entrance.
```

Always read both parts: frontmatter drives the generated code, prose drives the agent's qualitative decisions.

---

## Generating styles.ts

Given the frontmatter above, generate a `src/styles.ts` file that exports typed `as const` objects. Never use `any` — type narrowness enables IDE autocomplete and catches style drift at compile time.

```typescript
// src/styles.ts
// AUTO-GENERATED from .remotion-maker/styles/<name>.md
// Re-run generation if the style definition changes.

export const PALETTE = {
  background: "#0A0A0F",
  primary: "#6366F1",
  accent: "#F59E0B",
  text: "#F8FAFC",
  textSecondary: "#94A3B8",
} as const;

export const FONTS = {
  heading: {
    family: "Inter",
    weight: 700,
  },
  body: {
    family: "Inter",
    weight: 400,
  },
  code: {
    family: "JetBrains Mono",
    weight: 400,
  },
} as const;

export const TRANSITIONS = {
  types: ["slide", "fade"] as const,
  durationFrames: 18,
  easing: "easeInOut",
} as const;

export const ANIMATIONS = {
  entrance: {
    type: "fadeUp",
    durationFrames: 24,
    easing: [0.16, 1, 0.3, 1] as [number, number, number, number],
  },
  emphasis: {
    config: {
      damping: 14,
      stiffness: 180,
      mass: 1,
    },
  },
  text: {
    type: "typewriter",
  },
} as const;

export const LAYOUT = {
  padding: 80,
  titlePosition: "center" as const,
  contentAlignment: "left" as const,
} as const;
```

Place this file at `src/styles.ts` relative to the Remotion project root. Every scene component imports from this single file — there is never a second source of truth for style values.

---

## Mapping to Remotion APIs

### Palette → component colors

Use `PALETTE` constants for every color value. Never hardcode a hex string in a component.

```tsx
// src/components/TitleCard.tsx
import { AbsoluteFill } from "remotion";
import { PALETTE, FONTS, LAYOUT } from "../styles";

export const TitleCard: React.FC<{ title: string }> = ({ title }) => {
  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.background,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        padding: LAYOUT.padding,
      }}
    >
      <h1
        style={{
          color: PALETTE.text,
          fontFamily: FONTS.heading.family,
          fontWeight: FONTS.heading.weight,
          fontSize: 72,
          margin: 0,
        }}
      >
        {title}
      </h1>
    </AbsoluteFill>
  );
};
```

### Fonts → loadFont

Map each font family to its `@remotion/google-fonts` package. Call `loadFont` at module level (outside any component) so fonts are ready before rendering. Use aliased imports to avoid name collisions when heading and body share the same family but differ in weight.

```typescript
// src/load-fonts.ts
import {
  loadFont as loadInter,
  fontFamily as interFamily,
} from "@remotion/google-fonts/Inter";
import {
  loadFont as loadJetBrainsMono,
  fontFamily as jetBrainsMonoFamily,
} from "@remotion/google-fonts/JetBrainsMono";
import { FONTS } from "./styles";

// Call at module level — side-effectful, registers fonts for the renderer
loadInter({ weights: [String(FONTS.heading.weight), String(FONTS.body.weight)] });
loadJetBrainsMono({ weights: [String(FONTS.code.weight)] });

// Re-export resolved family names (may differ slightly from FONTS.*.family)
export { interFamily, jetBrainsMonoFamily };
```

Import `load-fonts.ts` in `Root.tsx` so fonts are loaded before any composition renders:

```typescript
// src/Root.tsx
import "./load-fonts";
import { Composition } from "remotion";
// ...
```

### Animations → interpolate/spring

**Entrance animations** use `interpolate` with `Easing.bezier` from the style definition:

```tsx
import { useCurrentFrame, interpolate, Easing } from "remotion";
import { ANIMATIONS } from "../styles";

const frame = useCurrentFrame();

const opacity = interpolate(
  frame,
  [0, ANIMATIONS.entrance.durationFrames],
  [0, 1],
  { extrapolateRight: "clamp" }
);

const translateY = interpolate(
  frame,
  [0, ANIMATIONS.entrance.durationFrames],
  [40, 0],
  {
    extrapolateRight: "clamp",
    easing: Easing.bezier(...ANIMATIONS.entrance.easing),
  }
);
```

**Emphasis animations** use `spring` with `ANIMATIONS.emphasis.config`:

```tsx
import { useCurrentFrame, useVideoConfig, spring } from "remotion";
import { ANIMATIONS } from "../styles";

const frame = useCurrentFrame();
const { fps } = useVideoConfig();

const scale = spring({
  frame,
  fps,
  config: ANIMATIONS.emphasis.config,
  from: 0.8,
  to: 1,
});
```

### Transitions → TransitionSeries

Map `TRANSITIONS.types` string values to their `@remotion/transitions` presenter imports. Use `TRANSITIONS.durationFrames` in `linearTiming`.

```tsx
import {
  TransitionSeries,
  linearTiming,
} from "@remotion/transitions";
import { slide } from "@remotion/transitions/slide";
import { fade } from "@remotion/transitions/fade";
import { TRANSITIONS } from "../styles";

// Map string → presenter function
const transitionMap = {
  slide: () => slide(),
  fade: () => fade(),
} as const;

// Use in composition
<TransitionSeries>
  <TransitionSeries.Sequence durationInFrames={90}>
    <TitleCard title="Hello" />
  </TransitionSeries.Sequence>
  <TransitionSeries.Transition
    presentation={transitionMap[TRANSITIONS.types[0]]()}
    timing={linearTiming({ durationInFrames: TRANSITIONS.durationFrames })}
  />
  <TransitionSeries.Sequence durationInFrames={120}>
    <ContentScene heading="Main Point" bullets={[]} />
  </TransitionSeries.Sequence>
</TransitionSeries>
```

---

## Important Rules

1. **Never hardcode colors.** Every color value in every component must come from `PALETTE`. If a new color is needed, add it to the style definition first, regenerate `styles.ts`, then use the constant.

2. **Never use CSS animations.** Do not use `animation:`, `transition:`, `@keyframes`, or `animate-*` Tailwind classes. All motion must go through `interpolate`, `spring`, or `TransitionSeries` so Remotion controls the timeline.

3. **One styles.ts per composition project.** A single project renders one style. Do not conditionally switch palettes at runtime — that belongs to a different project with a different style definition.

4. **Respect the prose guidelines.** After generating code from frontmatter, re-read the prose body of the style definition and verify that motion choices (speed, entrance direction, use of emphasis) align with the described aesthetic. The prose overrides your defaults when they conflict.
