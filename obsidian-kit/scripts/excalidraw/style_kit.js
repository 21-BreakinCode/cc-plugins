// excalidraw-refine style kit. Loaded by build.py; `ea` and `kit` are in scope of the build script.
// Every helper returns a block {id, x, y, w, h, right, bottom} so callers lay out from real sizes.
const TOKENS = {
  pageMargin: 48,
  columnGap: 120,      // between side-by-side regions
  sectionGap: 96,      // between stacked regions
  blockGap: 24,        // between blocks inside a region
  lineGap: 12,         // between a heading/line and its caption
  arrowClearance: 12,  // gap between an arrow tip and the shape it points at
};
const ROLE_COLORS = {
  body: '#1e1e1e',      // renders off-white in dark theme
  primary: '#0c8599',   // teal: main concept, formulas
  secondary: '#6741d9', // purple: second concept, comparison
  warning: '#e03131',   // coral: pitfall, caveat
  callout: '#f08c00',   // amber: summary / takeaway panel
  muted: '#868e96',     // gray: captions, axes, footnotes
};
const FONT_SIZES = { title: 36, heading: 22, body: 16, caption: 13 };
const HANDWRITTEN_FONT = 5; // Excalifont; CJK falls back to Xiaolai handwriting
const LATEX_SCALE = 2.2;
const HIGHLIGHT_OPACITY = 25;
const PANEL_OPACITY = 22;
const MAX_POINTER_BOW_PX = 80;
const ATTACH_SPREAD_PX = 18;
const ALIGN_TOLERANCE_PX = 24;
const ARROW_LABEL_OFFSET_PX = 6;
const DOT_SIZE_PX = 8;
const MAX_HIGHLIGHT_PX = 14;
const HORIZONTAL_SIDE_BIAS = 2;
const SMALL_TARGET_PX = 16;          // dots and markers
const SMALL_TARGET_CLEARANCE_PX = 4;
const MIN_SHARED_SPAN_PX = 16;
const LABEL_POSITIONS_ALONG_ARROW = [0.5, 0.4, 0.6];
const SIBLING_CLEARANCE_PX = 30;

const toBlock = (id) => {
  const e = ea.getElement(id);
  return { id, x: e.x, y: e.y, w: e.width, h: e.height, right: e.x + e.width, bottom: e.y + e.height };
};

const resetStyle = (role) => {
  Object.assign(ea.style, {
    strokeColor: ROLE_COLORS[role] ?? ROLE_COLORS.body, backgroundColor: 'transparent',
    fillStyle: 'solid', strokeWidth: 1.5, strokeStyle: 'solid', roughness: 1, opacity: 100,
    fontFamily: HANDWRITTEN_FONT, roundness: null, startArrowHead: null, endArrowHead: null,
  });
};

// Decorative shapes (highlight band, panel) are tagged so lint knows text may sit on them.
const tagDecoration = (id, kind) => ea.addAppendUpdateCustomData(id, { excalidrawRefine: kind });

const sendToBack = (id) => {
  const moved = ea.elementsDict[id];
  const rest = Object.entries(ea.elementsDict).filter(([key]) => key !== id);
  ea.elementsDict = Object.fromEntries([[id, moved], ...rest]);
};

// Greedy wrap with real glyph widths. Latin wraps at spaces, CJK wraps per character.
const wrapToWidth = (content, maxWidth) => content.split('\n').map((paragraph) => {
  const tokens = paragraph.match(/[\u2E80-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF][，。、；：！？）」』]*|[^\s\u2E80-\u9FFF\uF900-\uFAFF\uFF00-\uFFEF]+|\s+/g) ?? [''];
  const lines = [''];
  for (const token of tokens) {
    const candidate = lines[lines.length - 1] + token;
    if (lines[lines.length - 1].trim() && ea.measureText(candidate).width > maxWidth) {
      lines.push(token.trimStart());
    } else {
      lines[lines.length - 1] = candidate;
    }
  }
  return lines.map((line) => line.trimEnd()).join('\n');
}).join('\n');

// anchor: 'center' makes x the horizontal center of the text instead of its left edge.
const text = (x, y, content, { role = 'body', size = 'body', width, anchor = 'left' } = {}) => {
  resetStyle(role);
  ea.style.fontSize = FONT_SIZES[size] ?? size;
  const id = ea.addText(x, y, width ? wrapToWidth(content, width) : content);
  if (anchor === 'center') ea.getElement(id).x -= ea.getElement(id).width / 2;
  return toBlock(id);
};

