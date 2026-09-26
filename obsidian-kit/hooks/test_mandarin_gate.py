"""Self-check for gate A: python3 obsidian-kit/hooks/test_mandarin_gate.py"""
import importlib.util
import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent


def run_rules(cwd, env_extra=None):
    env = {"PATH": "/usr/bin:/bin", "CLAUDE_PLUGIN_ROOT": str(HERE.parent)}
    env.update(env_extra or {})
    return subprocess.run(
        ["bash", str(HERE / "mandarin-rules.sh")],
        cwd=cwd, env=env, capture_output=True, text=True,
    ).stdout


with tempfile.TemporaryDirectory() as tmp:
    plain = Path(tmp) / "repo"
    plain.mkdir()
    vault = Path(tmp) / "vault"
    (vault / ".obsidian").mkdir(parents=True)

    assert run_rules(plain) == "", "gate A must stay silent outside a vault"
    assert run_rules(vault) != "", "gate A must emit the rules inside a vault"
    assert run_rules(vault, {"OBSIDIAN_KIT_MANDARIN": "0"}) == "", "the off switch must win"

spec = importlib.util.spec_from_file_location("mandarin_lint", HERE / "mandarin-lint.py")
mandarin_lint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mandarin_lint)

with tempfile.TemporaryDirectory() as tmp:
    plain = Path(tmp) / "repo"
    plain.mkdir()
    vault = Path(tmp) / "vault"
    (vault / ".obsidian").mkdir(parents=True)

    assert mandarin_lint.in_vault(plain) is False, "gate A must be false outside a vault"
    assert mandarin_lint.in_vault(vault) is True, "gate A must be true inside a vault"

    cwd = os.getcwd()
    try:
        os.chdir(plain)
        assert mandarin_lint.main() == 0, "main() must no-op outside a vault"
    finally:
        os.chdir(cwd)

print("mandarin gate: ok")
