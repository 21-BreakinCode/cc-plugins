# autoresearch

Claude Code plugin that applies an edit-eval-keep/discard iteration loop to any improvement task. Inspired by karpathy/autoresearch.

## Standards

- Coding: see `~/.claude/rules/coding-style.md`
- Git: see `~/.claude/rules/git-workflow.md`
- Shell scripts follow POSIX conventions with `set -euo pipefail`
- All bash functions prefixed with `ar_`

## Project Structure

- `commands/` — `/autoresearch:improve` slash command
- `agents/` — `experimenter` subagent (runs the iteration loop)
- `skills/` — `experiment-loop` skill (core iteration logic)
- `lib/` — shared shell libraries (common, experiment-log, eval, dashboard)
- `templates/` — HTML dashboard template, program.md template

## Runtime Artifacts

Created in the user's project directory under `.autoresearch/`:
- `program.md` — generated experiment spec
- `experiments.json` — structured iteration log
- `dashboard.html` — auto-refreshing HTML dashboard
