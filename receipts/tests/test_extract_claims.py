"""Self-check for claim scoping: python3 receipts/tests/test_extract_claims.py"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "lib"))
from check import extract_claims  # noqa: E402

TURN = "\n".join([
    "Let me check the config first.",
    "**FACT:** `config.yaml` sets replicas to 5.",
])
FINAL = "\n".join([
    "| 2 | creative-3d__2026-08-28-x | Archive: done |",
    "### Issue 2 CONFIRMED: bigo_sg",
    "**ASSUME:** the wrapper passes all args through.",
    "All 716 tests pass.",
])

claims = extract_claims(TURN + "\n" + FINAL, FINAL)

assert "All 716 tests pass." in claims, claims
assert "`config.yaml` sets replicas to 5." in claims, claims
for rejected in ("Let me check the config first.",
                 "| 2 | creative-3d__2026-08-28-x | Archive: done |",
                 "### Issue 2 CONFIRMED: bigo_sg"):
    assert rejected not in claims, f"should not be a claim: {rejected}"
assert not any("ASSUME" in c for c in claims), claims

print("claim scoping: ok")
