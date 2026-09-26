"""Score the full pipeline (extraction then classification) against the
user-labeled set.

Usage: python3 receipts/tests/eval.py [path-to-labeled.jsonl]

Each labeled claim runs through extract_claims() first, then classify(). A
row counts as flagged only if extraction still keeps it as a claim AND
classify() returns cheating. A change to either stage moves these numbers.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
from check import extract_claims  # noqa: E402
from classify import CHEATING, classify  # noqa: E402

DEFAULT = os.path.join(HERE, "fixtures", "labeled.jsonl")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def _survives_extraction(text):
    """Does the claim still register as a claim at all?

    Task 3 changes extract_claims from one argument to two. Accept both so this
    scorer keeps producing real numbers across that change.
    """
    try:
        kept = extract_claims(text, text)
    except TypeError:
        kept = extract_claims(text)
    return bool(kept)


def main():
    rows = load(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    true_pos = false_pos = false_neg = escalated = dropped_at_extraction = 0
    for row in rows:
        extracted = _survives_extraction(row["claim"])
        if not extracted:
            dropped_at_extraction += 1
        result = classify(row["claim"], [])
        # Task 4 changes classify() to return (verdict, evidence). Accept both
        # shapes so this scorer keeps producing real numbers across that change.
        verdict = result[0] if isinstance(result, tuple) else result
        if verdict == "escalate":
            escalated += 1
        flagged = extracted and verdict == CHEATING
        truth = row["truth"] == CHEATING
        true_pos += flagged and truth
        false_pos += flagged and not truth
        false_neg += truth and not flagged
    precision = true_pos / (true_pos + false_pos) if true_pos + false_pos else 0.0
    recall = true_pos / (true_pos + false_neg) if true_pos + false_neg else 0.0
    print(f"rows                  {len(rows)}")
    print(f"precision             {precision:.3f}")
    print(f"recall                {recall:.3f}")
    print(f"escalation_rate       {escalated / len(rows):.3f}" if rows else "escalation_rate n/a")
    print(f"dropped_at_extraction {dropped_at_extraction}")


if __name__ == "__main__":
    main()
