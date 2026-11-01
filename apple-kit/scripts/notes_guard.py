#!/usr/bin/env python3
"""Check whether replacing an Apple Note's body would lose content.

`notes edit --body` rewrites the whole body from Markdown. Without Full Disk
Access, macnotesapp can only detect attachments, so this guard reads the
note's HTML from `notes cat --json` and names every rich feature that a
Markdown round trip can drop.

Usage: notes cat --json "TITLE" | notes_guard.py --id NOTE_ID
Exit 0: safe to edit (prints nothing). Exit 2: lossy (prints the features).
Exit 3: no note with that id in the input.
"""

import argparse
import json
import re
import sys

# (feature name, pattern in the note's HTML). Lists count because Notes
# checklists cannot be told apart from plain lists in the scripted HTML.
LOSSY_PATTERNS = (
    ("lists or checklists", r"<(ul|ol|li)\b"),
    ("tables", r"<table\b"),
    ("images or attachments", r"<(img|object|attachment)\b"),
    ("underline or strikethrough", r"<(u|s|strike)>"),
    ("fonts or colors", r"<font\b|style=\"[^\"]*(color|font|background)"),
    ("tags", r"(?:^|[\s>])#[^\s#<>]*[A-Za-z][^\s#<>]*"),
)


def lossy_features(html: str) -> list[str]:
    return [name for name, pattern in LOSSY_PATTERNS
            if re.search(pattern, html, flags=re.IGNORECASE)]


def main(argv: list[str] | None = None, stdin_text: str | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check an Apple Note for content an edit would lose.")
    parser.add_argument("--id", required=True, dest="note_id")
    args = parser.parse_args(argv)
    notes = json.loads(sys.stdin.read() if stdin_text is None else stdin_text)
    note = next((n for n in notes if n.get("id") == args.note_id), None)
    if note is None:
        print(f"notes_guard: note {args.note_id} not found in the input")
        return 3
    features = lossy_features(note.get("body", ""))
    if features:
        print("notes_guard: an edit would lose: " + ", ".join(features))
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
