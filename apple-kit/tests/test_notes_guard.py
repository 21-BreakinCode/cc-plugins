"""Tests for apple-kit/scripts/notes_guard.py. Run: python3 -B -m unittest discover -s apple-kit/tests -v"""

import contextlib
import importlib.util
import io
import json
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "notes_guard.py"
spec = importlib.util.spec_from_file_location("notes_guard", SCRIPT)
assert spec is not None and spec.loader is not None, SCRIPT
notes_guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(notes_guard)


def cat_json(body, note_id="x-coredata://A/ICNote/p1"):
    return json.dumps([{"account": "iCloud", "id": note_id, "name": "Groceries", "body": body}])


def run(stdin_text, note_id="x-coredata://A/ICNote/p1"):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = notes_guard.main(["--id", note_id], stdin_text)
    return code, out.getvalue()


class LossyFeaturesTest(unittest.TestCase):
    def test_plain_text_note_is_safe(self):
        body = "<div><h1>Groceries</h1></div><div>milk</div><div><b>eggs</b></div>"
        self.assertEqual(notes_guard.lossy_features(body), [])

    def test_list_counts_as_possible_checklist(self):
        body = "<div>Groceries</div><ul><li>milk</li></ul>"
        self.assertEqual(notes_guard.lossy_features(body), ["lists or checklists"])

    def test_each_rich_feature_is_named(self):
        body = ('<div>T</div><table><tr><td>1</td></tr></table><img src="x">'
                '<u>under</u><s>gone</s><font color="red">red</font>'
                '<span style="color: red">c</span><div>buy #errand</div>')
        self.assertEqual(notes_guard.lossy_features(body), [
            "tables", "images or attachments", "underline or strikethrough",
            "fonts or colors", "tags"])

    def test_heading_anchor_hash_is_not_a_tag(self):
        self.assertEqual(notes_guard.lossy_features('<div>issue # 5 and C#</div>'), [])


class MainTest(unittest.TestCase):
    def test_safe_note_exits_0_silent(self):
        self.assertEqual(run(cat_json("<div>T</div><div>milk</div>")), (0, ""))

    def test_lossy_note_exits_2_and_lists_features(self):
        code, out = run(cat_json("<div>T</div><ul><li>milk</li></ul>"))
        self.assertEqual(code, 2)
        self.assertIn("lists or checklists", out)

    def test_unknown_id_exits_3(self):
        code, out = run(cat_json("<div>T</div>", note_id="other"))
        self.assertEqual(code, 3)
        self.assertIn("not found", out)


if __name__ == "__main__":
    unittest.main()
