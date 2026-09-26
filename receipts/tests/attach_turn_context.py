"""Attach each labeled claim's real turn context to fixtures/labeled.jsonl.

Run this to rebuild the fixture after adding labels, while the transcripts are
still on disk. It adds `turn_text` and `final_text` so the eval scores
extraction the way production sees it, and re-fits each adjudicated row's
stored `tools` to the smallest output cap that still reproduces its verdict.

Usage: python3 receipts/tests/attach_turn_context.py
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "lib"))
sys.path.insert(0, HERE)

from classify import classify  # noqa: E402
import replay_ledger as R  # noqa: E402

FIX = os.path.join(HERE, "fixtures", "labeled.jsonl")
rows = [json.loads(l) for l in open(FIX, encoding="utf-8") if l.strip()]
by_claim = {r["claim"]: r for r in rows}

def shrink(tools, cap):
    return [{"name": t["name"], "input": t["input"], "output": str(t["output"])[:cap]}
            for t in tools]

resolved = 0
seen = set()
for path in R.transcripts_for(R.ledger_session_ids()):
    for turn_text, final_text, tools in R.turns(path):
        for claim, row in by_claim.items():
            if claim in seen or claim not in turn_text:
                continue
            seen.add(claim)
            resolved += 1
            row["turn_text"] = turn_text
            row["final_text"] = final_text
            # Only the adjudicated rows carry tool evidence. They are the ones
            # labelled for what classify() decides. The provisional rows are
            # labelled for what extraction keeps, which needs no tool output,
            # and storing theirs put a single 249 KB turn in the fixture.
            if "tools" not in row:
                continue
            full = classify(claim, tools)[0]
            for cap in (200, 500, 1200, 3000, 8000, 25000, 80000):
                trimmed = shrink(tools, cap)
                if classify(claim, trimmed)[0] == full:
                    row["tools"] = trimmed
                    break
            else:
                row["tools"] = tools

with open(FIX, "w", encoding="utf-8") as fh:
    for row in rows:
        ordered = {k: row[k] for k in ("claim", "logged", "truth", "note") if k in row}
        for k in ("turn_text", "final_text", "tools"):
            if k in row:
                ordered[k] = row[k]
        fh.write(json.dumps(ordered, ensure_ascii=False) + "\n")
print(f"attached turn context to {resolved}/{len(rows)} rows", file=sys.stderr)
