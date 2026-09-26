"""Self-check for handover discovery: python3 test_discover.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from handover.discover import OrgUnresolved, derive_org, live_handovers  # noqa: E402

FAKE = {
    "tag:#type/handover -tag:#status/archived": [
        "01Project/Appier/Services/cs-domain/handover/cs-domain__2026-09-21-x.md",
        "01Project/BustDice/Services/bust-lobby/handover/bust-lobby__2026-09-25-y.md",
    ],
}

assert live_handovers(search=lambda q: FAKE[q]) == FAKE["tag:#type/handover -tag:#status/archived"]

assert derive_org("01Project/Appier/Services/cs-domain/handover/a.md") == "Appier"
assert derive_org("01Project/BustDice/Services/bust-lobby/handover/b.md") == "BustDice"

for bad in ("02Area/Journal/2026-09-26.md", "handover/loose.md", ""):
    try:
        derive_org(bad)
        raise AssertionError(f"expected OrgUnresolved for {bad!r}")
    except OrgUnresolved:
        pass

print("handover discovery: ok")
