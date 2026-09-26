// excalidraw-refine diagram helpers, loaded after style_kit.js by build.py:
// labels beside a target, dot paths, sequence diagrams, and Venn diagrams.
const LABEL_SIDES = ['right', 'above', 'left', 'below'];
const SEQUENCE_MIN_SPACING_PX = 200;
const SEQUENCE_MAX_BOX_WIDTH_PX = 180;
const SEQUENCE_TIP_GAP_PX = 6;
const VENN_RADIUS_PX = 190;
const VENN_SET_ROLES = ['primary', 'secondary', 'callout'];

// Labels beside a target are queued and placed after the layout exists, on the first
// side (in `sides` order) with the fewest neighbors.
const pendingTargetLabels = [];
const label = (target, content, { role = 'body', size = 'caption', sides = LABEL_SIDES, gap = TOKENS.lineGap } = {}) => {
  pendingTargetLabels.push({ target, content, role, size, sides, gap });
};

const positionBeside = (target, side, width, height, gap) => {
  const centerX = target.x + target.w / 2;
  const centerY = target.y + target.h / 2;
  if (side === 'right') return [target.right + gap, centerY - height / 2];
  if (side === 'left') return [target.x - gap - width, centerY - height / 2];
  if (side === 'above') return [centerX - width / 2, target.y - gap - height];
  return [centerX - width / 2, target.bottom + gap];
};

const placeTargetLabels = () => {
  for (const { target, content, role, size, sides, gap } of pendingTargetLabels.splice(0)) {
    resetStyle(role);
    ea.style.fontSize = FONT_SIZES[size] ?? size;
    const id = ea.addText(0, 0, content);
    const labelElement = ea.getElement(id);
    const ignoredIds = new Set([id, target.id].filter(Boolean));
    const candidates = sides.map((side) => {
      const [x, y] = positionBeside(target, side, labelElement.width, labelElement.height, gap);
      return { x, y, crowding: obstaclesInside([x, y, x + labelElement.width, y + labelElement.height], ignoredIds) };
    });
    const best = candidates.reduce((winner, candidate) => (candidate.crowding < winner.crowding ? candidate : winner));
    labelElement.x = best.x;
    labelElement.y = best.y;
  }
};

const placeLabels = () => {
  placeArrowLabels();
  placeTargetLabels();
};

// Chain of dots joined by short straight arrows (optimizer steps, a walk, a trajectory).
// Keep neighboring points 48 px or more apart so each arrow shows its tip.
const path = (points, { role = 'primary' } = {}) => {
  const dots = points.map(([x, y]) => dot(x, y, { role }));
  dots.slice(1).forEach((target, index) => arrow(dots[index], target, { role }));
  return dots;
};

// Text centered on (x, y) in both directions, wrapped to `width`.
const centeredText = (x, y, content, options) => {
  const block = text(x, y, content, { ...options, anchor: 'center' });
  ea.getElement(block.id).y -= block.h / 2;
  return toBlock(block.id);
};

// Sequence diagram: actor boxes on top, dashed lifelines, one labeled message per row.
// actors: names or {label, role}. messages: {from, to, label, role}, from/to are actor names.
const sequence = (x, y, actors, messages, { rowGap = 64, role = 'primary' } = {}) => {
  const actorSpecs = actors.map((actor) => (typeof actor === 'string' ? { label: actor } : actor));
  resetStyle('body');
  ea.style.fontSize = FONT_SIZES.caption;
  const widestMessage = Math.max(0, ...messages.map((message) => ea.measureText(message.label).width));
  const spacing = Math.max(SEQUENCE_MIN_SPACING_PX, widestMessage + 2 * TOKENS.blockGap);
  const boxWidth = Math.min(spacing - 2 * TOKENS.blockGap, SEQUENCE_MAX_BOX_WIDTH_PX);
  const actorBoxes = actorSpecs.map((spec, index) =>
    box(x + index * spacing, y, spec.label, { role: spec.role ?? role, width: boxWidth }));
  const lifelineXs = actorBoxes.map((actorBox) => actorBox.x + actorBox.w / 2);
  const actorIndex = Object.fromEntries(actorSpecs.map((spec, index) => [spec.label, index]));
  const firstRowY = Math.max(...actorBoxes.map((actorBox) => actorBox.bottom)) + TOKENS.blockGap + rowGap / 2;
  const lastRowY = firstRowY + (messages.length - 1) * rowGap;
  actorBoxes.forEach((actorBox, index) =>
    dashed(lifelineXs[index], actorBox.bottom + TOKENS.lineGap, lifelineXs[index], lastRowY + TOKENS.blockGap));

  const rows = messages.map((message, row) => {
    const rowY = firstRowY + row * rowGap;
    const fromX = lifelineXs[actorIndex[message.from]];
    const toX = lifelineXs[actorIndex[message.to]];
    if (fromX === undefined || toX === undefined) throw new Error(`unknown actor in message: ${message.from} -> ${message.to}`);
    const direction = Math.sign(toX - fromX);
    resetStyle(message.role ?? 'muted');
    const arrowId = ea.addArrow([[fromX + direction * SEQUENCE_TIP_GAP_PX, rowY], [toX - direction * SEQUENCE_TIP_GAP_PX, rowY]], { endArrowHead: 'arrow' });
    ea.addAppendUpdateCustomData(arrowId, { excalidrawRefine: 'message' });
    const messageLabel = text(Math.min(fromX, toX) + TOKENS.lineGap, rowY, message.label, { role: message.role ?? 'body', size: 'caption' });
    ea.getElement(messageLabel.id).y = rowY - messageLabel.h - ARROW_LABEL_OFFSET_PX;
    return { arrowId, y: rowY };
  });
  return { actors: actorBoxes, rows, bottom: lastRowY + TOKENS.blockGap, right: actorBoxes[actorBoxes.length - 1].right };
};

