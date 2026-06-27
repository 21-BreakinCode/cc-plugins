# harness

> Build the feedback machinery around your agent

Scores project health across six categories, then scaffolds the Tier-1 harness components a project is missing — feedback loops, evals, sensors, and context-mgmt advisories — and auto-fixes the top-ranked issue by delegating to autoresearch.

## Install

```bash
claude plugin install harness@21-breakincode
```

## Commands

- **`/harness:build`** — Menu-driven scaffolder for harness components — feedback loop, eval loop, sensor, or context-mgmt advisory. Writes Tier-1 artifacts into your project's .claude/.
- **`/harness:check`** — Scan project health across code quality, tests, runtime, architecture, scriptability, and harness completeness — produces a scored harness report with impact-ranked improvements
- **`/harness:improvement`** — Execute improvement loop on the top-ranked harness issue — auto-generates eval from probes and spawns the autoresearch:experimenter agent

## Depends on

- [`autoresearch`](../autoresearch/README.md)

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
