"""Plan a handover archive: where it goes and what its tags become.

The filename never changes. Status lives in tags, and the 04Archive/<ORG>/
folder says the rest, so renaming would only break wikilinks.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.vault import archive_root  # noqa: E402
from handover.discover import derive_org  # noqa: E402

ARCHIVED_PREFIX = "archived/"
STATE_TAG = "status/archived"


def archive_tags(tags):
    """Wrap every tag, add the one state tag that is never wrapped."""
    wrapped = []
    for tag in tags:
        if tag == STATE_TAG or tag.startswith(ARCHIVED_PREFIX):
            wrapped.append(tag)
        else:
            wrapped.append(ARCHIVED_PREFIX + tag)
    if STATE_TAG not in wrapped:
        wrapped.append(STATE_TAG)
    return wrapped


def plan_archive(vault_relative_path, vault_root, config):
    """Everything the command needs before it touches a file."""
    org = derive_org(vault_relative_path)
    source = Path(vault_relative_path)
    return {
        "source": source,
        "org": org,
        "destination": archive_root(Path(vault_root), config) / org,
        "filename": source.name,
    }
