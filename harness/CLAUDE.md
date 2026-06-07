# harness

Claude Code plugin that builds the dev-lifecycle harness around your agent workflow: feedback loops, eval loops, sensors, and context-mgmt advisories. Extracted from autoresearch — depends on autoresearch for the improvement-loop primitive.

## Standards

- Coding: see `~/.claude/rules/coding-style.md`
- Git: see `~/.claude/rules/git-workflow.md`
- Shell scripts follow POSIX conventions with `set -euo pipefail`
- All bash functions prefixed with `ar_` (shared namespace with autoresearch)

## Project Structure

- `commands/` — `/harness:check`, `/harness:build`, `/harness:improvement`
- `lib/` — `probes.sh` (extended), `harness.sh`, `build.sh`
- `skills/harness-probes/` — guide for adding new probes
- `templates/harness-components/` — Tier-1 templates for feedback / eval / sensor

## Runtime Artifacts

Written into the user's project at:
- `.autoresearch/harness.json` — health scorecard (shared with autoresearch)
- `.claude/hooks/<name>.json` — generated feedback loops
- `eval/<name>.sh` — generated eval scripts
- `.claude/sensors/<name>.sh` + `<name>.SENSOR.md` — generated sensors
- `.claude/harness-report-<date>.md` — context-mgmt advisory reports

## Cross-Plugin Dependency

`harness:improvement` dispatches the `autoresearch:experimenter` subagent via the Agent tool. autoresearch must be installed.
