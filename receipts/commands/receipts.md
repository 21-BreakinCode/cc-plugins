---
description: "Show this session's receipts audit ledger, or set the audit mode: /receipts [block|warn|report|default]."
argument-hint: "[block|warn|report|default]"
allowed-tools: ["Bash"]
---

# /receipts

With **no argument**, print the most recent receipts audit ledger and summarize it.
With `block` / `warn` / `report`, set the audit mode (persists across sessions until
changed); `default` clears the override, reverting to `CLAUDE_RECEIPTS_MODE` or the
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
newest=$(ls -t "$base"/*.log 2>/dev/null | head -1)
if [ -z "${newest:-}" ]; then
  echo "No receipts audit yet."
  echo "Auditor is ON by default (mode: $effmode). Disable with:  export CLAUDE_RECEIPTS=0"
  exit 0
fi
echo "Ledger: $newest   (mode: $effmode)"
echo "--- verdict counts ---"
awk -F'\t' '{c[$2]++} END {for (k in c) printf "%-9s %d\n", k, c[k]}' "$newest"
echo "--- most recent 15 ---"
tail -15 "$newest"
```

Summarize for the user: how many claims were **backed** vs flagged **cheating**,
and list any cheating claims verbatim so they can prove or retract them.
