"""Self-check for archive planning: python3 test_archive.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from handover.archive import archive_tags, plan_archive  # noqa: E402
from handover.discover import OrgUnresolved  # noqa: E402

CONFIG = {"taxonomyPath": "x", "noteFormatFolders": [], "excludedPaths": [], "typeFolders": {}}

# every tag is wrapped, status/archived is added unprefixed
assert archive_tags(["type/handover", "project/appier/cs-domain"]) == [
    "archived/type/handover", "archived/project/appier/cs-domain", "status/archived",
]

# a note already carrying status/archived is not double-prefixed, and the
# state tag stays unwrapped
assert archive_tags(["type/handover", "status/archived"]) == [
    "archived/type/handover", "status/archived",
]

# an already-archived tag is left alone
assert archive_tags(["archived/type/handover", "status/archived"]) == [
    "archived/type/handover", "status/archived",
]

plan = plan_archive(
    "01Project/Appier/Services/cs-domain/handover/cs-domain__2026-09-21-x.md",
    Path("/vault"), CONFIG,
)
assert plan["org"] == "Appier", plan
assert plan["destination"] == Path("/vault/04Archive/Appier"), plan
assert plan["filename"] == "cs-domain__2026-09-21-x.md", plan

try:
    plan_archive("02Area/Journal/2026-09-26.md", Path("/vault"), CONFIG)
    raise AssertionError("expected OrgUnresolved")
except OrgUnresolved:
    pass

print("handover archive: ok")
