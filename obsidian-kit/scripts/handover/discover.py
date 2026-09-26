"""Find live handover notes through the Obsidian tag index.

Discovery goes through the CLI, not a grep. A grep for the YAML list form
misses a note tagged inline in its body, and the vault holds such notes.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.obsidian_eval import run_cli  # noqa: E402

LIVE_QUERY = "tag:#type/handover -tag:#status/archived"
PROJECT_ROOT = "01Project"


class OrgUnresolved(RuntimeError):
    """The note is not under 01Project/<ORG>/, so ORG cannot be derived."""


def run_search(query):
    # run_cli is positional-only and takes "key=value" strings.
    # See obsidian-kit/scripts/common/obsidian_eval.py and notes/migrate.py.
    raw = run_cli("search", f"query={query}", "format=json")
    return json.loads(raw)


def live_handovers(search=run_search):
    """Vault-relative paths of handovers that are neither archived nor stale-marked."""
    return search(LIVE_QUERY)


def derive_org(vault_relative_path):
    """The path segment immediately after 01Project/. Never guessed."""
    parts = Path(vault_relative_path).parts
    if len(parts) < 2 or parts[0] != PROJECT_ROOT:
        raise OrgUnresolved(
            f"{vault_relative_path} is not under {PROJECT_ROOT}/<ORG>/. "
            "Ask the user which ORG folder to archive it under."
        )
    return parts[1]