const highlight = (block, role = 'callout') => {
  const target = ea.getElement(block.id);
  if (!target || !['text', 'image'].includes(target.type) || target.containerId) {
    throw new Error('kit.highlight marks free text or a formula only. To mark a box, give it a role color.');
  }
  resetStyle(role);
  ea.style.backgroundColor = ROLE_COLORS[role];
  ea.style.strokeColor = 'transparent';
  ea.style.opacity = HIGHLIGHT_OPACITY;
  ea.style.roughness = 2;
  const bandHeight = Math.min(Math.max(8, block.h * 0.3), MAX_HIGHLIGHT_PX);
  const id = ea.addRect(block.x - 6, block.bottom - bandHeight, block.w + 12, bandHeight);
  tagDecoration(id, 'highlight');
  sendToBack(id);
  return toBlock(id);
};

const title = (x, y, { breadcrumb, heading, subtitle }) => {
  const crumb = breadcrumb ? text(x, y, breadcrumb, { role: 'primary', size: 'caption' }) : null;
  const main = text(x, crumb ? crumb.bottom + TOKENS.lineGap : y, heading, { size: 'title' });
  highlight(main, 'callout');
  const sub = subtitle ? text(x, main.bottom + TOKENS.lineGap, subtitle, { role: 'muted', size: 'caption' }) : null;
  return { ...main, y, bottom: (sub ?? main).bottom };
};

const heading = (x, y, number, label, role = 'primary') => {
  resetStyle(role);
  ea.style.fontSize = FONT_SIZES.heading;
  const numberLabel = String(number).padStart(2, '0');
  const badgeSize = FONT_SIZES.heading * 1.6;
  const badge = ea.addEllipse(x, y, badgeSize, badgeSize);
  const numberText = ea.addText(0, 0, numberLabel);
  const numberElement = ea.getElement(numberText);
  numberElement.x = x + (badgeSize - numberElement.width) / 2;
  numberElement.y = y + (badgeSize - numberElement.height) / 2;
  const labelBlock = text(x + badgeSize + TOKENS.lineGap, y + (badgeSize - FONT_SIZES.heading * 1.25) / 2, label, { role, size: 'heading' });
  ea.addToGroup([badge, numberText, labelBlock.id]);
  return { id: badge, x, y, w: labelBlock.right - x, h: badgeSize, right: labelBlock.right, bottom: y + badgeSize };
};

const formula = async (x, y, tex, { role = 'primary', scale = LATEX_SCALE } = {}) => {
  const coloredTex = role === 'body' ? tex : `\\color{${ROLE_COLORS[role]}}{${tex}}`;
  const id = await ea.addLaTex(x, y, coloredTex);
  const e = ea.getElement(id);
  e.width *= scale;
  e.height *= scale;
  return toBlock(id);
};

const box = (x, y, content, { role = 'primary', width, padding = 14 } = {}) => {
  resetStyle(role);
  ea.style.fontSize = FONT_SIZES.body;
  ea.style.roundness = { type: 3 };
  const label = width ? wrapToWidth(content, width - 2 * padding) : content;
  const id = ea.addText(x + padding, y + padding, label, { box: 'rectangle', boxPadding: padding, textAlign: 'center' });
  const rect = ea.getElement(id);
  if (width && rect.width < width) {
    const boundText = ea.getElement(rect.boundElements[0].id);
    boundText.x += (width - rect.width) / 2;
    rect.width = width;
  }
  return toBlock(id);
};

const panel = (x, y, w, h, role = 'callout') => {
  resetStyle(role);
  ea.style.backgroundColor = ROLE_COLORS[role];
  ea.style.opacity = PANEL_OPACITY;
  ea.style.roundness = { type: 3 };
  const id = ea.addRect(x, y, w, h);
  tagDecoration(id, 'panel');
  sendToBack(id);
  return toBlock(id);
};

// Arrows that share one side of a block fan out, so two arrowheads never meet at one point.
// `base` is the coordinate along the side to start from (default: the side's center).
const sideAttachments = new Map();
const attachPoint = (block, side, base) => {
  const isSmallTarget = block.id && block.w <= SMALL_TARGET_PX && block.h <= SMALL_TARGET_PX;
  const clear = isSmallTarget ? SMALL_TARGET_CLEARANCE_PX : TOKENS.arrowClearance;
  const key = `${block.id}:${side}`;
  const index = block.id ? (sideAttachments.get(key) ?? 0) : 0;
  if (block.id) sideAttachments.set(key, index + 1);
  const isHorizontalSide = side === 'top' || side === 'bottom';
  const sideLength = isHorizontalSide ? block.w : block.h;
  const spread = Math.min(ATTACH_SPREAD_PX * Math.ceil(index / 2), sideLength * 0.4) * (index % 2 ? 1 : -1);
  const alongX = (isHorizontalSide ? (base ?? block.x + block.w / 2) : 0) + (isHorizontalSide ? spread : 0);
  const alongY = (isHorizontalSide ? 0 : (base ?? block.y + block.h / 2)) + (isHorizontalSide ? 0 : spread);
  if (side === 'right') return [block.right + clear, alongY];
  if (side === 'left') return [block.x - clear, alongY];
  if (side === 'bottom') return [alongX, block.bottom + clear];
  return [alongX, block.y - clear];
};

