---
description: "Search free resources for media assets (images, videos, audio) for video scenes"
allowed-tools: ["Read", "Write", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion", "WebSearch", "WebFetch"]
---

# /remotion-maker:find-media

Search free resource sites for images, videos, and audio to use in your Remotion videos.

## Usage
```
/remotion-maker:find-media                # interactive — describe what you need
/remotion-maker:find-media <description>  # search for a specific asset
```

## What This Does
Spawns the **media-sourcer** agent which searches Unsplash, Pexels, Pixabay, and Freesound for matching free media. Downloaded assets are saved to `.remotion-maker/media/sourced/`.

## Execution
1. Ensure dirs: source lib/common.sh, `rm_ensure_dirs .`
2. If no description provided, ask: "What kind of media are you looking for? Describe the content and type (image, video clip, audio/sfx)."
3. Spawn media-sourcer agent with search description and project path.
4. Report: "Assets saved to `.remotion-maker/media/sourced/`. Use them in your next video with `staticFile()`."
