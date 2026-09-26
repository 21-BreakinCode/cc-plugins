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

    # M1: invalid JSON raises VaultConfigError instead of json.JSONDecodeError.
    (vault_root / ".obsidian-kit.json").write_text("{bad")
    try:
        load_config(vault_root)
        raise AssertionError("expected VaultConfigError for invalid JSON")
    except VaultConfigError as bad_json:
        assert "not valid JSON" in str(bad_json)

# Obsidian closed or CLI missing: one line, exit 1.
closed = subprocess.run(
    [sys.executable, "-c", "from common.vault import require_obsidian_running; require_obsidian_running()"],
    cwd=Path(__file__).resolve().parents[1], env={**os.environ, "PATH": ""}, capture_output=True, text=True,
)
assert closed.returncode == 1
assert closed.stderr.strip() == "Open Obsidian, then run again."

from common.vault import archive_root, resolve_via_handover  # noqa: E402

with tempfile.TemporaryDirectory() as tmp:
    root = Path(tmp).resolve()
    vault = root / "LifeOS"
    (vault / ".obsidian").mkdir(parents=True)
    service = vault / "01Project" / "Appier" / "Services" / "cs-domain" / "handover"
    service.mkdir(parents=True)
    repo = root / "repo"
    repo.mkdir()

    # no symlink at all
    try:
        resolve_via_handover(repo)
        raise AssertionError("expected VaultConfigError for a missing symlink")
    except VaultConfigError as error:
        assert "handover-init-service" in str(error), str(error)

    # a symlink that resolves
    (repo / "handover").symlink_to(service)
    assert resolve_via_handover(repo) == vault

    # a symlink whose target is gone
    dead_repo = root / "dead"
    dead_repo.mkdir()
    (dead_repo / "handover").symlink_to(root / "gone" / "handover")
    try:
        resolve_via_handover(dead_repo)
        raise AssertionError("expected VaultConfigError for a dangling symlink")
    except VaultConfigError as error:
        assert "gone" in str(error), str(error)

    # archive root falls back when the key is absent
    assert archive_root(vault, CONFIG) == vault / "04Archive"
    assert archive_root(vault, {**CONFIG, "handoverArchiveRoot": "09Old"}) == vault / "09Old"

print("vault gate B: ok")

print("test_common: all passed")
