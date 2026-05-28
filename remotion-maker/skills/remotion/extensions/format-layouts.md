---
name: format-layouts
description: "Layout rules for YouTube 16:9 and Story 9:16 formats with adaptation patterns"
metadata:
  tags: layout, format, aspect-ratio, responsive
---

## YouTube 16:9

**Dimensions:** 1920 × 1080 px, 30 fps

### Safe Zone

Content outside the safe zone risks being clipped on certain displays or overlapped by platform UI.

```
┌─────────────────────────────────────────────────────┐
│                  1920 × 1080 (full)                  │
│  ┌───────────────────────────────────────────────┐  │
│  │ ◄──────────── 1728 px ─────────────────────► │  │
│  │                                               │  │
│  │  Safe zone: 1728 × 912                        │  │
│  │  (96px margin each side, 84px top/bottom)     │  │
│  │                                               │  │
│  └───────────────────────────────────────────────┘  │
│                                                      │
└─────────────────────────────────────────────────────┘
  ◄── 96px ──►                       ◄── 96px ──►
```

Set `padding: 96` minimum in `LAYOUT.padding` for 16:9 compositions.

### Title Cards

- Heading font size: **64–80 px**
- Heading `maxWidth`: **80%** of composition width (1536 px max)
- Heading alignment: centered horizontally and vertically within `AbsoluteFill`
- Subtitle font size: **28–36 px**, same centering
- No more than 2 lines of heading text before layout breaks

### Content Scenes

- Two-column flexbox: text **55%** / media **45%**, `gap: 40`
- Heading font size: **48 px**
- Bullet font size: **28 px**, line height **1.5**
- Media column: `objectFit: "contain"` within its column; `borderRadius: 12`
- If no media: text occupies full width, max-width **70%** centered

### Code Scenes

- Code block max width: **85%** of composition width (1632 px max), centered
- Monospace font size: **18–20 px**
- Line height: **1.6**
- Padding inside code block: **40 px** all sides
- Maximum visible lines without scrolling: ~20 lines at 20 px / 1.6 line height

---

## Story 9:16

**Dimensions:** 1080 × 1920 px, 30 fps

### Safe Zone

Stories have UI overlay zones at top (status bar, username) and bottom (gestures, action buttons).

```
┌────────────────────────────┐
│         1080 × 1920        │
│  ── ── ── ── ── ── ── ──  │  ← 120px top (status bar)
│                            │
│  ┌──────────────────────┐  │
│  │ ◄──── 960 px ──────► │  │
│  │                      │  │
│  │  Safe zone:          │  │
│  │  960 × 1620          │  │
│  │  (60px sides,        │  │
│  │   120px top,         │  │
│  │   180px bottom)      │  │
│  │                      │  │
│  └──────────────────────┘  │
│  ── ── ── ── ── ── ── ──  │  ← 180px bottom (gestures)
└────────────────────────────┘
```

Set `padding: 60` for sides, and account for top/bottom safe zones in flex layout with `paddingTop: 120` and `paddingBottom: 180`.

### Title Cards

- Heading font size: **56–64 px**
- Heading position: **35% from top** of composition (not centered — visual center for vertical formats sits above geometric center)
- Heading `maxWidth`: **90%** of composition width (972 px max)
- Heading alignment: centered horizontally
- Subtitle font size: **24–28 px**

```tsx
// 9:16 title card vertical positioning
<AbsoluteFill
  style={{
    paddingTop: 120,
    paddingBottom: 180,
    paddingLeft: 60,
    paddingRight: 60,
    justifyContent: "flex-start",
    paddingTop: Math.round(1920 * 0.35), // ~672px from top
  }}
>
```

### Content Scenes

- **No side-by-side columns** — vertical stack only: heading → media → bullets
- Heading font size: **44–48 px**
- Media (if present): full width minus padding, `aspectRatio: "16/9"`, `borderRadius: 12`, appears between heading and bullets
- Bullets font size: **24–26 px**, line height **1.5**
- Gap between sections: **32 px**

### Code Scenes

- Code block width: **full width minus 40 px padding** each side (1000 px)
- Monospace font size: **14–16 px** (smaller to fit more lines)
- Line height: **1.5**
- Max visible lines: ~28 lines at 16 px / 1.5 line height — trim long code samples for 9:16

---

## Adapting Between Formats

When re-targeting an existing 16:9 composition for 9:16 (or vice versa), apply these 6 rules in order:

1. **Reduce font sizes ~15%.** A 72 px heading at 16:9 becomes 60–62 px at 9:16. Scale all font sizes proportionally, not just headings.

2. **Convert side-by-side layouts to vertical stacks.** Two-column flex rows (`flexDirection: "row"`) must become single-column stacks (`flexDirection: "column"`) for 9:16. The text content appears above the media by default; adjust to below if the media is illustrative rather than introductory.

3. **Reduce code font size.** Drop from 18–20 px to 14–16 px. If the code sample exceeds 20 lines, trim it — never let code overflow the visible frame.

4. **Cap chart bars at 4 for 9:16.** A 6-bar chart that works at 1920 px wide becomes illegible at 1080 px. Show the top 4 values and add a "Source: …" label if data truncation needs attribution.

5. **Image approach is the same — only dimensions change.** Ken Burns zoom and gradient overlay work identically in both formats. Adjust `objectFit` source dimensions if the original image is portrait-oriented.

6. **Reduce CTA button width at 9:16.** A full-width CTA in outro at 9:16 looks cheap. Cap at `maxWidth: 480` and keep the same padding.

---

## Composition Config

Register both format compositions in `src/Root.tsx` using the same component with format-aware props, or as separate compositions if the layout difference is too great for a single component.

```tsx
// src/Root.tsx
import { Composition } from "remotion";
import "./load-fonts";
import { MyVideo } from "./compositions/MyVideo";
import { MyVideoStory } from "./compositions/MyVideoStory";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      {/* YouTube 16:9 */}
      <Composition
        id="MyVideo-YouTube"
        component={MyVideo}
        durationInFrames={450}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          format: "youtube",
        }}
      />

      {/* Story 9:16 */}
      <Composition
        id="MyVideo-Story"
        component={MyVideoStory}
        durationInFrames={450}
        fps={30}
        width={1080}
        height={1920}
        defaultProps={{
          format: "story",
        }}
      />
    </>
  );
};
```

Both compositions must use the same `fps` value. Render commands target by composition id:

```bash
# Render YouTube version
npx remotion render MyVideo-YouTube out/youtube.mp4

# Render Story version
npx remotion render MyVideo-Story out/story.mp4
```
