---
name: scene-patterns
description: "Reusable Remotion scene component templates for 6 scene types: title-card, content, code, chart, image-showcase, outro"
metadata:
  tags: scenes, components, templates, composition
---

## Scene Component Templates

Each scene component below is a complete, copy-paste-ready TSX implementation. All import from `../styles` and use `PALETTE`, `FONTS`, `ANIMATIONS`, and `LAYOUT` constants. Adjust file paths to match your project structure.

---

### 1. title-card

```tsx
// src/scenes/TitleCard.tsx
import React from "react";
import { AbsoluteFill, useCurrentFrame, interpolate, Easing } from "remotion";
import { PALETTE, FONTS, ANIMATIONS, LAYOUT } from "../styles";

type TitleCardProps = {
  title: string;
  subtitle?: string;
};

export const TitleCard: React.FC<TitleCardProps> = ({ title, subtitle }) => {
  const frame = useCurrentFrame();

  const titleOpacity = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [0, 1],
    { extrapolateRight: "clamp" }
  );

  const titleTranslateY = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [40, 0],
    {
      extrapolateRight: "clamp",
      easing: Easing.bezier(...ANIMATIONS.entrance.easing),
    }
  );

  const subtitleDelay = ANIMATIONS.entrance.durationFrames + 10;
  const subtitleOpacity = interpolate(
    frame,
    [subtitleDelay, subtitleDelay + ANIMATIONS.entrance.durationFrames],
    [0, 1],
    { extrapolateRight: "clamp", extrapolateLeft: "clamp" }
  );

  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.background,
        display: "flex",
        flexDirection: "column",
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
          textAlign: "center",
          maxWidth: "80%",
          opacity: titleOpacity,
          transform: `translateY(${titleTranslateY}px)`,
        }}
      >
        {title}
      </h1>

      {subtitle && (
        <p
          style={{
            color: PALETTE.textSecondary,
            fontFamily: FONTS.body.family,
            fontWeight: FONTS.body.weight,
            fontSize: 32,
            marginTop: 24,
            textAlign: "center",
            maxWidth: "70%",
            opacity: subtitleOpacity,
          }}
        >
          {subtitle}
        </p>
      )}
    </AbsoluteFill>
  );
};
```

---

### 2. content

```tsx
// src/scenes/ContentScene.tsx
import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  interpolate,
  Easing,
  Img,
  staticFile,
} from "remotion";
import { PALETTE, FONTS, ANIMATIONS, LAYOUT } from "../styles";

type ContentSceneProps = {
  heading: string;
  bullets: string[];
  mediaUrl?: string;
  mediaPosition?: "left" | "right";
};

export const ContentScene: React.FC<ContentSceneProps> = ({
  heading,
  bullets,
  mediaUrl,
  mediaPosition = "right",
}) => {
  const frame = useCurrentFrame();

  const headingOpacity = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [0, 1],
    { extrapolateRight: "clamp" }
  );

  const headingTranslateY = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [30, 0],
    {
      extrapolateRight: "clamp",
      easing: Easing.bezier(...ANIMATIONS.entrance.easing),
    }
  );

  const BULLET_STAGGER = 8;

  const textColumn = (
    <div
      style={{
        flex: mediaUrl ? "0 0 55%" : "1",
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        gap: 20,
      }}
    >
      <h2
        style={{
          color: PALETTE.text,
          fontFamily: FONTS.heading.family,
          fontWeight: FONTS.heading.weight,
          fontSize: 48,
          margin: 0,
          opacity: headingOpacity,
          transform: `translateY(${headingTranslateY}px)`,
        }}
      >
        {heading}
      </h2>

      <ul style={{ listStyle: "none", margin: 0, padding: 0, display: "flex", flexDirection: "column", gap: 16 }}>
        {bullets.map((bullet, i) => {
          const bulletStart = ANIMATIONS.entrance.durationFrames + i * BULLET_STAGGER;
          const bulletOpacity = interpolate(
            frame,
            [bulletStart, bulletStart + ANIMATIONS.entrance.durationFrames],
            [0, 1],
            { extrapolateRight: "clamp", extrapolateLeft: "clamp" }
          );
          const bulletTranslateX = interpolate(
            frame,
            [bulletStart, bulletStart + ANIMATIONS.entrance.durationFrames],
            [-24, 0],
            {
              extrapolateRight: "clamp",
              extrapolateLeft: "clamp",
              easing: Easing.bezier(...ANIMATIONS.entrance.easing),
            }
          );

          return (
            <li
              key={i}
              style={{
                color: PALETTE.text,
                fontFamily: FONTS.body.family,
                fontWeight: FONTS.body.weight,
                fontSize: 28,
                display: "flex",
                alignItems: "flex-start",
                gap: 12,
                opacity: bulletOpacity,
                transform: `translateX(${bulletTranslateX}px)`,
              }}
            >
              <span style={{ color: PALETTE.accent, marginTop: 4, flexShrink: 0 }}>▸</span>
              <span>{bullet}</span>
            </li>
          );
        })}
      </ul>
    </div>
  );

  const mediaColumn = mediaUrl ? (
    <div
      style={{
        flex: "0 0 45%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
      }}
    >
      <Img
        src={staticFile(mediaUrl)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "contain",
          borderRadius: 12,
        }}
      />
    </div>
  ) : null;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.background,
        display: "flex",
        flexDirection: "row",
        alignItems: "center",
        padding: LAYOUT.padding,
        gap: 40,
      }}
    >
      {mediaPosition === "left" && mediaColumn}
      {textColumn}
      {mediaPosition === "right" && mediaColumn}
    </AbsoluteFill>
  );
};
```