// Venn diagram for 2 or 3 sets around (centerX, centerY).
// sets: [{label, role}]. overlaps: keys '0+1', '0+2', '1+2', '0+1+2' -> label text.
// Set names sit outside the circles. Overlap labels sit at the middle of each lens.
const venn = (centerX, centerY, sets, overlaps = {}, { radius = VENN_RADIUS_PX } = {}) => {
  if (sets.length !== 2 && sets.length !== 3) throw new Error('kit.venn draws 2 or 3 sets');
  const centerDistance = radius;
  const triangleHeight = (centerDistance * Math.sqrt(3)) / 2;
  const centers = sets.length === 2
    ? [[centerX - centerDistance / 2, centerY], [centerX + centerDistance / 2, centerY]]
    : [[centerX - centerDistance / 2, centerY - triangleHeight / 3],
       [centerX + centerDistance / 2, centerY - triangleHeight / 3],
       [centerX, centerY + (2 * triangleHeight) / 3]];
  const circles = centers.map(([circleX, circleY], index) =>
    ellipse(circleX - radius, circleY - radius, 2 * radius, 2 * radius, { role: sets[index].role ?? VENN_SET_ROLES[index] }));

  centers.forEach(([circleX, circleY], index) => {
    const isBottomSet = sets.length === 3 && index === 2;
    const outward = isBottomSet ? 0 : (circleX < centerX ? -1 : 1) * radius * 0.3;
    const role = sets[index].role ?? VENN_SET_ROLES[index];
    const nameBlock = text(circleX + outward, 0, sets[index].label, { role, size: 'heading', anchor: 'center' });
    ea.getElement(nameBlock.id).y = isBottomSet ? circleY + radius + TOKENS.lineGap : circleY - radius - TOKENS.lineGap - nameBlock.h;
  });

  const lensWidth = radius * 0.55;
  const midpoint = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  const pairLensCenter = (first, second) => {
    const middle = midpoint(centers[first], centers[second]);
    if (sets.length === 2) return middle;
    const third = centers[3 - first - second];
    const awayX = middle[0] - third[0];
    const awayY = middle[1] - third[1];
    const awayLength = Math.hypot(awayX, awayY);
    const nearEdge = radius - triangleHeight;
    const farEdge = Math.sqrt(radius ** 2 - (centerDistance / 2) ** 2);
    const along = (nearEdge + farEdge) / 2;
    return [middle[0] + (awayX / awayLength) * along, middle[1] + (awayY / awayLength) * along];
  };
  const centroid = [centers.reduce((sum, c) => sum + c[0], 0) / centers.length,
                    centers.reduce((sum, c) => sum + c[1], 0) / centers.length];
  Object.entries(overlaps).forEach(([key, content]) => {
    const members = key.split('+').map(Number);
    const [labelX, labelY] = members.length === 3 ? centroid : pairLensCenter(members[0], members[1]);
    centeredText(labelX, labelY, content, { size: 'caption', width: lensWidth });
  });
  return { circles, centers };
};

const kit = { ...baseKit, label, path, sequence, venn, centeredText, placeLabels };
