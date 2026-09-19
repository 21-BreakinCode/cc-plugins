# autoresearch

> Eval-driven improvement, plus the harness to drive it

Two parts form one loop. An edit → eval → keep/discard engine improves code, prompts, or docs. It scores each change with a shell command, an LLM judge, or both. It shows progress in a live Artifact dashboard. A harness builder measures project health in six categories. It creates feedback loops, evals, sensors, and context management advisories. It then fixes the top-ranked issue through the same loop.

## Install

```bash
claude plugin install autoresearch@21-breakincode
```

## Commands

- **`/autoresearch:harness-build`** — Menu-driven scaffolder for harness components: feedback loop, eval loop, sensor, or context-mgmt advisory. Writes Tier-1 artifacts into your project's .claude/.
- **`/autoresearch:harness-check`** — Scan project health across code quality, tests, runtime, architecture, scriptability, and harness completeness. Produces a scored harness report with impact-ranked improvements
- **`/autoresearch:harness-improvement`** — Execute improvement loop on the top-ranked harness issue: auto-generates eval from probes and spawns the autoresearch:experimenter agent
- **`/autoresearch:improve`** — Iteratively improve any artifact using an edit-eval-keep/discard loop with live dashboard

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
