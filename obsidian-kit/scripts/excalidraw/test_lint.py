"""Self-check for lint.py: python3 test_lint.py"""
from lint import lint_elements


def element(element_id, element_type, x, y, width, height, **extra):
    return {"id": element_id, "type": element_type, "x": x, "y": y, "width": width, "height": height,
            "strokeColor": "#1e1e1e", "backgroundColor": "transparent", "fontFamily": 5, **extra}


def arrow(element_id, x, y, points, start=None, end=None):
    return element(element_id, "arrow", x, y, 0, 0, points=points,
                   startBinding={"elementId": start} if start else None,
                   endBinding={"elementId": end} if end else None)


clean_scene = [
    element("panel", "rectangle", 0, 0, 400, 200, backgroundColor="#f08c00"),
    element("title", "text", 20, 20, 150, 30, text="Title"),
    element("boxA", "rectangle", 0, 300, 100, 50),
    element("boxB", "rectangle", 300, 300, 100, 50),
    arrow("link", 110, 325, [[0, 0], [180, 0]], start="boxA", end="boxB"),
]
assert lint_elements(clean_scene)["errors"] == [], lint_elements(clean_scene)

overlapping_texts = [element("t1", "text", 0, 0, 100, 30), element("t2", "text", 50, 10, 100, 30)]
assert any("overlap" in e for e in lint_elements(overlapping_texts)["errors"])

arrow_through_text = [element("t1", "text", 50, -10, 60, 20), arrow("a", 0, 0, [[0, 0], [200, 0]])]
assert any("crosses text" in e for e in lint_elements(arrow_through_text)["errors"])

crossing_arrows = [arrow("a1", 0, 0, [[0, 0], [100, 100]]), arrow("a2", 0, 100, [[0, 0], [100, -100]])]
assert any("arrows cross" in e for e in lint_elements(crossing_arrows)["errors"])

fill_above_text = [element("t", "text", 10, 10, 50, 20), element("band", "rectangle", 0, 0, 100, 40, backgroundColor="#0c8599")]
assert any("layer order" in e for e in lint_elements(fill_above_text)["errors"])

straddling_text = [element("box", "rectangle", 0, 0, 100, 50), element("t", "text", 80, 10, 60, 20)]
assert any("straddles" in e for e in lint_elements(straddling_text)["errors"])

off_palette = [element("t", "text", 0, 0, 10, 10, strokeColor="#ff00ff", fontFamily=1)]
warnings = lint_elements(off_palette)["warnings"]
assert any("off-palette" in w for w in warnings) and any("non-handwritten" in w for w in warnings)

colliding_tips = [arrow("a1", 0, 0, [[0, 0], [100, 0]]), arrow("a2", 100, 100, [[0, 0], [0, -100]])]
assert any("arrowheads collide" in e for e in lint_elements(colliding_tips)["errors"])

own_label = [arrow("a", 0, 0, [[0, 0], [200, 0]]),
             element("lbl", "text", 80, -8, 40, 16, customData={"excalidrawRefine": "arrowLabel", "arrowId": "a"})]
assert any("crosses text" in e for e in lint_elements(own_label)["errors"]), "a label the line runs through is still a crossing"

tiny_arrow = [arrow("a", 0, 0, [[0, 0], [2, 0]])]
assert any("arrow too short" in e for e in lint_elements(tiny_arrow)["errors"])

caption_through_ring = [element("cap", "text", 0, 300, 80, 16),
                        element("ring", "ellipse", -100, -100, 400, 300),
                        arrow("p", 40, 290, [[0, 0], [60, -240]], start="cap")]
caption_errors = lint_elements(caption_through_ring)["errors"]
assert any("caption pointer too long" in e for e in caption_errors)
assert any("caption pointer crosses 1 shape" in e for e in caption_errors)

circle = element("c", "ellipse", 0, 0, 200, 200)
label_on_arc = [circle, element("t", "text", -20, 90, 60, 20)]
assert any("straddles" in e for e in lint_elements(label_on_arc)["errors"])
label_in_corner_outside_arc = [circle, element("t", "text", 2, 2, 30, 16)]
assert not any("straddles" in e for e in lint_elements(label_in_corner_outside_arc)["errors"]), "bbox corner is outside the round arc"
label_inside_circle = [circle, element("t", "text", 80, 90, 40, 20)]
assert not any("straddles" in e for e in lint_elements(label_inside_circle)["errors"])

badge_number = [element("badge", "ellipse", 0, 0, 30, 30, groupIds=["g"]), element("n", "text", 4, 6, 24, 18, groupIds=["g"])]
assert not any("straddles" in e for e in lint_elements(badge_number)["errors"]), "heading badge number is intended"

sequence_message = [dict(arrow("m", 0, 0, [[0, 0], [200, 0]]), customData={"excalidrawRefine": "message"})]
assert not any("bound to nothing" in w for w in lint_elements(sequence_message)["warnings"])

print("lint self-check passed")
