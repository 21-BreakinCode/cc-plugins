"""Self-check for common helpers: python3 test_common.py"""
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.obsidian_eval import ObsidianCliError, parse_cli_output  # noqa: E402
from common.note_text import read_property, split_frontmatter  # noqa: E402
from common.vault import (VaultConfigError, find_vault_root, is_excluded,  # noqa: E402
                          is_in_scope, load_config)

CONFIG = {
    "taxonomyPath": "03Resource/About/tag-taxonomy.md",
    "noteFormatFolders": ["03Resource/Zettelkasten", "01Project/Leetcode"],
    "excludedPaths": ["03Resource/Credentials", "04Archive"],
    "typeFolders": {"03Resource/Zettelkasten/Permanent": "concept"},
}

# CLI output: exit code is 0 even on failure, so the text decides.
assert parse_cli_output("1.13.7 (installer 1.13.7)\n") == "1.13.7 (installer 1.13.7)"
try:
    parse_cli_output('Error: File "nope/missing.md" not found.\n')
    raise AssertionError("expected ObsidianCliError")
except ObsidianCliError as cli_error:
    assert "nope/missing.md" in str(cli_error)

# Scope and exclusion use folder boundaries, not string prefixes.
assert is_excluded("03Resource/Credentials/aws.md", CONFIG)
assert not is_excluded("03Resource/CredentialsGuide.md", CONFIG)
assert is_in_scope("03Resource/Zettelkasten/Permanent/a.md", CONFIG)
assert not is_in_scope("02Area/Journal/2026-09-26.md", CONFIG)

# Frontmatter split and property read.
note = "---\nnote-type: concept\ntags: [a]\n---\n#domain/llm\n\n## Title\n"
frontmatter, body = split_frontmatter(note)
assert frontmatter == "---\nnote-type: concept\ntags: [a]\n---\n"
assert body == "#domain/llm\n\n## Title\n"
assert read_property(frontmatter, "note-type") == "concept"
assert read_property(frontmatter, "type") is None
assert split_frontmatter("#tag\nbody") == ("", "#tag\nbody")

# Vault root and config loading.
with tempfile.TemporaryDirectory() as temp:
    vault_root = Path(temp)
    (vault_root / ".obsidian").mkdir()
    (vault_root / "a" / "b").mkdir(parents=True)
    assert find_vault_root(vault_root / "a" / "b") == vault_root
    try:
        load_config(vault_root)
        raise AssertionError("expected VaultConfigError for a missing config")
    except VaultConfigError as missing:
        assert ".obsidian-kit.json" in str(missing)
    (vault_root / ".obsidian-kit.json").write_text(json.dumps({"taxonomyPath": "t.md"}))
    try:
        load_config(vault_root)
        raise AssertionError("expected VaultConfigError for missing keys")
    except VaultConfigError as incomplete:
        assert "noteFormatFolders" in str(incomplete)

# Obsidian closed or CLI missing: one line, exit 1.
closed = subprocess.run(
    [sys.executable, "-c", "from common.vault import require_obsidian_running; require_obsidian_running()"],
    cwd=Path(__file__).resolve().parents[1], env={**os.environ, "PATH": ""}, capture_output=True, text=True,
)
assert closed.returncode == 1
assert closed.stderr.strip() == "Open Obsidian, then run again."

print("test_common: all passed")
