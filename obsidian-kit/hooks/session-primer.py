#!/usr/bin/env python3
"""SessionStart: in an Obsidian vault, prime Claude to use the obsidian CLI as the source of truth."""
import json
import sys
from pathlib import Path

PRIMER = """This project is an Obsidian vault (obsidian-kit).
- The `obsidian` CLI is the source of truth for vault operations. If unsure or a command fails, run `obsidian help <cmd>`.
- It exits 0 even on failure: read the output for `Error:`.
- read: read, search, search:context, outline, links, backlinks, tags, properties
- write: create, append, prepend, property:set, property:remove
- organize: move, rename, delete (delete moves to trash; wikilinks auto-update)
- recover: history, history:read, history:restore, sync:history, sync:restore, diff
- inspect: orphans, deadends, unresolved, vault, file, wordcount
- develop: eval, dev:screenshot, dev:errors, dev:console, plugin:reload
- Before a bulk write, list the files you will change. Undo is `obsidian history:restore`.
- For a web page, prefer `defuddle parse <url> --md` over WebFetch (install: npm install -g defuddle)."""

try:
    working_directory = Path(json.load(sys.stdin).get("cwd", "."))
except (json.JSONDecodeError, AttributeError):
    sys.exit(0)

if (working_directory / ".obsidian").is_dir():
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": PRIMER}}))
