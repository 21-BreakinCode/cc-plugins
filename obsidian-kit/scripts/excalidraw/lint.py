"""Deterministic layout lint for Excalidraw drawings (obsidian-kit create-excali and update-excali).

Usage: python3 lint.py <vault-relative .excalidraw.md> [--json]
Exit 0 = clean or warnings only, 2 = errors (hook feeds them back to Claude), 1 = could not run.
"""
import argparse
import json
import sys
from itertools import combinations
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ea_bridge import ObsidianBridgeError, run_ea_script  # noqa: E402

PALETTE = {"#1e1e1e", "#0c8599", "#6741d9", "#e03131", "#f08c00", "#868e96", "transparent"}
HANDWRITTEN_FONT_EXCALIFONT = 5
MIN_BLOCK_GAP_PX = 10
ARROWHEAD_COLLISION_PX = 10
MIN_ARROW_LENGTH_PX = 24
MAX_CAPTION_POINTER_PX = 160
SHAPE_TYPES = {"rectangle", "ellipse", "diamond"}
BLOCK_TYPES = {"text", "image"}
CONNECTOR_TYPES = {"arrow", "line"}

LOAD_SCENE_JS = """
const file = app.vault.getAbstractFileByPath(args.drawingPath);
if (!file) throw new Error('drawing not found: ' + args.drawingPath);
const scene = await ea.getSceneFromFile(file);
return scene.elements.filter(e => !e.isDeleted);
"""


def box(element):
    return (element["x"], element["y"], element["x"] + element["width"], element["y"] + element["height"])


