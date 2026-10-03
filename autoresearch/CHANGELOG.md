# Changelog

## 2.3.1 — 2026-10-03

- **fix:** libs now load when a command or skill sources them from zsh. They fall back to `$0` when `BASH_SOURCE` is unset, and functions use `AR_PLUGIN_DIR` and `AR_TEMPLATES_DIR` instead. Before this fix, sourcing from zsh outside the plugin failed with `BASH_SOURCE[0]: parameter not set`.

## 2.3.0 — 2026-10-03

- **feat:** LLM-judge evals use three blind `autoresearch:judge` agents. Each judge compares the last kept version with the edit, and a strict majority must prefer the edit to keep it. The experimenter no longer scores its own edit.
- **feat:** add `min_delta` to the experiment configuration. A shell-metric gain at or below it is discarded and counts toward the stopping limit. The default 0 keeps the old behavior.
- **feat:** `/autoresearch:improve` adds a default size cap of 150% of baseline for text targets. An edit over the cap is discarded without eval.
- **docs:** `/autoresearch:improve` offers `claude plugin eval` as the shell eval for skill and plugin targets.

## 2.2.3 — 2026-09-24

- **fix:** state the eval-metrics guard in `/autoresearch:improve` once, with its reason, instead of five times with rising emphasis.

## 2.2.2 — 2026-09-19

- **feat:** publish the live improvement dashboard as a private Claude Artifact. The dashboard now uses inline SVG and no external assets.

## 2.2.1 — 2026-09-19

- **fix:** rewrite prose across plugin files to clear the simple-english linter. No content or meaning changed, only sentence shape. "harness" stays: standard term for this plugin.

## 2.2.0 — 2026-08-10

- **feat:** keep/discard no longer requires git. The experiment loop now
  snapshots target files into `.autoresearch/snapshot/` instead of committing
  and checking out, so `/autoresearch:improve` runs against any directory,
  not just a git repo.
- **fix:** stops polluting real repos with per-iteration commits. Nothing read
  that history. The dashboard sources `reasoning` and `diff_summary` from
  `experiments.json`.
- **breaking:** iterations no longer record a commit SHA in `experiments.json`
  (iteration number already identifies them).
- **test:** `tests/test_snapshot.sh`: 12 assertions, including that a discard
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

- **feat:** initial release of autoresearch plugin
