# harness

A Claude Code plugin that builds the dev-lifecycle harness around your agent workflow. Inspired by [OpenAI — Harness Engineering](https://openai.com/index/harness-engineering/). Extracted from [autoresearch](../autoresearch) — depends on it for the improvement-loop primitive.

## Commands

### `/harness:check` — Scan project health

Same five base categories autoresearch's harness-check used to provide (Code Quality, Tests, Runtime, Architecture, Scriptability) **plus** a new `Harness Completeness` category that flags missing harness components.

```
/harness:check
```

### `/harness:build` — Scaffold a Tier-1 harness component

Menu-driven. Pick one of:

1. **Feedback loop** — a Claude Code hook that posts a domain principle on an event
2. **Eval loop** — a shell script returning `{"pass": bool, "metric": n, "reason": "..."}`
3. **Sensor** — a linter wrapper that rewrites findings into agent-tuned fix messages
4. **Context-mgmt** — a Markdown advisory report on oversized agent/skill files

Every generated artifact is **Tier 1** (single file) and embeds an inline upgrade ladder documenting when to escalate to Tier 2 / 3.

```
/harness:build
```

### `/harness:improvement` — Auto-fix the top-ranked issue

Reads `harness.json` from `/harness:check`, generates an experiment spec, dispatches `autoresearch:experimenter`. Same dashboard, same loop, just routed through the new plugin.

```
/harness:improvement              # fix top-ranked
/harness:improvement --rank 2     # fix second-ranked
/harness:improvement --focus tests
```

## Typical workflow

```
/harness:check          # 1. See what's missing
/harness:build          # 2. Add the harness component the project needs most
/harness:check          # 3. Re-check, see the harness score rise
/harness:improvement    # 4. Auto-fix the next non-harness issue
```

## Tier-1 principle

Every generated component opens at the **simplest viable shape** — a single file. The file documents how to escalate. We never auto-generate Tier 2 or Tier 3 scaffolds.

## Runtime artifacts

| File | Purpose |
|---|---|
| `.autoresearch/harness.json` | Health scorecard (shared state with autoresearch) |
| `.claude/hooks/<name>.json` | Generated feedback loops |
| `eval/<name>.sh` | Generated eval scripts |
| `.claude/sensors/<name>.sh`, `.SENSOR.md` | Generated sensors |
| `.claude/harness-report-<date>.md` | Context-mgmt advisory reports |

## Install

```bash
ln -sfn $(pwd)/harness ~/.claude/plugins/local/harness
# autoresearch must also be installed
```

## Adding custom probes

See `skills/harness-probes/SKILL.md`.
