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


NOTE_ID = "x-coredata://A/ICNote/p1"


def run_hook(command, bodies=None):
    """Run the hook on one Bash command. bodies maps note id to HTML; a missing id reads as an error."""
    bodies = {NOTE_ID: "<div>T</div><div>milk</div>"} if bodies is None else bodies

    def fetch_body(note_id):
        return (bodies[note_id], None) if note_id in bodies else (None, "Can't get note id")

    event = json.dumps({"tool_name": "Bash", "tool_input": {"command": command}})
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        code = notes_guard.main(event, fetch_body)
    return code, err.getvalue()


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


class HookTest(unittest.TestCase):
    def test_other_commands_pass(self):
        self.assertEqual(run_hook("ls -la"), (0, ""))
        self.assertEqual(run_hook('notes cat --json "Groceries"'), (0, ""))

    def test_safe_edit_passes(self):
        self.assertEqual(run_hook(f"notes edit --id {NOTE_ID} -m --body 'milk'"), (0, ""))

    def test_lossy_edit_is_blocked_with_features(self):
        bodies = {NOTE_ID: "<div>T</div><ul><li>milk</li></ul>"}
        code, err = run_hook(f"notes edit --id {NOTE_ID} -m --body 'milk'", bodies)
        self.assertEqual(code, 2)
        self.assertIn("lists or checklists", err)
        self.assertIn("Notes app", err)

    def test_edit_without_id_is_blocked(self):
        code, err = run_hook("notes edit Groceries -m --body 'milk'")
        self.assertEqual(code, 2)
        self.assertIn("--id", err)

    def test_force_is_blocked(self):
        code, err = run_hook(f"notes edit --id {NOTE_ID} --force -m --body 'x'")
        self.assertEqual(code, 2)
        self.assertIn("--force", err)

    def test_unreadable_note_is_blocked(self):
        code, err = run_hook("notes edit --id x-coredata://A/ICNote/p9 -m --body 'x'")
        self.assertEqual(code, 2)
        self.assertIn("Can't get note id", err)

    def test_edit_inside_compound_command_is_checked(self):
        bodies = {NOTE_ID: "<table></table>"}
        code, _ = run_hook(f"cd /tmp && notes edit --id={NOTE_ID} -m --body 'x'", bodies)
        self.assertEqual(code, 2)

    def test_unparseable_edit_is_blocked(self):
        code, err = run_hook("notes edit --id 'unclosed")
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