---

### 3. code

```tsx
// src/scenes/CodeScene.tsx
import React from "react";
import { AbsoluteFill, useCurrentFrame, interpolate, Easing } from "remotion";
import { PALETTE, FONTS, ANIMATIONS, LAYOUT } from "../styles";

type CodeSceneProps = {
  title: string;
  code: string;
  charsPerFrame?: number;
};

const CODE_BG = "#0F172A";
const TYPEWRITER_START = ANIMATIONS.entrance.durationFrames;

export const CodeScene: React.FC<CodeSceneProps> = ({
  title,
  code,
  charsPerFrame = 2,
}) => {
  const frame = useCurrentFrame();

  const titleOpacity = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [0, 1],
    { extrapolateRight: "clamp" }
  );

  const titleTranslateY = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [20, 0],
    {
      extrapolateRight: "clamp",
      easing: Easing.bezier(...ANIMATIONS.entrance.easing),
    }
  );

  const charsVisible = Math.max(
    0,
    Math.floor((frame - TYPEWRITER_START) * charsPerFrame)
  );
  const displayedCode = code.slice(0, charsVisible);
  const isTyping = charsVisible < code.length;
  const showCursor = isTyping && frame % 30 < 15;

  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.background,
        display: "flex",
        flexDirection: "column",
        padding: LAYOUT.padding,
        gap: 32,
      }}
    >
      <h2
        style={{
          color: PALETTE.text,
          fontFamily: FONTS.heading.family,
          fontWeight: FONTS.heading.weight,
          fontSize: 48,
          margin: 0,
          opacity: titleOpacity,
          transform: `translateY(${titleTranslateY}px)`,
        }}
      >
        {title}
      </h2>

      <div
        style={{
          backgroundColor: CODE_BG,
          borderRadius: 12,
          padding: 40,
          flex: 1,
          overflow: "hidden",
          border: `1px solid ${PALETTE.primary}33`,
        }}
      >
        <pre
          style={{
            margin: 0,
            fontFamily: FONTS.code.family,
            fontWeight: FONTS.code.weight,
            fontSize: 20,
            lineHeight: 1.6,
            color: PALETTE.text,
            whiteSpace: "pre-wrap",
            wordBreak: "break-word",
          }}
        >
          {displayedCode}
          {showCursor && (
            <span
              style={{
                display: "inline-block",
                width: 2,
                height: "1em",
                backgroundColor: PALETTE.accent,
                marginLeft: 2,
                verticalAlign: "text-bottom",
              }}
            />
          )}
        </pre>
      </div>
    </AbsoluteFill>
  );
};
```

---

### 4. chart

