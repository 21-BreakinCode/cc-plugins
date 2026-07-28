# receipts — a claim-verification Stop hook

**Date:** 2026-07-28
**Status:** approved (brainstorming), pre-implementation
**Goal:** origin/main carries a working, autoresearch-tuned `receipts` plugin.

## Problem

RLHF rewards a confident "done"/"verified"/"FACT:" even when no tool call backs
it (reward hacking → tool-use hallucination). This repo's user runs
`~/.claude/rules/fact-assume-feedback.md`, which mandates `**FACT:**` for
"anything directly observable — file, line, config, log, metric, test result;
provable if challenged." Nothing currently checks that FACT claims are actually
provable. `receipts` is the enforcement arm: no claim without a receipt.

## Behaviour (decided during brainstorming)

- **Enforcement:** hard gate. On an unbacked claim, `decision: block` — Claude
  must prove it with a real tool call or downgrade `**FACT:** → **ASSUME:**`
  before the turn can end.
- **Judge:** hybrid. A free deterministic prefilter decides the obvious cases;
  only genuinely ambiguous claims escalate to a fresh-context Haiku judge.
- **Trigger:** broad — the `**FACT:**` tag plus work-completion verbs
  (`verified`, `confirmed`, `tests pass`, `fixed`, `done`, `it works`). The
  judge prunes false positives (e.g. "confirmed the user wants dark mode").

## Architecture

Registered `Stop` hook. Default OFF — a blocking hook must be opt-in.

| File | Job |
|---|---|
| `hooks/hooks.json` | Registers the `Stop` hook → `hooks/receipts-check.sh` |
| `hooks/receipts-check.sh` | Bash entry. Env guards (opt-in + recursion), then `exec python3 lib/check.py`. Guards keep the default-off path a ~3-line no-op (no python spawn). |
| `lib/check.py` | Orchestrator: read stdin → extract turn → trigger scan → per-claim classify → escalate to judge → decide (block/allow) → ledger. |
| `lib/extract.py` | Transcript JSONL → last assistant turn text + this turn's tool activity `[{name,input,output}]`. |
| `lib/classify.py` | **TUNABLE.** `(claim, tools) → backed \| cheating \| escalate`. The autoresearch target. |
| `lib/judge.sh` | Escalated claims only → headless `claude -p --model haiku` (fresh context) → per-claim verdict JSON. Sets `RECEIPTS_NESTED=1`. |
| `commands/receipts.md` | `/receipts` → print this session's audit ledger. |
| `tests/fixtures/*.json` | Labeled turns: `{tools:[…], claims:[{text, gold}]}`. |
| `tests/eval-prefilter.sh` | Runs `classify.py` over fixtures → weighted `score: NN` for autoresearch. |
| `tests/test_conformance.sh` | End-to-end: cheating fixture → block JSON; backed fixture → approve. |

**Language:** python core + bash shim. Deviates from the repo's bash+jq hook
convention, justified by JSONL/regex robustness, per-claim testability, and
giving autoresearch a single clean file (`classify.py`) to tune — the same
python-in-bash pattern the autoresearch libs already use.

## Decision flow (one Stop event)

```
Stop → stdin {transcript_path, stop_hook_active, session_id}
 0. GUARD  RECEIPTS_NESTED=1 → exit 0 (don't recurse into our own judge)
           CLAUDE_RECEIPTS!=1 → exit 0 (opt-in; default OFF)
 1. EXTRACT last assistant turn: text + this turn's tool activity
 2. TRIGGER any **FACT:** / completion-verb claims? none → approve (free, common)
 3. CLASSIFY each claim (classify.py):
      no tools this turn                       → cheating (free)
      claim anchor (file:line/keyword/quote) present in tool activity → backed (free)
      else                                     → escalate
 4. JUDGE escalated only (judge.sh, fresh Haiku):
      prompt: only observable/runtime claims need a receipt; reasoning over
      content already visible in the turn is backed.
 5. DECIDE
      all backed → approve
      any cheating NOT already in this session's ledger → record + block
      any cheating already blocked once → approve + note   (loop-bounded)
```

## Loop safety & degradation

- Per-session ledger `~/.claude/receipts/<session_id>` of blocked claim-hashes →
  each unique unbacked claim blocks at most once. `stop_hook_active` is the
  backstop.
- **Fail open, never wedge:** missing `jq`/`claude`/unreadable transcript →
  approve. A verifier must not lock the session on infra failure.

## Config (opt-in; default off)

- `CLAUDE_RECEIPTS=1` — master enable.
- `CLAUDE_RECEIPTS_MODE=block|warn|report` — dial down without uninstalling
  (default `block`).
- `CLAUDE_RECEIPTS_MODEL` — judge model (default `claude-haiku-4-5`).

## Tuning plan (autoresearch)

- **Target:** `lib/classify.py`. **Eval:** `tests/eval-prefilter.sh` over labeled
  fixtures, deterministic, no live LLM.
- **Score (higher better):** weighted penalty — false-backed (a lie slips
  through) and false-cheating (a wrongful block) cost most; over-escalate costs
  little; `escalate` is the safe hedge. Baseline naive-anchor classifier scores
  below 100 (fixtures include traps: a test command that *failed*, a cited file
  that was never read, a path in a different form) so the loop has headroom.
- Stopping: smart defaults (max 10 iters / 3 consecutive non-improvements).

## Out of scope (YAGNI, v1)

- `SubagentStop` coverage (main session only).
- Configurable verb list (hardcoded + documented).
- Cross-session analytics / persistent dashboard.
