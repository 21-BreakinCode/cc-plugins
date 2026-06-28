# autoresearch

Claude Code plugin with two halves of one improvement loop: an edit-eval-keep/discard iteration engine for any artifact, and a dev-lifecycle harness builder that scans project health and scaffolds the feedback machinery to improve it. Inspired by karpathy/autoresearch.

## Standards

- Coding: see `~/.claude/rules/coding-style.md`
- Git: see `~/.claude/rules/git-workflow.md`
- Shell scripts follow POSIX conventions with `set -euo pipefail`
- All bash functions prefixed with `ar_`

## Project Structure

- `commands/`
  - `/autoresearch:improve` — run the iteration loop on a user-supplied goal
  - `/autoresearch:harness-check` — scan project health, produce a scored scorecard
  - `/autoresearch:harness-build` — scaffold one Tier-1 harness component
  - `/autoresearch:harness-improvement` — auto-target the top-ranked issue and hand off to the experimenter
- `agents/` — `experimenter` subagent (runs the iteration loop)
- `skills/`
  - `experiment-loop` — core iteration logic
  - `harness-probes` — guide for adding new probes
- `lib/` — shared shell libraries: `common`, `experiment-log`, `eval`, `dashboard` (loop) plus `probes`, `harness`, `build` (harness)
- `templates/` — HTML dashboard template, program.md template, `harness-components/` Tier-1 templates
- `tests/` — smoke tests for the harness probe + build helpers

Commands source libs via `${CLAUDE_PLUGIN_ROOT}/lib/…`; libs source siblings via `$(dirname "${BASH_SOURCE[0]}")/…`.

## Runtime Artifacts

Created in the user's project directory under `.autoresearch/`:
- `program.md` — generated experiment spec
- `experiments.json` — structured iteration log
- `dashboard.html` — auto-refreshing HTML dashboard
- `harness.json` — health scorecard with impact-ranked improvements

The harness build command also writes into the user's project:
- `.claude/hooks/<name>.json` — generated feedback loops
- `eval/<name>.sh` — generated eval scripts
- `.claude/sensors/<name>.sh` + `<name>.SENSOR.md` — generated sensors
- `.claude/harness-report-<date>.md` — context-mgmt advisory reports
