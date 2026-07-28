#!/usr/bin/env bash
# Deterministic prefilter eval for autoresearch.
#
# Scores lib/classify.py against the labeled fixtures. No live LLM — fast,
# repeatable, free. Higher is better (0-100).
#
# Weighting reflects a hard-gate blocker's real costs:
#   false-backed   (a bluff slips through)  and
#   false-cheating (a legit claim is blocked) hurt most (cost 5);
#   over/under-escalate is only a wasted judge call (cost 1);
#   escalate is the safe hedge for genuinely ambiguous claims.
#
# Prints:  claims: N / penalty: P / score: NN.N   (misses go to stderr)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RECEIPTS_HERE="${here}" python3 - <<'PY'
import os, sys, json, glob

here = os.environ["RECEIPTS_HERE"]
sys.path.insert(0, os.path.join(here, "..", "lib"))
import classify as C  # noqa: E402

COST = {
    ("backed", "backed"): 0,   ("backed", "escalate"): 1,   ("backed", "cheating"): 5,
    ("cheating", "cheating"): 0, ("cheating", "escalate"): 1, ("cheating", "backed"): 5,
    ("escalate", "escalate"): 0, ("escalate", "backed"): 5,  ("escalate", "cheating"): 5,
}
MAX_PER_CLAIM = 5

total, n, misses = 0, 0, []
for path in sorted(glob.glob(os.path.join(here, "fixtures", "*.json"))):
    fx = json.load(open(path, encoding="utf-8"))
    tools = fx.get("tools", [])
    for claim in fx.get("claims", []):
        gold = claim["gold"]
        pred = C.classify(claim["text"], tools)
        cost = COST[(gold, pred)]
        total += cost
        n += 1
        if cost:
            misses.append((os.path.basename(path), gold, pred, claim["text"][:64]))

score = 100.0 * (1 - total / (MAX_PER_CLAIM * n)) if n else 0.0
for m in misses:
    print(f"  MISS {m[0]}: gold={m[1]} pred={m[2]} :: {m[3]}", file=sys.stderr)
print(f"claims: {n}")
print(f"penalty: {total}")
print(f"score: {score:.1f}")
PY
