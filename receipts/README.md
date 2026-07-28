# receipts

> No claim without a receipt

A Stop hook that enforces provable claims. When the finished turn asserts a **FACT:** or a completion ('verified', 'tests pass', 'fixed', 'done'), a free deterministic prefilter checks it against that turn's real tool calls; only genuinely ambiguous claims escalate to a fresh-context Haiku judge. Unbacked claims are flagged with a ⚠ note (default `warn` mode) — or hard-gate the turn in `block` mode, where Claude must prove each with a real tool call or downgrade it to **ASSUME:** — bounded to one challenge per claim per session (ledger + stop_hook_active backstop). Enforces the fact-assume discipline (FACT = provable if challenged) that RLHF's confident 'done' quietly erodes. On by default and fail-open; set CLAUDE_RECEIPTS=0 to disable. /receipts prints the session's audit ledger and sets the mode.

## Install

```bash
claude plugin install receipts@21-breakincode
```

## Commands

- **`/receipts:receipts`** — Show this session's receipts audit ledger, or set the audit mode: /receipts [block|warn|report|default].

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_RECEIPTS` | `unset → on` | Master switch. On by default — installing the plugin activates the auditor. Set to `0` to disable it for a session (`1` also works, redundantly). |
| `CLAUDE_RECEIPTS_MODE` | `warn` | `warn` (default) = allow the turn but inject a ⚠ note listing unbacked claims; `block` = hard-gate them until proven/downgraded; `report` = silent audit log only. Change per session with `/receipts block|warn|report` (persists until `/receipts default`); the /receipts override file takes precedence over this env var. |
| `CLAUDE_RECEIPTS_MODEL` | `claude-haiku-4-5` | Model for the fresh-context judge that resolves the ambiguous claims the deterministic prefilter can't settle. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
