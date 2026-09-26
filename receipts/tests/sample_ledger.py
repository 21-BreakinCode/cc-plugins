"""Draw a stratified sample from the real receipts audit ledger.

Usage: python3 sample_ledger.py [n_per_class] > sample.tsv
The ledger rows are TSV: timestamp, verdict, claim.
"""
import collections
import glob
import os
import random
import sys

LEDGER_GLOB = os.path.join(
    os.environ.get("CLAUDE_CONFIG_DIR", os.path.expanduser("~/.claude")),
    "receipts", "*.log",
)
SEED = 20260926


def rows():
    for path in glob.glob(LEDGER_GLOB):
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 3 and parts[1] in ("backed", "cheating"):
                    yield parts[1], parts[2]


def main():
    per_class = int(sys.argv[1]) if len(sys.argv) > 1 else 60
    buckets = collections.defaultdict(list)
    seen = set()
    for verdict, claim in rows():
        if claim in seen:
            continue
        seen.add(claim)
        buckets[verdict].append(claim)
    random.seed(SEED)
    for verdict in sorted(buckets):
        for claim in random.sample(buckets[verdict], min(per_class, len(buckets[verdict]))):
            print(f"{verdict}\t{claim}")


if __name__ == "__main__":
    main()
