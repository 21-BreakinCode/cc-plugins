# Style kit API (`style_kit.js`)

Every helper returns a block `{id, x, y, w, h, right, bottom}`. Lay out the next block
from these numbers. Roles: `body`, `primary`, `secondary`, `warning`, `callout`, `muted`.
Default roles: boxes, flows, stacks, formulas, and curves are `primary`. Arrows are `muted`.
Text is `body`. Outline shapes are `muted`.
Text content can hold `\n` for a forced line break.

| Helper | Use |
|---|---|
| `kit.TOKENS` | `pageMargin` 48, `columnGap` 120, `sectionGap` 96, `blockGap` 24, `lineGap` 12, `arrowClearance` 12 |
| `kit.columnX(index, columnWidth)` | x of column `index` (0-based) with page margin and column gap |
| `kit.title(x, y, {breadcrumb, heading, subtitle})` | page header with a band under the title |
| `kit.heading(x, y, number, label, role)` | circled number + heading label, grouped |
| `kit.text(x, y, content, {role, size, width, anchor})` | size is `title`, `heading`, `body`, `caption`, or px. `width` wraps the text inside that width. `anchor: 'center'` makes x the center |
| `await kit.formula(x, y, tex, {role, scale})` | LaTeX image colored by role. Default scale 2.2. Use 1.6–1.8 for long formulas |
| `kit.box(x, y, content, {role, width, padding})` | rounded rectangle with centered text. (x, y) is the outer corner |
| `kit.flow(x, y, items, {role, gap, width})` | row of boxes with straight arrows. An item is a string or `{label, role, arrowLabel}`. `arrowLabel` names the arrow INTO that box. Default gap 64. Gaps grow to fit labels |
| `kit.stack(x, y, items, {role, gap, width})` | column of boxes, no arrows. An item is a string or `{label, role}`. Default gap 48. For fork targets and parallel parts |
| `kit.middleY(first, last, height)` | y that centers a block of `height` on the span from `first` to `last` |
| `kit.arrow(from, to, {role, label})` | straight bound arrow between the facing sides. Boxes that share a column or row get a perfectly straight arrow, whatever their widths. `label` rides beside it |
| `kit.pointer(from, to, {role, bend, via, label})` | curved arrow. It bows sideways by min(abs(bend) × length, 80 px). A positive `bend` bows left of the travel direction. `via: [x, y]` sets the bend point. Aligned ends give a straight arrow |
| `kit.spot(x, y)` | zero-size target for `pointer` or `arrow` (a curve peak, a data point) |
| `kit.dot(x, y, {role, size})` | filled dot centered on (x, y) |
| `kit.ellipse(x, y, w, h, {role})` / `kit.rect(...)` | plain outline shape (contour ring, zone, marker) |
| `kit.style(role)` | set `ea.style` to a role before a raw `ea.add*` call |
| `kit.label(target, content, {role, size, sides, gap})` | label beside a block, dot, or shape. Placed after the layout on the first least crowded side of `sides` (default right, above, left, below) |
| `kit.centeredText(x, y, content, {role, size, width})` | text centered on (x, y) in both directions |
| `kit.path(points, {role})` | dots joined by short arrows (optimizer steps, a trajectory). Keep points 48 px or more apart |
| `kit.sequence(x, y, actors, messages, {rowGap, role})` | sequence diagram: actor boxes, dashed lifelines, one labeled message arrow per row. A message is `{from, to, label, role}`. Returns `{actors, rows, bottom, right}` |
| `kit.venn(centerX, centerY, sets, overlaps, {radius})` | 2 or 3 circles. `sets` is `[{label, role}]`. `overlaps` maps `'0+1'`, `'0+2'`, `'1+2'`, `'0+1+2'` to lens labels |
| `kit.highlight(block, role)` | thin band (14 px or less) behind the bottom of a free text or formula. It throws an error on a box |
| `kit.panel(x, y, w, h, role)` | translucent filled panel, sent to back. Size it after placing its text |
| `kit.dashed(x1, y1, x2, y2, role)` | dashed reference line |
| `kit.chart(x, y, w, h, points, {role, smooth, markers})` | L-axis + first curve. `points` are chart-local px, and y grows down. `markers: true` puts a dot on each point |
| `kit.curve(chart, points, {role, smooth, markers})` | another curve on an existing chart, no second axis |

