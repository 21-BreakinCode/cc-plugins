# Rubric (10 checks, 1 point each, pass/fail)

Checks 1–5 come from `python3 $X/lint.py "<drawing>" --score`. Checks 6–10 come from
looking at the rendered PNG. A score of 10/10 needs every check to pass.

Score as a strict reviewer. For each visual check, look for its failure examples first.
If any failure example applies, the check fails, even if the rest looks good.

| # | Check | Pass when |
|---|---|---|
| 1 | No overlap | lint has no `overlap` and no `straddles` error |
| 2 | Lines clear of text | lint has no `crosses text` error |
| 3 | Lines do not tangle | lint has no `arrows cross`, `arrowheads collide`, `arrow too short`, or `caption pointer` error, and every arrow is bound at one end or more |
| 4 | Layer order | lint has no `layer order` error |
| 5 | Palette and font | lint has no `off-palette` and no `non-handwritten font` warning |
| 6 | Spacing shows grouping | Regions read as separate islands, and each group reads as one unit |
| 7 | Text-to-diagram clarity | Every diagram, curve, and box has a label. Every named relation (trigger, condition, probability) is an arrow label. Each label obviously belongs to one thing. A plain sequence arrow needs no label |
| 8 | Line style | Each line type matches its job (principle 5) and every tip lands on its target with a visible gap |
| 9 | Hierarchy and layers | Title > heading > body > caption. Emphasis is a band on text. Panels sit behind text. Each region has a heading directly above it |
| 10 | Readable in one pass | Nothing clipped or cut by the canvas edge. The reading order is obvious |

## Failure examples (seen in real runs)

- 6: A table spread with 96 px between rows, so rows look like separate regions.
  A heading 300 px away from the boxes it names. A set name 100 px away from its circle. A caption closer to the next box than to its own.
- 7: An arrow label squeezed against a box. A color whose meaning the reader cannot see.
  Actors or parts that exist only inside box text instead of as shapes joined by lines.
  Row headings placed over the left column only, so the right column has no label.
  A transition trigger floating between two arrows instead of riding its own arrow.
  A chart that shows "8 points" as corners of a line with no point markers.
- 8: A curved arrow between two boxes in the same column. A long arrow that crosses
  into another region. A caption pointer that cuts through shape outlines to reach a
  target it can sit next to. Two arrowheads on the same pixel. An arrow that leaves the
  right side of a box and climbs steeply to a box above it. An arrow to a caption when the caption can sit next to its target.
- 9: A highlight band on a box that spills past the box border. A band so thick that it
  covers part of a formula. A heading that floats
  between two groups. A region with no heading.
- 10: Text cut at the right edge. A reader cannot tell which region to read first.

These cases are intended and do not fail a check:
- a 12 px gap between a heading and its own caption,
- a band under a title,
- text inside a panel,
- arrows that fan out from one side of a box.
