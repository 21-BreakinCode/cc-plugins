#!/usr/bin/env python3
"""PostToolUse: after a note inside noteFormatFolders is written, remind Claude of format-note."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from common.vault import VaultConfigError, find_vault_root, is_in_scope, load_config  # noqa: E402

REMINDER = ("This edit touched a note inside noteFormatFolders. Apply /obsidian-kit:format-note: "
            "keep its note-type format, take tags only from the taxonomy, and use compact ASCII "
            "diagrams (never Mermaid) for concepts with shape.")

try:
    file_path = Path(json.load(sys.stdin).get("tool_input", {}).get("file_path", ""))
except (json.JSONDecodeError, AttributeError):
    sys.exit(0)
if file_path.suffix != ".md" or not file_path.is_absolute():
    sys.exit(0)
try:
    vault_root = find_vault_root(file_path.parent)
    config = load_config(vault_root)
except VaultConfigError:
    sys.exit(0)
if is_in_scope(file_path.relative_to(vault_root).as_posix(), config):
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": REMINDER}}))
