---
name: story-9-16
width: 1080
height: 1920
fps: 30
safe_zone:
  top: 120
  bottom: 180
  left: 60
  right: 60
---

# Story 9:16 Format

Vertical video for Instagram Stories, TikTok, YouTube Shorts.

## Composition Registration

```tsx
<Composition
  id="<video-name>"
  component={MyVideo}
  width={1080}
  height={1920}
  fps={30}
  durationInFrames={/* total */}
/>
```

## Render Command

```bash
npx remotion render src/index.ts <video-name> out/<video-name>.mp4
```

## Preview Command

```bash
npx remotion still src/index.ts <video-name> --frame=<N> out/preview-frame-<N>.png
```
