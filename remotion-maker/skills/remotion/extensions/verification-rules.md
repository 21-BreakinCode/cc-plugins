---
name: verification-rules
description: "Codified verification checks for the video-verifier agent across 3 tiers: static code analysis, frame sampling, and Playwright playback"
metadata:
  tags: verification, testing, quality, style-drift
---

## Overview

The video-verifier agent runs three tiers of checks in sequence. Each tier has a defined pass/fail threshold. Abort and report if any tier produces errors — warnings are noted but do not block subsequent tiers.

**Tier order:** Static analysis first (fastest, catches most issues), then frame sampling (visual validation), then Playwright playback (runtime validation). Do not run Tier 2 or 3 if Tier 1 has errors.

---

## Tier 1: Static Code Analysis

Run all checks against source files under `src/`. Read the project's style definition from `.remotion-maker/styles/*.md` before running checks — the frontmatter values are the reference data.

### 1.1 Palette Check

**Purpose:** Ensure no hardcoded hex colors exist that are not in the style definition.

**Pattern:**
```
/#[0-9A-Fa-f]{6}\b/g
```

Run this regex against all `.tsx` and `.ts` files under `src/` (excluding `styles.ts` itself — that file is the authoritative source).

**Exceptions** (allow without matching against palette):
- `#FFFFFF` — pure white, valid for text-on-image contexts
- `#000000` — pure black, valid for shadow/overlay contexts
- `#0F172A` — code block background (hardcoded in CodeScene intentionally)

**Pass criterion:** Zero unrecognized hex values outside the exception list. Every other hex found must appear in `PALETTE` within `styles.ts`.

**Failure example:**
```
FAIL src/scenes/TitleCard.tsx:34 — hardcoded color #E2E8F0 not in PALETTE
```

### 1.2 Font Check

**Purpose:** Ensure all fonts used in components are declared in `styles.ts` and all declared fonts are loaded.

**Patterns:**
```
/fontFamily:\s*["']([^"']+)["']/g        // font usage in style objects
/fontFamily:\s*\{[^}]*\}/g              // font usage via FONTS.*.family
/loadFont\(/g                            // font loading calls in load-fonts.ts
```

**Check both directions:**
1. Every `FONTS.*.family` value in `styles.ts` must have a corresponding `loadFont` call in `load-fonts.ts`.
2. Every literal `fontFamily` string in components must match a value that resolves to a `FONTS.*` constant.

**Pass criterion:** All fonts accounted for in both directions — no orphaned loads, no unloaded families.

### 1.3 Transition Check

**Purpose:** Ensure only transition types declared in `TRANSITIONS.types` are used, and durations match.

**Patterns:**
```
/import\s+\{[^}]*\}\s+from\s+["']@remotion\/transitions\/(\w+)["']/g   // imported types
/durationInFrames:\s*(\d+)/g                                              // transition durations
```

**Checks:**
1. Extract all transition presenter imports (e.g., `slide`, `fade`, `wipe`).
2. Each must appear in `TRANSITIONS.types` in `styles.ts`.
3. Each `durationInFrames` in a `TransitionSeries.Transition` must be within **±3 frames** of `TRANSITIONS.durationFrames`.

**Pass criterion:** Zero unauthorized transition types. All durations within tolerance.

### 1.4 Animation Check

**Purpose:** Ensure no CSS animations are used and all scene components access the timeline.

**Forbidden patterns (must not match):**
```
/\banimate-\w+/g          // Tailwind animate-* classes
/transition:\s*[^;]+;/g   // CSS transition shorthand
/animation:\s*[^;]+;/g    // CSS animation shorthand
/@keyframes\s+\w+/g       // CSS keyframes declarations
```

**Required patterns (must match in every scene file):**
```
/useCurrentFrame\(\)/     // every scene file under src/scenes/ must call this
```

**Pass criterion:** Zero forbidden patterns. Every file in `src/scenes/` contains at least one `useCurrentFrame()` call.

### 1.5 Remotion Practices