```tsx
// src/scenes/ChartScene.tsx
import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
  Easing,
} from "remotion";
import { PALETTE, FONTS, ANIMATIONS, LAYOUT } from "../styles";

type ChartDataItem = {
  label: string;
  value: number;
};

type ChartSceneProps = {
  title: string;
  data: ChartDataItem[];
};

export const ChartScene: React.FC<ChartSceneProps> = ({ title, data }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const titleOpacity = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [0, 1],
    { extrapolateRight: "clamp" }
  );

  const maxValue = Math.max(...data.map((d) => d.value));
  const BAR_COLORS = [PALETTE.primary, PALETTE.accent];

  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.background,
        display: "flex",
        flexDirection: "column",
        padding: LAYOUT.padding,
        gap: 40,
      }}
    >
      <h2
        style={{
          color: PALETTE.text,
          fontFamily: FONTS.heading.family,
          fontWeight: FONTS.heading.weight,
          fontSize: 48,
          margin: 0,
          opacity: titleOpacity,
        }}
      >
        {title}
      </h2>

      <div
        style={{
          flex: 1,
          display: "flex",
          alignItems: "flex-end",
          gap: 24,
        }}
      >
        {data.map((item, i) => {
          const animProgress = spring({
            frame: frame - i * 5,
            fps,
            config: ANIMATIONS.emphasis.config,
            from: 0,
            to: 1,
          });

          const barHeight = (item.value / maxValue) * 100 * animProgress;
          const barColor = BAR_COLORS[i % BAR_COLORS.length];

          const labelOpacity = interpolate(
            frame,
            [i * 5, i * 5 + ANIMATIONS.entrance.durationFrames],
            [0, 1],
            {
              extrapolateRight: "clamp",
              extrapolateLeft: "clamp",
              easing: Easing.bezier(...ANIMATIONS.entrance.easing),
            }
          );

          return (
            <div
              key={i}
              style={{
                flex: 1,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                gap: 12,
                height: "100%",
                justifyContent: "flex-end",
              }}
            >
              <span
                style={{
                  color: PALETTE.text,
                  fontFamily: FONTS.body.family,
                  fontWeight: FONTS.heading.weight,
                  fontSize: 24,
                  opacity: labelOpacity,
                }}
              >
                {item.value}
              </span>
              <div
                style={{
                  width: "100%",
                  height: `${barHeight}%`,
                  backgroundColor: barColor,
                  borderRadius: "6px 6px 0 0",
                  minHeight: 4,
                }}
              />
              <span
                style={{
                  color: PALETTE.textSecondary,
                  fontFamily: FONTS.body.family,
                  fontWeight: FONTS.body.weight,
                  fontSize: 20,
                  textAlign: "center",
                  opacity: labelOpacity,
                }}
              >
                {item.label}
              </span>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
```

---

### 5. image-showcase

```tsx
// src/scenes/ImageShowcase.tsx
import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  Img,
  staticFile,
  interpolate,
  Easing,
} from "remotion";
import { PALETTE, FONTS, ANIMATIONS, LAYOUT } from "../styles";

type ImageShowcaseProps = {
  imageUrl: string;
  caption: string;
};

const KEN_BURNS_DURATION = 150;

export const ImageShowcase: React.FC<ImageShowcaseProps> = ({
  imageUrl,
  caption,
}) => {
  const frame = useCurrentFrame();

  // Ken Burns zoom: scale from 1.0 to 1.05 over KEN_BURNS_DURATION frames
  const scale = interpolate(frame, [0, KEN_BURNS_DURATION], [1, 1.05], {
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.quad),
  });

  const captionOpacity = interpolate(
    frame,
    [
      ANIMATIONS.entrance.durationFrames,
      ANIMATIONS.entrance.durationFrames + ANIMATIONS.entrance.durationFrames,
    ],
    [0, 1],
    {
      extrapolateRight: "clamp",
      extrapolateLeft: "clamp",
      easing: Easing.bezier(...ANIMATIONS.entrance.easing),
    }
  );

  const captionTranslateY = interpolate(
    frame,
    [
      ANIMATIONS.entrance.durationFrames,
      ANIMATIONS.entrance.durationFrames + ANIMATIONS.entrance.durationFrames,
    ],
    [20, 0],
    {
      extrapolateRight: "clamp",
      extrapolateLeft: "clamp",
      easing: Easing.bezier(...ANIMATIONS.entrance.easing),
    }
  );

  return (
    <AbsoluteFill style={{ overflow: "hidden" }}>
      {/* Full-bleed image with Ken Burns zoom */}
      <AbsoluteFill>
        <Img
          src={staticFile(imageUrl)}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            transform: `scale(${scale})`,
            transformOrigin: "center center",
          }}
        />
      </AbsoluteFill>

      {/* Gradient overlay at bottom for caption legibility */}
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(to top, rgba(0,0,0,0.85) 0%, rgba(0,0,0,0.4) 30%, rgba(0,0,0,0) 60%)",
        }}
      />

      {/* Caption */}
      <AbsoluteFill
        style={{
          display: "flex",
          alignItems: "flex-end",
          padding: LAYOUT.padding,
          paddingBottom: LAYOUT.padding + 20,
        }}
      >
        <p
          style={{
            color: "#FFFFFF",
            fontFamily: FONTS.body.family,
            fontWeight: FONTS.body.weight,
            fontSize: 28,
            margin: 0,
            maxWidth: "70%",
            lineHeight: 1.5,
            opacity: captionOpacity,
            transform: `translateY(${captionTranslateY}px)`,
          }}
        >
          {caption}
        </p>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
```

