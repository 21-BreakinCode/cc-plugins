"""Score classify() against the user-labeled set.

Usage: python3 receipts/tests/eval.py [path-to-labeled.jsonl]

The labeled rows carry no tool calls, so this scores the no-tools branch of
classify() only. That branch is where the ledger's structural false positives
came from, and it is the branch the scoping change in Task 3 alters.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
from classify import CHEATING, classify  # noqa: E402

DEFAULT = os.path.join(HERE, "fixtures", "labeled.jsonl")


def load(path):
    with open(path, encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]


def main():
    rows = load(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    true_pos = false_pos = false_neg = escalated = 0
    for row in rows:
        result = classify(row["claim"], [])
        # Task 4 changes classify() to return (verdict, evidence). Accept both
        # shapes so this scorer keeps producing real numbers across that change.
        verdict = result[0] if isinstance(result, tuple) else result
        if verdict == "escalate":
            escalated += 1
        flagged = verdict == CHEATING
        truth = row["truth"] == CHEATING
        true_pos += flagged and truth
        false_pos += flagged and not truth
        false_neg += truth and not flagged
    precision = true_pos / (true_pos + false_pos) if true_pos + false_pos else 0.0
    recall = true_pos / (true_pos + false_neg) if true_pos + false_neg else 0.0
    print(f"rows            {len(rows)}")
    print(f"precision       {precision:.3f}")
    print(f"recall          {recall:.3f}")
    print(f"escalation_rate {escalated / len(rows):.3f}" if rows else "escalation_rate n/a")


if __name__ == "__main__":
    main()
