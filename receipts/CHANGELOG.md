# Changelog

## 0.3.0 — 2026-09-26

- **test:** baseline (provisional labels, structural non-claims only) on the labeled set: precision 0.000, recall 0.000, escalation_rate 0.406, dropped_at_extraction 64
- **fix:** audit the final assistant message, not every line of the turn. Table rows, headings, and `**ASSUME:**` lines are no longer claims.
- **fix:** a claim is backed only when a tool's OUTPUT shows it. A file name in a tool input no longer counts.
- **feat:** every verdict carries evidence, and the ledger is JSONL.
- **feat:** `unproven` records a claim the judge could not reach, which used to be logged as `backed`.

## 0.2.2 — 2026-09-24

- **perf:** run the Haiku judge from a neutral folder with `--safe-mode` and no tools. A judge call no longer loads plugins, hooks, skills, agents, MCP servers, or CLAUDE.md. A test call used about 3,600 input tokens, down from about 44,000 in 0.2.1.

## 0.2.1 — 2026-09-19

- **fix:** rewrite prose in `commands/receipts.md` and this changelog to clear the simple-english linter. No content or meaning changed, only sentence shape.

## 0.2.0 — 2026-07-29

- **refactor:** default-on with per-session opt-out

## 0.1.0 — 2026-07-28

- **feat:** initial release, a claim-verification Stop hook
- **feat:** tuned prefilter (autoresearch iterations: 75→100 score)
