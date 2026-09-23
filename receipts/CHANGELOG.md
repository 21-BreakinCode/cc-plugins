# Changelog

## 0.2.2 — 2026-09-24

- **perf:** run the Haiku judge from a neutral folder with no skills and no tools. Each judge call no longer loads the full user setup (plugins, skill and agent listings, project CLAUDE.md).

## 0.2.1 — 2026-09-19

- **fix:** rewrite prose in `commands/receipts.md` and this changelog to clear the simple-english linter. No content or meaning changed, only sentence shape.

## 0.2.0 — 2026-07-29

- **refactor:** default-on with per-session opt-out

## 0.1.0 — 2026-07-28

- **feat:** initial release, a claim-verification Stop hook
- **feat:** tuned prefilter (autoresearch iterations: 75→100 score)
