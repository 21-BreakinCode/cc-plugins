# remotion-maker

> Generate styled Remotion videos, end to end

A full pipeline for Remotion (React) videos: define a consistent style, generate scenes from your content, source free media, review preview frames, and verify against the style before rendering to MP4.

## Install

```bash
claude plugin install remotion-maker@cc-plugins
```

## Commands

- **`/remotion-maker:create`** — Full video creation pipeline: style -> generate -> preview -> verify -> render
- **`/remotion-maker:define-style`** — Create or manage video style definitions for consistent series look and feel
- **`/remotion-maker:find-media`** — Search free resources for media assets (images, videos, audio) for video scenes
- **`/remotion-maker:verify`** — Verify generated Remotion video against style definition (3-tier: static, frame sampling, Playwright)

---

Part of the [cc-plugins](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
