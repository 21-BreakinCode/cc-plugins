---
description: "Show this session's receipts audit ledger — which FACT/completion claims were backed vs flagged unbacked."
allowed-tools: ["Bash"]
---

# /receipts

Print the most recent receipts audit ledger and summarize it.

```bash
base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/receipts"
newest=$(ls -t "$base"/*.log 2>/dev/null | head -1)
if [ -z "${newest:-}" ]; then
  echo "No receipts audit yet."
  echo "Enable the auditor with:  export CLAUDE_RECEIPTS=1"
  exit 0
fi
echo "Ledger: $newest"
echo "--- verdict counts ---"
awk -F'\t' '{c[$2]++} END {for (k in c) printf "%-9s %d\n", k, c[k]}' "$newest"
echo "--- most recent 15 ---"
tail -15 "$newest"
```

Summarize for the user: how many claims were **backed** vs flagged **cheating**,
and list any cheating claims verbatim so they can prove or retract them.