// Midpoint of the range two blocks share on one axis, so aligned blocks get a perfectly
// straight arrow even when their widths differ. Undefined when they barely overlap.
const sharedMidpoint = (startA, endA, startB, endB) => {
  const overlapStart = Math.max(startA, startB);
  const overlapEnd = Math.min(endA, endB);
  return overlapEnd - overlapStart >= MIN_SHARED_SPAN_PX ? (overlapStart + overlapEnd) / 2 : undefined;
};

// Pick the pair of facing sides. Side-by-side blocks use left/right unless the vertical
// gap is much wider, so every branch of a fork leaves from the same side and a steep
// relation still leaves from the side that faces its target.
const nearestSides = (from, to) => {
  const horizontalGap = Math.max(to.x - from.right, from.x - to.right);
  const verticalGap = Math.max(to.y - from.bottom, from.y - to.bottom);
  const prefersHorizontal = horizontalGap > 0 && horizontalGap * HORIZONTAL_SIDE_BIAS >= verticalGap;
  if (prefersHorizontal || horizontalGap >= verticalGap) {
    const sharedY = sharedMidpoint(from.y, from.bottom, to.y, to.bottom);
    return to.x >= from.right ? [attachPoint(from, 'right', sharedY), attachPoint(to, 'left', sharedY)]
                              : [attachPoint(from, 'left', sharedY), attachPoint(to, 'right', sharedY)];
  }
  const sharedX = sharedMidpoint(from.x, from.right, to.x, to.right);
  return to.y >= from.bottom ? [attachPoint(from, 'bottom', sharedX), attachPoint(to, 'top', sharedX)]
                             : [attachPoint(from, 'top', sharedX), attachPoint(to, 'bottom', sharedX)];
};

// Arrow labels are queued and placed by placeArrowLabels() after the whole layout exists,
// so each label can pick the side of its arrow with the fewest neighbors.
const pendingArrowLabels = [];
const labelConnector = (arrowId, start, end, content, role, source) => {
  pendingArrowLabels.push({ arrowId, start, end, content, role, source });
};

const elementBox = (e) => [e.x, e.y, e.x + e.width, e.y + e.height];
const connectorPoints = (e) => e.points.flatMap(([px, py], index, points) => {
  if (index === 0) return [[e.x + px, e.y + py]];
  const [prevX, prevY] = points[index - 1];
  return Array.from({ length: 10 }, (_, step) => [
    e.x + prevX + ((px - prevX) * (step + 1)) / 10, e.y + prevY + ((py - prevY) * (step + 1)) / 10]);
});

const obstaclesInside = (candidate, ignoredIds, margin = 4) => {
  const [left, top, right, bottom] = candidate.map((v, i) => v + (i < 2 ? -margin : margin));
  const isInside = ([px, py]) => px >= left && px <= right && py >= top && py <= bottom;
  return ea.getElements().filter((e) => !ignoredIds.has(e.id)).filter((e) => {
    if (e.type === 'arrow' || e.type === 'line') return connectorPoints(e).some(isInside);
    const [eLeft, eTop, eRight, eBottom] = elementBox(e);
    return eLeft < right && left < eRight && eTop < bottom && top < eBottom;
  }).length;
};

