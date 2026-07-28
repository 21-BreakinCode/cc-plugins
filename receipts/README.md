# receipts

> No claim without a receipt

A Stop hook that enforces provable claims. When the finished turn asserts a **FACT:** or a completion ('verified', 'tests pass', 'fixed', 'done'), a free deterministic prefilter checks it against that turn's real tool calls; only genuinely ambiguous claims escalate to a fresh-context Haiku judge. Unbacked claims hard-gate the turn — Claude must prove each with a real tool call or downgrade it to **ASSUME:** — bounded to one challenge per claim per session (ledger + stop_hook_active backstop). Enforces the fact-assume discipline (FACT = provable if challenged) that RLHF's confident 'done' quietly erodes. Opt-in and fail-open; /receipts prints the session's audit ledger.

## Install

```bash
claude plugin install receipts@21-breakincode
```

## Commands

- **`/receipts:receipts`** — Show this session's receipts audit ledger — which FACT/completion claims were backed vs flagged unbacked.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_RECEIPTS` | `unset` | Master switch. Set to `1` to enable the auditor. Off by default — a blocking hook must be opt-in, so installing the plugin changes nothing until this is set. |
| `CLAUDE_RECEIPTS_MODE` | `block` | `block` = hard-gate unbacked claims until proven/downgraded; `warn` = allow but inject a ⚠ note listing them; `report` = silent audit log only. Dial down without uninstalling. |
| `CLAUDE_RECEIPTS_MODEL` | `claude-haiku-4-5` | Model for the fresh-context judge that resolves the ambiguous claims the deterministic prefilter can't settle. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
