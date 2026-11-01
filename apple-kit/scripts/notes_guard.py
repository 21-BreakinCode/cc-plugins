#!/usr/bin/env python3
"""PreToolUse hook: block a `notes edit` that would lose content.

`notes edit --body` rewrites the whole body from Markdown. Without Full Disk
Access, macnotesapp can only detect attachments, so this hook reads the
note's HTML by id and names every rich feature that a Markdown round trip
can drop. Claude Code runs hooks outside the Bash sandbox, so the hook can
reach Notes while the edit command itself waits.

Input: the hook event JSON on stdin. Exit 0: allow. Exit 2: block, with the
reason on stderr.
"""

import json
import re
import shlex
import subprocess
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


NOTES_EDIT = re.compile(r"(?:^|[;&|(\s])notes\s+edit\b")
READ_BODY_SCRIPT = ('on run argv\n'
                    'tell application "Notes" to get body of note id (item 1 of argv)\n'
                    'end run')


def fetch_body(note_id: str) -> tuple[str | None, str | None]:
    """Return (html, None), or (None, error text) when Notes cannot read the note."""
    try:
        done = subprocess.run(["osascript", "-e", READ_BODY_SCRIPT, note_id],
                              capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired) as error:
        return None, type(error).__name__
    if done.returncode != 0:
        return None, done.stderr.strip()
    return done.stdout, None


def edit_note_id(tokens: list[str]) -> str | None:
    for index, token in enumerate(tokens):
        if token.startswith("--id="):
            return token.removeprefix("--id=")
        if token == "--id" and index + 1 < len(tokens):
            return tokens[index + 1]
    return None


def block_reason(command: str, fetch=fetch_body) -> str | None:
    match = NOTES_EDIT.search(command)
    if match is None:
        return None
    try:
        tokens = shlex.split(command[match.start():])
    except ValueError as error:
        return f"cannot parse the notes edit command ({error})"
    if "--force" in tokens:
        return "--force is not allowed: it drops content"
    note_id = edit_note_id(tokens)
    if note_id is None:
        return "select the note with --id"
    html, error = fetch(note_id)
    if html is None:
        return f"cannot read note {note_id}: {error}"
    features = lossy_features(html)
    if features:
        return "this edit would lose: " + ", ".join(features) + ". Edit this note in the Notes app"
    return None


def main(event_text: str | None = None, fetch=fetch_body) -> int:
    event = json.loads(sys.stdin.read() if event_text is None else event_text)
    reason = block_reason(event.get("tool_input", {}).get("command", ""), fetch)
    if reason is None:
        return 0
    print(f"apple-kit notes guard: {reason}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