**Purpose:** Ensure native HTML media elements are not used (they break Remotion's render pipeline).

**Forbidden patterns (must not match in any `.tsx` file):**
```
/<img\s/gi      // use Remotion <Img> instead
/<video\s/gi    // use Remotion <Video> instead
/<audio\s/gi    // use Remotion <Audio> instead
```

**Required patterns:**
```
/staticFile\(/  // all asset paths must go through staticFile()
```

**Pass criterion:** Zero native media element usages. Every asset reference uses `staticFile()`.

### 1.6 Structure Check

**Purpose:** Ensure `Root.tsx` registers all compositions correctly.

**Patterns:**
```
/<Composition\s[^/]*id=["']([^"']+)["']/g      // composition ids
/<Composition\s[^/]*width=\{?(\d+)\}?/g         // widths
/<Composition\s[^/]*height=\{?(\d+)\}?/g        // heights
/<Composition\s[^/]*fps=\{?(\d+)\}?/g           // fps values
```

**Checks:**
1. At least one `<Composition>` is registered.
2. Each composition has a non-empty `id`.
3. Width/height pair must be either `1920/1080` (16:9) or `1080/1920` (9:16).
4. `fps` must be `30` (other values are not supported by the remotion-maker preset system).

**Pass criterion:** All registered compositions have valid id, valid format dimensions, and `fps={30}`.

### Tier 1 Report Format

```
TIER 1: Static Code Analysis
─────────────────────────────
1.1 Palette Check     [PASS|FAIL|WARN]  <detail>
1.2 Font Check        [PASS|FAIL|WARN]  <detail>
1.3 Transition Check  [PASS|FAIL|WARN]  <detail>
1.4 Animation Check   [PASS|FAIL|WARN]  <detail>
1.5 Remotion Practices[PASS|FAIL|WARN]  <detail>
1.6 Structure Check   [PASS|FAIL|WARN]  <detail>

Files scanned: <N>
Errors: <N>  Warnings: <N>
```

---

## Tier 2: Frame Sampling

Render individual frames with the Remotion CLI and inspect them visually or via image analysis. Requires Tier 1 to pass.

**Command template:**
```bash
npx remotion still <composition-id> --scale=0.5 --frame=<N> --output=.verify/frame-<N>.png
```

Sample frames at: frame 0 (first frame), frame at 50% of duration, frame at 90% of duration, and one frame per scene transition midpoint.

### 2.1 Layout Check

For each sampled frame, verify:
- Text is not clipped at frame edges
- Content stays within the safe zone margins (96 px for 16:9, 60 px sides / 120 px top / 180 px bottom for 9:16)
- No element overflows the composition boundaries

**Pass criterion:** Zero clipped elements in any sampled frame.

### 2.2 Visual Consistency Check

For each sampled frame, verify:
- Background color matches `PALETTE.background`
- Primary text color matches `PALETTE.text`
- No unexpected white or fully transparent frames (except intentional fade transitions)
- Font rendering is consistent (no fallback system fonts visible)

**Pass criterion:** All sampled frames use palette-consistent colors.

### 2.3 Composition Check

For each sampled frame, verify:
- Scene content is visible and not blank at non-transition frames
- Animations are mid-progress at the midpoint frame (not stuck at start or end)
- No z-index stacking artifacts (elements unexpectedly hidden behind others)

**Pass criterion:** All non-transition frames contain visible, animated content.

### 2.4 Render Health Check

Run a full render of the first 60 frames and confirm no errors:
```bash
npx remotion render <composition-id> --frames=0-59 --output=.verify/health-check.mp4
```

**Pass criterion:** Render exits with code 0. No `[error]` lines in stdout/stderr.

### Tier 2 Report Format

```
TIER 2: Frame Sampling
──────────────────────
Frames sampled: <list of frame numbers>
2.1 Layout Check        [PASS|FAIL|WARN]  <detail>
2.2 Visual Consistency  [PASS|FAIL|WARN]  <detail>
2.3 Composition Check   [PASS|FAIL|WARN]  <detail>
2.4 Render Health       [PASS|FAIL|WARN]  <detail>

Errors: <N>  Warnings: <N>
```

---

## Tier 3: Playwright Playback

Full runtime validation using Playwright to drive Remotion Studio. Requires Tier 1 and Tier 2 to pass.

### 3.1 Setup

Start Remotion Studio and wait for it to be ready:

```bash
# Start studio in background
npx remotion studio --port=3100 &
STUDIO_PID=$!

# Wait for studio to respond
npx wait-on http://localhost:3100 --timeout=30000
```

Navigate Playwright to the composition:
```javascript
const { chromium } = require('playwright');
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto('http://localhost:3100');

// Select the target composition from the sidebar
await page.getByText('<composition-id>').click();
await page.waitForTimeout(1000);
```

### 3.2 Playback Screenshots

Capture screenshots at key moments during playback:

```javascript
// Frame 0 — initial state
await page.screenshot({ path: '.verify/playwright-frame0.png' });

// Seek to first transition midpoint
await page.evaluate(() => {
  window.__REMOTION_STUDIO_SEEK__(<transition-frame>);
});
await page.waitForTimeout(500);
await page.screenshot({ path: '.verify/playwright-transition1.png' });

// Seek to mid-composition
await page.evaluate(() => {
  window.__REMOTION_STUDIO_SEEK__(<mid-frame>);
});
await page.waitForTimeout(500);
await page.screenshot({ path: '.verify/playwright-mid.png' });

// Seek to last frame
await page.evaluate(() => {
  window.__REMOTION_STUDIO_SEEK__(<last-frame>);
});
await page.waitForTimeout(500);
await page.screenshot({ path: '.verify/playwright-last.png' });
```

**Pass criterion:** All 4 screenshots are non-blank, no browser console errors logged.

### 3.3 Audio Sync (if applicable)

If the composition includes audio:
1. Seek to a frame where audio and visuals should be synchronized (e.g., a subtitle appearing with spoken word).
2. Confirm the subtitle text visible in the screenshot matches the expected transcript line for that timestamp.
3. Check browser console for `[remotion:audio]` warnings indicating buffer issues.

**Pass criterion:** No audio buffer warnings. Subtitle text matches expected transcript at sampled frame.

### 3.4 Cleanup

Always kill the studio process after Playwright tests complete:

```bash
kill $STUDIO_PID 2>/dev/null || true
# Remove temp files
rm -rf .verify/
```

### Tier 3 Report Format

```
TIER 3: Playwright Playback
────────────────────────────
Studio URL:      http://localhost:3100
Composition:     <composition-id>
Screenshots:     .verify/playwright-*.png

3.1 Setup         [PASS|FAIL]  <detail>
3.2 Playback      [PASS|FAIL]  <detail>
3.3 Audio Sync    [PASS|FAIL|SKIP]  <detail or "no audio in composition">
3.4 Cleanup       [PASS|FAIL]  <detail>

Console errors:   <N>
Errors: <N>  Warnings: <N>
```

---

## Overall Report

Write the final report as YAML frontmatter followed by a prose summary of any failures. Save to `.verify/report.md` within the Remotion project.

```yaml
---
video: <composition-id>
style: <style-definition-filename>
tiers_run:
  - tier1_static
  - tier2_frames     # omit if not run
  - tier3_playwright # omit if not run
pass: true           # false if any tier has errors
warnings: 0
errors: 0
---
```

**Pass criteria (all must be true):**
- Tier 1: zero errors (warnings are allowed)
- Tier 2: zero errors, zero blank non-transition frames
- Tier 3: zero console errors, all screenshots non-blank

If `pass: false`, the prose body must list each failing check by tier and check number (e.g., "1.1 Palette Check — found 3 unrecognized hex values") and provide the file path and line number where each issue was found. Do not summarize failures — list them exhaustively so the generator agent can fix them in one pass.
