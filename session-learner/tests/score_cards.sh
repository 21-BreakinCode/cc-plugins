#!/usr/bin/env bash
# Objective per-card conformance scorer for session-learner's pick-up cards.
#
# Usage: bash score_cards.sh [CARDS_DIR]
#   CARDS_DIR holds one-card-per-file markdown (default: fixtures/golden-cards).
# Emits `metric: value` lines (objective_score, hard_violations, num_cards, a
# per-rule tally, and a per-card breakdown). See README.md for the workflow.
#
# Checks the MECHANICAL per-card requirements only (the LLM judge handles
# "one concept", "atomic/reusable", and whether the sources are REAL/relevant):
#   R1  card is <= 50 lines              (hard requirement)
#   R2  card has >= 1 tag line (#domain/..., a single '#', not a '##' header)
#   R3  card has >= 2 [[wiki-links]]
#   R4  card has a "From this session:" line
#   R5  Sources line lists <= 3 URLs     (ceiling)
#   R6  Sources line lists >= 1 URL      (floor — cards must cite sources)
#
# objective_score = 10 * (passed checks) / (6 * num_cards)   [0..10, higher better]
# hard_violations = number of cards exceeding 50 lines        [lower better, target 0]
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
CARDS_DIR="${1:-${SCRIPT_DIR}/fixtures/golden-cards}"

python3 - "$CARDS_DIR" <<'PY'
import sys, glob, os, re

cards_dir = sys.argv[1]
files = sorted(glob.glob(os.path.join(cards_dir, "*.md")))
n = len(files)

if n == 0:
    print("objective_score: 0")
    print("hard_violations: 0")
    print("num_cards: 0")
    print("ERROR: no card files found in %s" % cards_dir)
    sys.exit(0)

rules = ["r1_le50", "r2_tag", "r3_links", "r4_session", "r5_le3_src", "r6_ge1_src"]
passes = {r: 0 for r in rules}
hard_violations = 0
details = []

for f in files:
    text = open(f, encoding="utf-8").read()
    lines = text.splitlines()
    nlines = len(lines)

    r1 = nlines <= 50
    if not r1:
        hard_violations += 1
    r2 = any(re.match(r'^#[^#\s]', ln) for ln in lines)
    r3 = len(re.findall(r'\[\[[^\]]+\]\]', text)) >= 2
    r4 = 'from this session:' in text.lower()
    src = [ln for ln in lines if ln.lower().startswith('sources:')]
    nurls = len(re.findall(r'https?://', src[0])) if src else 0
    r5 = nurls <= 3
    r6 = nurls >= 1

    for r, ok in zip(rules, [r1, r2, r3, r4, r5, r6]):
        if ok:
            passes[r] += 1
    details.append((os.path.basename(f), nlines, nurls, r1, r2, r3, r4, r5, r6))

total_possible = n * len(rules)
total_pass = sum(passes.values())
objective = round(10.0 * total_pass / total_possible, 2)

print("objective_score: %s" % objective)
print("hard_violations: %d" % hard_violations)
print("num_cards: %d" % n)
for r in rules:
    print("%s: %d/%d" % (r, passes[r], n))
print("--- per-card ---")
for name, nl, nu, a, b, c, d, e, g in details:
    print("%-14s lines=%-3d urls=%d R1=%d R2=%d R3=%d R4=%d R5=%d R6=%d"
          % (name, nl, nu, int(a), int(b), int(c), int(d), int(e), int(g)))
PY