---

### 6. outro

```tsx
// src/scenes/Outro.tsx
import React from "react";
import {
  AbsoluteFill,
  useCurrentFrame,
  useVideoConfig,
  spring,
  interpolate,
  Easing,
} from "remotion";
import { PALETTE, FONTS, ANIMATIONS, LAYOUT } from "../styles";

type OutroProps = {
  channelName: string;
  callToAction?: string;
};

export const Outro: React.FC<OutroProps> = ({
  channelName,
  callToAction = "Subscribe for more",
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const nameOpacity = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [0, 1],
    { extrapolateRight: "clamp" }
  );

  const nameTranslateY = interpolate(
    frame,
    [0, ANIMATIONS.entrance.durationFrames],
    [40, 0],
    {
      extrapolateRight: "clamp",
      easing: Easing.bezier(...ANIMATIONS.entrance.easing),
    }
  );

  const ctaDelay = ANIMATIONS.entrance.durationFrames + 12;
  const ctaScale = spring({
    frame: frame - ctaDelay,
    fps,
    config: ANIMATIONS.emphasis.config,
    from: 0.7,
    to: 1,
  });

  const ctaOpacity = interpolate(frame, [ctaDelay, ctaDelay + 12], [0, 1], {
    extrapolateRight: "clamp",
    extrapolateLeft: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        backgroundColor: PALETTE.background,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        gap: 40,
        padding: LAYOUT.padding,
      }}
    >
      <h1
        style={{
          color: PALETTE.text,
          fontFamily: FONTS.heading.family,
          fontWeight: FONTS.heading.weight,
          fontSize: 64,
          margin: 0,
          textAlign: "center",
          opacity: nameOpacity,
          transform: `translateY(${nameTranslateY}px)`,
        }}
      >
        {channelName}
      </h1>

      <div
        style={{
          backgroundColor: PALETTE.primary,
          borderRadius: 48,
          paddingTop: 20,
          paddingBottom: 20,
          paddingLeft: 48,
          paddingRight: 48,
          opacity: ctaOpacity,
          transform: `scale(${ctaScale})`,
        }}
      >
        <span
          style={{
            color: "#FFFFFF",
            fontFamily: FONTS.heading.family,
            fontWeight: FONTS.heading.weight,
            fontSize: 28,
            letterSpacing: 0.5,
          }}
        >
          {callToAction}
        </span>
      </div>
    </AbsoluteFill>
  );
};
```

---

## Usage in Compositions

Wire scenes together with `TransitionSeries`. Each scene's `durationInFrames` should be calculated based on content (number of bullets × stagger delay + a comfortable reading buffer).

```tsx
// src/compositions/MyVideo.tsx
import React from "react";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { slide } from "@remotion/transitions/slide";
import { fade } from "@remotion/transitions/fade";
import { TRANSITIONS } from "../styles";
import { TitleCard } from "../scenes/TitleCard";
import { ContentScene } from "../scenes/ContentScene";
import { CodeScene } from "../scenes/CodeScene";
import { ChartScene } from "../scenes/ChartScene";
import { ImageShowcase } from "../scenes/ImageShowcase";
import { Outro } from "../scenes/Outro";

export const MyVideo: React.FC = () => {
  return (
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={90}>
        <TitleCard title="Video Title" subtitle="A compelling subtitle" />
      </TransitionSeries.Sequence>

      <TransitionSeries.Transition
        presentation={slide()}
        timing={linearTiming({ durationInFrames: TRANSITIONS.durationFrames })}
      />

      <TransitionSeries.Sequence durationInFrames={150}>
        <ContentScene
          heading="Key Points"
          bullets={["Point one", "Point two", "Point three"]}
          mediaUrl="thumbnail.png"
          mediaPosition="right"
        />
      </TransitionSeries.Sequence>

      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: TRANSITIONS.durationFrames })}
      />

      <TransitionSeries.Sequence durationInFrames={180}>
        <CodeScene title="Example Code" code={`const x = 1;\nconsole.log(x);`} />
      </TransitionSeries.Sequence>

      <TransitionSeries.Transition
        presentation={slide()}
        timing={linearTiming({ durationInFrames: TRANSITIONS.durationFrames })}
      />

      <TransitionSeries.Sequence durationInFrames={90}>
        <Outro channelName="My Channel" />
      </TransitionSeries.Sequence>
    </TransitionSeries>
  );
};
```

Calculate total duration: sum all `durationInFrames` values in `TransitionSeries.Sequence` (transitions overlap, so subtract `durationInFrames` of each `Transition` once). Register this total in `Root.tsx` as the composition's `durationInFrames`.