const placeArrowLabels = () => {
  for (const { arrowId, start: [x1, y1], end: [x2, y2], content, role, source } of pendingArrowLabels.splice(0)) {
    resetStyle(role);
    ea.style.fontSize = FONT_SIZES.caption;
    const id = ea.addText(0, 0, content);
    const label = ea.getElement(id);
    const midX = (x1 + x2) / 2;
    const midY = (y1 + y2) / 2;
    const length = Math.hypot(x2 - x1, y2 - y1) || 1;
    const normal = [(y2 - y1) / length, -(x2 - x1) / length];
    const isMostlyHorizontal = Math.abs(x2 - x1) >= Math.abs(y2 - y1) * 2;
    const isMostlyVertical = Math.abs(y2 - y1) >= Math.abs(x2 - x1) * 2;
    const sourceCenterY = source.y + source.h / 2;
    // Preferred side first: above a horizontal arrow, right of a vertical one, and on the
    // outer side of a fan for a diagonal one.
    const prefersFirstNormal = isMostlyHorizontal ? normal[1] < 0
      : isMostlyVertical ? normal[0] > 0
      : Math.sign(normal[1]) === Math.sign(midY - sourceCenterY);
    const sides = prefersFirstNormal ? [normal, normal.map((v) => -v)] : [normal.map((v) => -v), normal];
    // A sibling arrow (same source or target) close to a candidate makes the label
    // ambiguous, so it counts as crowding too.
    const arrowElement = ea.getElement(arrowId);
    const endpointIds = [arrowElement.startBinding?.elementId, arrowElement.endBinding?.elementId].filter(Boolean);
    const siblingArrowIds = ea.getElements()
      .filter((e) => e.type === 'arrow' && e.id !== arrowId)
      .filter((e) => endpointIds.includes(e.startBinding?.elementId) || endpointIds.includes(e.endBinding?.elementId))
      .map((e) => e.id);
    const nonSiblingIds = new Set(ea.getElements().filter((e) => !siblingArrowIds.includes(e.id)).map((e) => e.id));
    const candidates = sides.flatMap(([normalX, normalY]) => LABEL_POSITIONS_ALONG_ARROW.map((along) => {
      const pushOut = Math.abs(normalX) * label.width / 2 + Math.abs(normalY) * label.height / 2 + ARROW_LABEL_OFFSET_PX;
      const x = x1 + (x2 - x1) * along + normalX * pushOut - label.width / 2;
      const y = y1 + (y2 - y1) * along + normalY * pushOut - label.height / 2;
      const labelBox = [x, y, x + label.width, y + label.height];
      const crowding = obstaclesInside(labelBox, new Set([id, arrowId]))
        + obstaclesInside(labelBox, new Set([...nonSiblingIds, id, arrowId]), SIBLING_CLEARANCE_PX);
      return { x, y, crowding };
    }));
    const best = candidates.reduce((winner, candidate) => (candidate.crowding < winner.crowding ? candidate : winner));
    label.x = best.x;
    label.y = best.y;
    ea.addAppendUpdateCustomData(id, { excalidrawRefine: 'arrowLabel', arrowId });
    ea.addToGroup([arrowId, id]);
  }
};

// Straight arrow: same-row / same-column flow, fork, or merge between two blocks.
const arrow = (from, to, { role = 'muted', label } = {}) => {
  resetStyle(role);
  const [start, end] = nearestSides(from, to);
  const id = ea.addArrow([start, end], { startObjectId: from.id, endObjectId: to.id, endArrowHead: 'arrow' });
  if (label) labelConnector(id, start, end, label, role, from);
  return toBlock(id);
};

// Curved arrow for a relation that must bend (across regions, into a chart).
// The curve bows sideways by min(|bend| x length, 80 px): bend > 0 bows left of the travel direction, < 0 right.
// `via: [x, y]` sets the bend point directly. Aligned endpoints fall back to a straight arrow.
const pointer = (from, to, { role = 'primary', bend = 0.2, via, label } = {}) => {
  resetStyle(role);
  const [start, end] = nearestSides(from, to);
  const isAligned = Math.abs(end[0] - start[0]) < ALIGN_TOLERANCE_PX || Math.abs(end[1] - start[1]) < ALIGN_TOLERANCE_PX;
  if (isAligned && !via) {
    const id = ea.addArrow([start, end], { startObjectId: from.id, endObjectId: to.id, endArrowHead: 'arrow' });
    if (label) labelConnector(id, start, end, label, role, from);
    return toBlock(id);
  }
  ea.style.roundness = { type: 2 };
  ea.style.roughness = 0; // a rough curve shows a kink near its ends
  const length = Math.hypot(end[0] - start[0], end[1] - start[1]);
  const bow = Math.sign(bend) * Math.min(Math.abs(bend) * length, MAX_POINTER_BOW_PX);
  const middle = via ?? [(start[0] + end[0]) / 2 - ((end[1] - start[1]) / length) * bow,
                         (start[1] + end[1]) / 2 + ((end[0] - start[0]) / length) * bow];
  const id = ea.addArrow([start, middle, end], { startObjectId: from.id, endObjectId: to.id, endArrowHead: 'arrow' });
  if (label) labelConnector(id, start, end, label, role, from);
  return toBlock(id);
};

