---
name: youtube-16-9
width: 1920
height: 1080
fps: 30
safe_zone:
  top: 84
  bottom: 84
  left: 96
  right: 96
---

# YouTube 16:9 Format

Standard landscape video for YouTube, presentations, and web.

## Composition Registration

```tsx
<Composition
  id="<video-name>"
  component={MyVideo}
  width={1920}
  height={1080}
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
