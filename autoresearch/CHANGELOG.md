# Changelog

## 2.2.0 — 2026-08-10

- **feat:** keep/discard no longer requires git. The experiment loop now
  snapshots target files into `.autoresearch/snapshot/` instead of committing
  and checking out, so `/autoresearch:improve` runs against any directory —
  not just a git repo.
- **fix:** stops polluting real repos with per-iteration commits. Nothing read
  that history; the dashboard sources `reasoning` and `diff_summary` from
  `experiments.json`.
- **breaking:** iterations no longer record a commit SHA in `experiments.json`
  (iteration number already identifies them).
- **test:** `tests/test_snapshot.sh` — 12 assertions, including that a discard
  reverts to the last *kept* state rather than the baseline.

## 2.1.0 — 2026-08-04

- **refactor:** collapse experiment-loop Rules into steps
- **refactor:** source improve.md libs via ${CLAUDE_PLUGIN_ROOT}

## 2.0.0 — 2026-06-28

- **feat:** merge harness plugin into autoresearch (single plugin)

## 1.2.2 — 2026-06-27

- **feat:** glass + depth dashboard redesign

## 1.2.1 — 2026-06-27

- **feat:** redesign eval dashboard (Linear/Vercel-grade visuals + motion)

## 1.2.0 — 2026-06-07

- **refactor:** move harness commands and probes to standalone harness plugin
- **refactor:** convert harness-check and harness-improvement to deprecation shims

## 1.1.1 — 2026-06-06

- **fix:** infer metric direction, fix improvement %

## 1.0.0 — 2026-05-28

- **feat:** initial release — autoresearch plugin