Arrow labels are placed after the layout script ends (build.py does it). Each label
takes the side of its arrow with the fewest neighbors, away from sibling arrows. Do not
place anything that depends on a label position.

Arrows that attach to the same side of one box fan out by themselves. An arrow between side-by-side
blocks leaves from the left or right side, unless the vertical gap is more than twice
the horizontal gap. So all branches of a fork leave from the same side. `kit.flow` arrows are `muted`
gray on purpose, so the boxes carry the color.

## Base pattern

```js
const columnWidth = 460;
const leftX = kit.columnX(0, columnWidth);
const header = kit.title(leftX, kit.TOKENS.pageMargin, { heading: 'Title', subtitle: 'one line' });
const heading = kit.heading(leftX, header.bottom + kit.TOKENS.sectionGap, 1, 'Region heading');
const formula = await kit.formula(leftX + 16, heading.bottom + kit.TOKENS.blockGap, 'a^2 + b^2 = c^2');
const note = kit.text(leftX + 16, formula.bottom + kit.TOKENS.blockGap, 'Body text', { width: columnWidth - 16 });

// Takeaway panel: place its text first, then size the panel to fit.
const panelTop = note.bottom + kit.TOKENS.sectionGap;
const panelTitle = kit.text(leftX + 24, panelTop + 20, 'Takeaway', { role: 'callout', size: 'heading' });
const panelBody = kit.text(leftX + 24, panelTitle.bottom + kit.TOKENS.lineGap, 'Summary line');
kit.panel(leftX, panelTop, columnWidth, panelBody.bottom + 20 - panelTop, 'callout');
```

## Comparison (N attributes × 2 sides) is ONE region

Put the attribute names in a narrow left column and one value column per side. Head
each side once at the top in its role color. Use `blockGap` between rows, not `sectionGap`.

```js
const attributeX = leftX, tcpX = leftX + 180, udpX = tcpX + 360;
const tcpHead = kit.text(tcpX, top, 'TCP', { role: 'primary', size: 'heading' });
kit.text(udpX, top, 'UDP', { role: 'secondary', size: 'heading' });
let rowTop = tcpHead.bottom + kit.TOKENS.blockGap;
for (const [name, tcp, udp] of rows) {
  const cells = [kit.text(attributeX, rowTop, name, { role: 'muted' }),
                 kit.text(tcpX, rowTop, tcp, { role: 'primary', width: 320 }),
                 kit.text(udpX, rowTop, udp, { role: 'secondary', width: 320 })];
  rowTop = Math.max(...cells.map((cell) => cell.bottom)) + kit.TOKENS.blockGap;
}
```

## State machine or process with named transitions

```js
const states = kit.flow(leftX, top, ['Created', { label: 'Paid', arrowLabel: 'payment ok' }], { width: 130 });
const cancelled = kit.box(states[0].x, states[0].bottom + 96, 'Cancelled', { role: 'warning', width: 130 });
kit.arrow(states[0], cancelled, { role: 'warning', label: 'buyer cancels' });   // same column: straight
kit.arrow(states[1], cancelled, { role: 'warning', label: 'refund' });          // diagonal: still straight
```

If possible, place each branch target in the same column or row as its source. The
arrows then stay short and straight.

## Fork and merge (architecture, pipelines)

Put the parallel parts in one column with `kit.stack`, one column to the right of the
source. Put the merge target one more column to the right, centered on the stack.
Take every x from returned blocks. Do not use `kit.columnX` next to `kit.flow`,
because flow gaps grow to fit labels.

```js
const trunk = kit.flow(leftX, top, ['Browser', 'CDN', 'API Gateway'], { width: 140 });
const gateway = trunk[2];
const services = kit.stack(gateway.right + 120, gateway.y - 40, ['Auth service', 'Order service'], { width: 150 });
const postgres = kit.box(services[0].right + 120, kit.middleY(services[0], services[1], 48), 'Postgres', { width: 140 });
services.forEach((service) => { kit.arrow(gateway, service); kit.arrow(service, postgres); });
const cache = kit.box(postgres.x, services[1].bottom + 96, 'Redis cache', { role: 'secondary', width: 140 });
kit.arrow(services[1], cache, { role: 'secondary', label: 'reads' });
kit.arrow(cache, postgres, { role: 'warning', label: 'cache miss' });   // same column: short and straight
```

