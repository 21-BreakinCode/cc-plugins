# harness

Dev-lifecycle harness builder for Claude Code. Extracted from [autoresearch](../autoresearch). Full README arrives at v1.0.

## Commands

- `/harness:check` — scan project health (5 base categories + harness completeness)
- `/harness:build` — menu-driven scaffolder for feedback loops, eval loops, sensors, and context-mgmt advisories
- `/harness:improvement` — auto-fix the top-ranked issue from harness.json (delegates to autoresearch:experimenter)

## Install

Symlink or copy this directory to your Claude Code plugins directory. Requires `autoresearch` installed alongside.