// Row of boxes left to right joined by straight arrows. Each item is a label string or
// {label, role, arrowLabel} where arrowLabel names the arrow coming INTO that box.
const flow = (x, y, items, { role = 'primary', gap = 64, width } = {}) => {
  const specs = items.map((item) => (typeof item === 'string' ? { label: item } : item));
  const blocks = [];
  const captionWidth = (content) => {
    ea.style.fontSize = FONT_SIZES.caption;
    return content ? ea.measureText(content).width : 0;
  };
  specs.forEach((spec, index) => {
    const gapFittingLabel = Math.max(gap, captionWidth(spec.arrowLabel) + 2 * TOKENS.blockGap);
    const left = index === 0 ? x : blocks[index - 1].right + gapFittingLabel;
    blocks.push(box(left, y, spec.label, { role: spec.role ?? role, width }));
  });
  blocks.slice(1).forEach((block, index) => arrow(blocks[index], block, { label: specs[index + 1].arrowLabel }));
  return blocks;
};

// Column of boxes top to bottom, no arrows (fork targets, parallel services).
// Items are label strings or {label, role}. Returns the boxes.
const stack = (x, y, items, { role = 'primary', gap = 2 * TOKENS.blockGap, width } = {}) => {
  const blocks = [];
  items.forEach((item) => {
    const spec = typeof item === 'string' ? { label: item } : item;
    const top = blocks.length ? blocks[blocks.length - 1].bottom + gap : y;
    blocks.push(box(x, top, spec.label, { role: spec.role ?? role, width }));
  });
  return blocks;
};

// Vertical center that lines a new block of height `height` up with the middle of blocks a..b.
const middleY = (first, last, height) => first.y + (last.bottom - first.y - height) / 2;

// Reference level (threshold, limit, spec line).
const dashed = (x1, y1, x2, y2, role = 'muted') => {
  resetStyle(role);
  ea.style.strokeStyle = 'dashed';
  ea.style.strokeWidth = 1;
  return toBlock(ea.addLine([[x1, y1], [x2, y2]]));
};

// Filled dot centered on (x, y): a data point or a marker.
const dot = (x, y, { role = 'primary', size = DOT_SIZE_PX } = {}) => {
  resetStyle(role);
  ea.style.backgroundColor = ROLE_COLORS[role] ?? ROLE_COLORS.primary;
  return toBlock(ea.addEllipse(x - size / 2, y - size / 2, size, size));
};

// Extra curve on an existing chart (points are chart-local px, y grows down).
// markers: true puts a dot on every point (use it for sampled data such as control charts).
const curve = (chartBlock, curvePoints, { role = 'primary', smooth = true, markers = false } = {}) => {
  resetStyle(role);
  ea.style.strokeWidth = 2;
  ea.style.roughness = 0;
  if (smooth) ea.style.roundness = { type: 2 };
  const curveId = ea.addLine(curvePoints.map(([px, py]) => [chartBlock.x + px, chartBlock.y + py]));
  const dots = markers ? curvePoints.map(([px, py]) => dot(chartBlock.x + px, chartBlock.y + py, { role }).id) : [];
  ea.addToGroup([chartBlock.id, curveId, ...dots]);
  return { ...chartBlock, curveId };
};

// Minimal chart: L-shaped muted axis + its first curve. Add more curves with kit.curve.
const chart = (x, y, w, h, curvePoints, { role = 'primary', smooth = true, markers = false } = {}) => {
  resetStyle('muted');
  ea.style.strokeWidth = 1;
  const axis = ea.addLine([[x, y], [x, y + h], [x + w, y + h]]);
  return curve({ id: axis, x, y, w, h, right: x + w, bottom: y + h }, curvePoints, { role, smooth, markers });
};

// Plain outline shapes (contours, regions, markers) in a role color.
const ellipse = (x, y, w, h, { role = 'muted' } = {}) => {
  resetStyle(role);
  return toBlock(ea.addEllipse(x, y, w, h));
};
const rect = (x, y, w, h, { role = 'muted' } = {}) => {
  resetStyle(role);
  ea.style.roundness = { type: 3 };
  return toBlock(ea.addRect(x, y, w, h));
};

// A zero-size target so pointer() can aim at a coordinate (a curve peak, a data point).
const spot = (x, y) => ({ id: undefined, x, y, w: 0, h: 0, right: x, bottom: y });

const columnX = (index, columnWidth) => TOKENS.pageMargin + index * (columnWidth + TOKENS.columnGap);

const baseKit = { TOKENS, ROLE_COLORS, FONT_SIZES, text, title, heading, formula, box, panel, highlight,
  arrow, pointer, flow, stack, middleY, dashed, dot, chart, curve, ellipse, rect, spot, columnX, placeArrowLabels, style: resetStyle, sendToBack, toBlock };
