# session-learner

> Turn a session into atomic Zettelkasten knowledge

A wrap-up → pick-up → recommend reflection funnel: wrap-up surfaces session pitfalls and candidate take-away topics, pick-up turns chosen topics into atomic Zettelkasten cards grounded in the real case and up to 3 web sources, and recommend picks the single topic most worth keeping.

## Install

```bash
claude plugin install session-learner@21-breakincode
```

## Skills

Invoke one directly as `/session-learner:<skill>`, or let it activate automatically when relevant.

- **`pick-up`** — Use after wrap-up to turn chosen topic numbers into atomic Zettelkasten cards grounded in the session case and up to 3 web sources.
- **`recommend`** — Use after wrap-up when unsure which take-away topic matters most — picks exactly one topic to keep, with reasoning.
- **`wrap-up`** — Use at the end of a working or debugging session to reflect on pitfalls worth noticing and list candidate take-away topics to keep.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_SESSION_LEARNER_ZK_PATH` | `~/…/LifeOS/03-Resource/Zettelkasten/Permanent` | Vault `Permanent/` dir used to ground `pick-up` card links and tags. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
