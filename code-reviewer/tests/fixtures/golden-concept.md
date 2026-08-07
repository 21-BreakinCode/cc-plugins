---
type: Pitfall
title: ffprobe returns empty streams on 0-byte upload
status: stable
stale_after: 2027-02-07
sources:
  - resource: https://github.com/plaxieappier/video-center-2/pull/812
    title: PR #812
  - resource: a1b2c3d4e5f
generated: { by: refresh-principles/opus-4-8, at: 2026-08-07T00:00:00Z }
verified: [ { by: human:whung, at: 2026-08-07 } ]
---
**What:** ffprobe returns an empty streams array when handed a 0-byte upload.

**Why it matters:** downstream code indexes streams[0] and crashes.
