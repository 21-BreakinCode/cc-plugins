---
description: "Show this session's receipts audit ledger, or set the audit mode: /receipts [block|warn|report|default]."
argument-hint: "[block|warn|report|default]"
allowed-tools: ["Bash"]
---

# /receipts

With **no argument**, print the most recent receipts audit ledger and summarize it.
With `block` / `warn` / `report`, set the audit mode. This choice persists across sessions
until changed. `default` clears the override. It reverts to `CLAUDE_RECEIPTS_MODE` or the
`warn` default.

```bash
base="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/receipts"
arg="$(printf '%s' "$ARGUMENTS" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

case "$arg" in
  block|warn|report)
    mkdir -p "$base"
    printf '%s\n' "$arg" > "$base/mode"
    echo "receipts mode → $arg (persists until changed; run /receipts default to clear)"
    exit 0 ;;
  default|reset)
    rm -f "$base/mode"
    echo "receipts mode override cleared → CLAUDE_RECEIPTS_MODE or warn default"
    exit 0 ;;
esac

if [ -f "$base/mode" ]; then effmode="$(cat "$base/mode")"; else effmode="${CLAUDE_RECEIPTS_MODE:-warn}"; fi
newest=$(ls -t "$base"/*.jsonl "$base"/*.log 2>/dev/null | head -1)
if [ -z "${newest:-}" ]; then
  echo "No receipts audit yet."
  echo "Auditor is ON by default (mode: $effmode). Disable with:  export CLAUDE_RECEIPTS=0"
  exit 0
fi
echo "Ledger: $newest   (mode: $effmode)"
case "$newest" in
  *.jsonl)
    echo "--- verdict counts ---"
    python3 -c "
import json,sys,collections
counts=collections.Counter()
rows=[json.loads(l) for l in open(sys.argv[1],encoding='utf-8') if l.strip()]
for r in rows: counts[r['verdict']]+=1
for k,v in sorted(counts.items()): print(f'{k:<10} {v}')
print('--- most recent 10, with evidence ---')
for r in rows[-10:]:
    print(f\"{r['ts']}  {r['verdict']}  via={r.get('via','')}\")
    print(f\"  claim: {r['claim'][:140]}\")
    e=r.get('evidence')
    if e: print(f\"  in   : tool#{e['tool_index']} {e['field']} L{e['line_range'][0]}\")
    if e: print(f\"  text : {e['matched'][:140]}\")
" "$newest" ;;
  *)
    echo "--- verdict counts (legacy TSV) ---"
    awk -F'\t' '{c[$2]++} END {for (k in c) printf "%-10s %d\n", k, c[k]}' "$newest"
    echo "--- most recent 15 ---"
    tail -15 "$newest" ;;
esac
```

Summarize for the user: how many claims were **backed** vs flagged **cheating**,
and list any cheating claims verbatim so they can prove or retract them. A
`unproven` verdict means the judge did not respond. The claim is neither
proved nor disproved.