Place a box that relates to two others where both arrows stay short. Here Redis sits
under Postgres, so the cache-miss arrow is a short vertical line.

A side note that belongs to one box (such as "rate-limits") sits right under that box
as a caption, with no arrow.

## Tree (two or more levels)

Stack each level's children with `kit.stack`, starting a little above their parent so
the stack straddles it. If a heading sits right above the tree, start the root lower by
that same offset, so the first level does not rise into the heading. Leave `sectionGap` between sibling subtrees
so their child stacks never touch. Put each branch probability or condition in the
arrow `label`.

```js
const root = kit.box(leftX, top, '10,000 people', { role: 'body', width: 150 });
const levelOne = kit.stack(root.right + 120, top - 120, ['Disease\n100', 'No disease\n9,900'], { width: 150, gap: 180 });
levelOne.forEach((node, index) => kit.arrow(root, node, { label: ['1%', '99%'][index] }));
for (const parent of levelOne) {
  const leaves = kit.stack(parent.right + 120, parent.y - 40, ['Test +', 'Test −'], { width: 140 });
  leaves.forEach((leaf, index) => kit.arrow(parent, leaf, { label: ['95%', '5%'][index] }));
}
```

## Chart with several curves and zones

Draw the first curve with `kit.chart` and the others with `kit.curve`. Label each curve
at its right end in the curve's color, so no legend is needed. Mark a zone boundary with
`kit.dashed` and put each zone caption inside the chart above its zone. Leave 40 px or
more of empty chart above the highest curve point, so the zone captions have room.

```js
const chart = kit.chart(leftX, top, 480, 240, biasPoints, { role: 'primary' });
kit.curve(chart, variancePoints, { role: 'secondary' });
kit.curve(chart, totalPoints, { role: 'warning' });   // chart top: 40 px above the highest point
kit.dashed(chart.x + sweetX, chart.y, chart.x + sweetX, chart.bottom);
kit.text(chart.x + 16, chart.y + 8, 'underfitting', { role: 'muted', size: 'caption' });
kit.text(chart.right - 16, chart.y + 8, 'overfitting', { role: 'muted', size: 'caption', anchor: 'center' });
```

## Sequence, Venn, and point labels

Use a helper whenever one fits. Hand-placed geometry for these shapes fails often.

```js
const flowTop = header.bottom + kit.TOKENS.sectionGap;
const oauth = kit.sequence(leftX, flowTop, ['User', 'App', 'Auth server', 'API'], [
  { from: 'App', to: 'Auth server', label: 'redirect to login' },
  { from: 'App', to: 'Auth server', label: 'code → token (server side)', role: 'warning' },
]);
kit.venn(leftX + 300, oauth.bottom + kit.TOKENS.sectionGap + 260,
  [{ label: 'Software' }, { label: 'Statistics' }, { label: 'Domain' }],
  { '0+1': 'ML engineering', '0+1+2': 'Data scientist' });
const steps = kit.path([[100, 100], [180, 130], [240, 150]]);
kit.label(steps[steps.length - 1], 'minimum', { role: 'primary' });
```

A name for a single point, dot, or shape is a `kit.label`, never a pointer from far away.

## Chart with a callout on one point

```js
const chart = kit.chart(leftX, top, 360, 140, samplePoints, { smooth: false, markers: true });
const [peakX, peakY] = samplePoints[3];
const peakLabel = kit.text(chart.x + peakX + 40, chart.y - 32, 'above UCL', { role: 'warning', size: 'caption' });
kit.pointer(peakLabel, kit.spot(chart.x + peakX, chart.y + peakY), { role: 'warning' });
```

Rule: keep every chart label 24 px or more away from every curve. Keep a callout label
60 px or more away from the point it names, so the pointer stays long enough to show its tip.
`via` must lie between the two ends. The curve passes through it, so a `via` point
beyond the target makes the curve overshoot. Lint checks arrows against text and
against other arrows. It does not check arrows against chart lines.

## Coordinates

`lint.py --dump` prints drawing coordinates. The PNG export crops to the content plus a
small margin, so PNG pixels are offset from drawing coordinates. Judge clipping and
spacing from the PNG.
