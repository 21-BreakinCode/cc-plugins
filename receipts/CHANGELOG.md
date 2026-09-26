# Changelog

## 0.5.0 — 2026-09-26

- **fix:** a lone slug or file name no longer backs a claim. The verbatim span must contain at least two words, because an `ls` line carrying a handover's name was backing the table cell that claimed it had been archived.
- **fix:** contradict a success claim only when exactly one command in the turn looks like a test, build or lint run. With several runs there is no cheap way to attribute the failure, and picking the failing one called true claims bluffs: "Test 1 passes" was contradicted by an unrelated command reporting "1 error".
- **fix:** drop "works" from the completion verbs. It reads as an observation in "the fix works" and as an opinion in "it works best as a secondary cross-check", and the second sense had a real analysis paragraph logged as a bluff.
- **test:** on the labeled set: precision 1.000 (was 0.250), recall 0.200, escalation_rate 0.419, dropped_at_extraction 69. All three fixes trade flagging for deferral, so precision rises while recall holds.

## 0.4.0 — 2026-09-26

- **fix:** a claim is backed only when tool output repeats a run of it word for word (24 characters or more). Shared vocabulary proved nothing: replaying 71 real ledger turns showed 47 of 52 `backed` verdicts resting on one shared word against a median claim of 8, so "W2a is done: 55 tests pass" came back backed by an agent's boilerplate line containing "files".
- **fix:** scope the failure signal to the tool that ran the work. An unrelated `gh` call exiting 1 in the same turn used to mark a true "All 15 tests pass" as a bluff.
- **feat:** `replay_ledger.py` rejoins a ledger claim to the transcript turn that produced it, so an old `.log` row can be re-judged against its real evidence.
- **test:** 10 ledger claims adjudicated against their full turn evidence by a fresh-context subagent, each row carrying that evidence so the eval exercises the evidence rules.
- **test:** on the labeled set: precision 0.250, recall 0.200, escalation_rate 0.351, dropped_at_extraction 69. The first two were 0.000 before, because the label set held no positive class.

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
