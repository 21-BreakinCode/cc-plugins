"""Emit provisional labels for receipts/tests/fixtures/labeled.jsonl.

This file is PROVISIONAL until the user labels a real sample by hand (the
brief's Step 3). It does not require human judgment: it only labels ledger
rows the classifier flagged `cheating` whose claim text is structurally not
an assertion at all (a markdown table row, a heading, or an explicitly
hedged `**ASSUME:**` line). For those rows, `truth: "backed"` means "should
not have been flagged" (i.e. the `cheating` verdict was a false positive by
construction) -- not that the claim was substantively backed by tool
evidence. Every other row is skipped; nothing is guessed.

Usage: python3 provisional_labels.py > receipts/tests/fixtures/labeled.jsonl
Reads the same ledger glob as sample_ledger.py.
"""
import json

from sample_ledger import rows


def is_structural_non_claim(claim):
    return claim.startswith("|") or claim.startswith("#") or "**ASSUME:**" in claim


def main():
    seen = set()
    for verdict, claim in rows():
        if claim in seen:
            continue
        seen.add(claim)
        if verdict == "cheating" and is_structural_non_claim(claim):
            print(json.dumps({
                "claim": claim,
                "logged": "cheating",
                "truth": "backed",
                "note": "provisional: structural non-claim",
            }))


if __name__ == "__main__":
    main()