def boxes_intersect(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def box_contains(outer, inner):
    return outer[0] <= inner[0] and outer[1] <= inner[1] and inner[2] <= outer[2] and inner[3] <= outer[3]


def box_gap(a, b):
    horizontal_gap = max(b[0] - a[2], a[0] - b[2], 0)
    vertical_gap = max(b[1] - a[3], a[1] - b[3], 0)
    return max(horizontal_gap, vertical_gap)


def connector_segments(element):
    absolute_points = [(element["x"] + px, element["y"] + py) for px, py in element["points"]]
    return list(zip(absolute_points, absolute_points[1:]))


def segments_cross(p1, p2, q1, q2):
    def orientation(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    d1, d2 = orientation(q1, q2, p1), orientation(q1, q2, p2)
    d3, d4 = orientation(p1, p2, q1), orientation(p1, p2, q2)
    return d1 * d2 < 0 and d3 * d4 < 0


def segment_hits_box(p1, p2, target_box):
    # ponytail: samples 20 points per segment, misses boxes thinner than segment_length/20
    return any(
        target_box[0] <= p1[0] + (p2[0] - p1[0]) * t / 20 <= target_box[2]
        and target_box[1] <= p1[1] + (p2[1] - p1[1]) * t / 20 <= target_box[3]
        for t in range(1, 20)
    )


def decoration_kind(element):
    return (element.get("customData") or {}).get("excalidrawRefine")


def share_group(a, b):
    return bool(set(a.get("groupIds") or []) & set(b.get("groupIds") or []))


def point_inside_shape(point, shape):
    left, top, right, bottom = box(shape)
    if shape["type"] != "ellipse":
        return left <= point[0] <= right and top <= point[1] <= bottom
    center_x, center_y = (left + right) / 2, (top + bottom) / 2
    radius_x, radius_y = max((right - left) / 2, 1), max((bottom - top) / 2, 1)
    return ((point[0] - center_x) / radius_x) ** 2 + ((point[1] - center_y) / radius_y) ** 2 <= 1


def text_box_crosses_ellipse(text_box, shape):
    # The real curve, not the bounding box: the arc crosses the text box when the box
    # perimeter has points both inside and outside, or an arc extreme pokes into the box.
    left, top, right, bottom = text_box
    perimeter = [(left + (right - left) * t / 8, y) for t in range(9) for y in (top, bottom)] + \
                [(x, top + (bottom - top) * t / 8) for t in range(9) for x in (left, right)]
    inside_flags = {point_inside_shape(point, shape) for point in perimeter}
    if len(inside_flags) == 2:
        return True
    e_left, e_top, e_right, e_bottom = box(shape)
    center_x, center_y = (e_left + e_right) / 2, (e_top + e_bottom) / 2
    extremes = [(e_left, center_y), (e_right, center_y), (center_x, e_top), (center_x, e_bottom)]
    return inside_flags == {False} and any(left <= x <= right and top <= y <= bottom for x, y in extremes)


def path_crosses_outline(segments, shape):
    samples = [p1 for p1, _ in segments] + [segments[-1][1]]
    dense = [(p[0] + (q[0] - p[0]) * t / 10, p[1] + (q[1] - p[1]) * t / 10)
             for p, q in zip(samples, samples[1:]) for t in range(11)]
    inside_flags = {point_inside_shape(point, shape) for point in dense}
    return len(inside_flags) == 2


def lint_elements(elements):
    by_id = {e["id"]: e for e in elements}
    errors, warnings = [], []
    free_blocks = [e for e in elements if e["type"] in BLOCK_TYPES and not e.get("containerId")]
    shapes = [e for e in elements if e["type"] in SHAPE_TYPES]
    connectors = [e for e in elements if e["type"] in CONNECTOR_TYPES]
    z_index = {e["id"]: position for position, e in enumerate(elements)}

    def label(e):
        text = (e.get("text") or "").replace("\n", " ")[:20]
        return f"{e['type']}#{e['id'][:6]}" + (f" '{text}'" if text else "")

    for a, b in combinations(free_blocks, 2):
        if boxes_intersect(box(a), box(b)):
            errors.append(f"overlap: {label(a)} and {label(b)}")
        elif box_gap(box(a), box(b)) < MIN_BLOCK_GAP_PX and not share_group(a, b):
            warnings.append(f"tight gap (<{MIN_BLOCK_GAP_PX}px): {label(a)} and {label(b)}")

    for block in free_blocks:
        for shape in shapes:
            if decoration_kind(shape) or not boxes_intersect(box(block), box(shape)):
                continue
            if shape["type"] == "ellipse":
                if not share_group(block, shape) and text_box_crosses_ellipse(box(block), shape):
                    errors.append(f"text straddles shape border: {label(block)} over {label(shape)}")
                continue
            if box_contains(box(shape), box(block)):
                continue
            if box_contains(box(block), box(shape)):
                continue
            errors.append(f"text straddles shape border: {label(block)} over {label(shape)}")
        for shape in shapes:
            is_filled = shape.get("backgroundColor", "transparent") != "transparent"
            if is_filled and boxes_intersect(box(block), box(shape)) and z_index[shape["id"]] > z_index[block["id"]]:
                errors.append(f"layer order: filled {label(shape)} sits above {label(block)}")

    for connector in connectors:
        endpoint_ids = {(connector.get(k) or {}).get("elementId") for k in ("startBinding", "endBinding")}
        for block in free_blocks:
            if block["id"] in endpoint_ids:
                continue
            if any(segment_hits_box(p1, p2, box(block)) for p1, p2 in connector_segments(connector)):
                errors.append(f"{connector['type']} crosses text: {label(connector)} through {label(block)}")
        is_sequence_message = (connector.get("customData") or {}).get("excalidrawRefine") == "message"
        if connector["type"] == "arrow" and endpoint_ids == {None} and not is_sequence_message:
            warnings.append(f"arrow bound to nothing: {label(connector)}")

    arrows = [c for c in connectors if c["type"] == "arrow"]
    free_text_ids = {e["id"] for e in free_blocks if e["type"] == "text"}
    for a in arrows:
        endpoint_ids = {(a.get(k) or {}).get("elementId") for k in ("startBinding", "endBinding")}
        if not endpoint_ids & free_text_ids:
            continue
        path_length = sum(((q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2) ** 0.5 for p, q in connector_segments(a))
        if path_length > MAX_CAPTION_POINTER_PX:
            errors.append(f"caption pointer too long ({path_length:.0f}px > {MAX_CAPTION_POINTER_PX}px), move the caption next to its target: {label(a)}")
        crossed = [s for s in shapes if s["id"] not in endpoint_ids and not decoration_kind(s)
                   and path_crosses_outline(connector_segments(a), s)]
        if crossed:
            errors.append(f"caption pointer crosses {len(crossed)} shape outline(s), move the caption next to its target: {label(a)}")
    for a in arrows:
        path_length = sum(((q[0] - p[0]) ** 2 + (q[1] - p[1]) ** 2) ** 0.5 for p, q in connector_segments(a))
        if path_length < MIN_ARROW_LENGTH_PX:
            errors.append(f"arrow too short ({path_length:.0f}px < {MIN_ARROW_LENGTH_PX}px, tip barely visible): {label(a)}")
    for a, b in combinations(arrows, 2):
        tip_a, tip_b = connector_segments(a)[-1][1], connector_segments(b)[-1][1]
        if abs(tip_a[0] - tip_b[0]) < ARROWHEAD_COLLISION_PX and abs(tip_a[1] - tip_b[1]) < ARROWHEAD_COLLISION_PX:
            errors.append(f"arrowheads collide: {label(a)} and {label(b)} end at the same point")
    for a, b in combinations(arrows, 2):
        if any(segments_cross(p1, p2, q1, q2)
               for p1, p2 in connector_segments(a) for q1, q2 in connector_segments(b)):
            errors.append(f"arrows cross: {label(a)} and {label(b)}")

    for e in elements:
        off_palette = {e.get("strokeColor"), e.get("backgroundColor")} - PALETTE - {None}
        if off_palette and e["type"] != "image":
            warnings.append(f"off-palette color {sorted(off_palette)}: {label(e)}")
        if e["type"] == "text" and e.get("fontFamily") != HANDWRITTEN_FONT_EXCALIFONT:
            warnings.append(f"non-handwritten font {e.get('fontFamily')}: {label(e)}")

    stats = {"elements": len(elements), "blocks": len(free_blocks), "connectors": len(connectors),
             "bound_arrows": sum(1 for a in arrows if a.get("startBinding") or a.get("endBinding")),
             "unknown_container_refs": sum(1 for e in elements if e.get("containerId") and e["containerId"] not in by_id)}
    return {"errors": errors, "warnings": warnings, "stats": stats}


def rubric_lint_checks(report):
    """Checks 1-5 of references/excali-rubric.md; each is True when no matching finding exists."""
    def clean(findings, *markers):
        return not any(marker in finding for finding in findings for marker in markers)
    errors, warnings = report["errors"], report["warnings"]
    return {
        "1_no_overlap": clean(errors, "overlap", "straddles"),
        "2_lines_clear_of_text": clean(errors, "crosses text"),
        "3_lines_do_not_tangle": clean(errors, "arrows cross", "arrowheads collide", "arrow too short", "caption pointer") and clean(warnings, "bound to nothing"),
        "4_layer_order": clean(errors, "layer order"),
        "5_palette_and_font": clean(warnings, "off-palette", "non-handwritten"),
    }


def compact_element(e):
    compact = {"id": e["id"][:6], "type": e["type"], "box": [round(v) for v in box(e)],
               "stroke": e.get("strokeColor"), "fill": e.get("backgroundColor")}
    for key in ("text", "containerId", "link"):
        if e.get(key):
            compact[key] = e[key]
    for key in ("startBinding", "endBinding"):
        if e.get(key):
            compact[key] = (e[key].get("elementId") or "")[:6]
    return compact


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("drawing_path")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--score", action="store_true", help="print rubric checks 1-5 (references/excali-rubric.md) as JSON")
    parser.add_argument("--dump", action="store_true", help="print a compact element list for rewriting the drawing")
    cli = parser.parse_args()

    try:
        elements = run_ea_script(LOAD_SCENE_JS, {"drawingPath": cli.drawing_path})
    except ObsidianBridgeError as bridge_error:
        print(f"excalidraw lint could not run: {bridge_error}", file=sys.stderr)
        return 1

    if cli.dump:
        print(json.dumps([compact_element(e) for e in elements], ensure_ascii=False))
        return 0

    report = lint_elements(elements)
    if cli.score:
        print(json.dumps(rubric_lint_checks(report), ensure_ascii=False, indent=2))
        return 0
    if cli.json:
        print(json.dumps({"file": cli.drawing_path, **report}, ensure_ascii=False, indent=2))
    else:
        for line in report["errors"]:
            print(f"ERROR {line}")
        for line in report["warnings"]:
            print(f"WARN  {line}")
        print(f"stats: {report['stats']}")
    return 2 if report["errors"] else 0


if __name__ == "__main__":
    sys.exit(main())
