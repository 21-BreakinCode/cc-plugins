# Excalidraw principles

Every Excalidraw drawing in this vault follows the principles below, whatever it shows:
a study card, a flowchart, an architecture map, a timeline, or a comparison.

## Principles

1. **Distance shows grouping.** Things that belong together sit close. Things that do not
   sit far apart. Inside a group: 12 px (a line and its caption) to 24 px (blocks).
   Between regions: `sectionGap` 96 px vertically, `columnGap` 120 px side by side.
   Every label is closer to its own subject than to anything else. Leave at least 40% of
   the canvas empty, but never spread one group so wide that it falls apart.
2. **A region is one idea with its heading directly on top.** The heading sits right
   above its content, left edges aligned, `blockGap` below it. Never put a heading in one
   column and its content in another. If reading order matters, use `kit.heading` with a
   circled number. A comparison or table is ONE region (see `references/kit.md`).
   A drawing with only one region uses the page title as its heading.
3. **Colors carry meaning.** The stored values are light-theme colors that render correctly in dark.
   - `body` #1e1e1e: text.
   - `primary` #0c8599: main concept, formulas.
   - `secondary` #6741d9: second concept, the other side of a comparison.
   - `warning` #e03131: pitfall, caveat.
   - `callout` #f08c00: summary panel.
   - `muted` #868e96: axes, footnotes, neutral captions.
   A caption about one colored element uses that element's color. Use at most 3 accent
   roles per drawing. A third peer concept (such as a third Venn set) uses `callout`.
   Every color must have a meaning the reader can see: a legend, a label in that color,
   or a warning.
4. **Emphasis is a highlight band, never bold.** `kit.highlight` marks free text or a
   formula only. To mark a box, give the box a role color. At most 1 band per region.
5. **Lines explain relations. They never create clutter.**
   - First try to place the related things next to each other. A caption that sits next
     to its subject needs no arrow. A caption pointer stays under 160 px and crosses no
     shape outline.
   - Same row or column → straight arrow (`kit.arrow`, `kit.flow`). Fork and merge arrows
     are straight too.
   - Only a relation that must bend (around content, into a chart) gets a curved
     `kit.pointer`. When the ends align, it falls back to straight.
   - A relation name (trigger, protocol, condition) is the arrow's `label`, never a loose
     text near the arrow.
   - Arrows never cross text, never cross each other, and never share an arrowhead point.
     No arrow travels across a whole region. If one must, move the boxes instead.
   - Dashed lines only for reference levels (thresholds, limits, spec lines).
6. **Layers are explicit:** panels → highlight bands → shapes → text → arrows.
   A takeaway or summary goes in one full-width amber `kit.panel` below the regions.
7. **Typography:** Excalifont only (CJK falls back to a handwriting font). Sizes: title 36,
   heading 22, body 16, caption 13. Formulas are LaTeX via `kit.formula`, colored by role.
8. **Page drawings get a header:** optional breadcrumb, title with a highlight band,
   gray subtitle. `kit.title` does all three.
9. **Charts are minimal:** L-shaped muted axis, 1–2 curves in role colors, small labels,
   no grid. Sampled data gets point markers (`markers: true`).
