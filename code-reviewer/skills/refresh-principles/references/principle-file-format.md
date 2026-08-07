# OKF concept format (v0.2)

A principle bundle is an OKF v0.2 directory tree. Each mined entry is ONE
concept `.md` file with YAML frontmatter, grouped in a role subdir. Reserved
files `index.md` (listing) and `log.md` (history) carry no `type`/`sources`.

## Concept schema

```yaml
---
type: Pitfall                 # REQUIRED. RedFlag|Pitfall|Hotspot|DomainTrap|ReviewPattern|Convention
title: <short imperative title>
status: stable                # stable | deprecated
stale_after: <YYYY-MM-DD>     # generated date + 6 months
sources:                      # >=1 REQUIRED. No source -> drop the entry.
  - resource: <PR url | commit sha | comment url>
    title: <optional label>
generated: { by: refresh-principles/<model>, at: <ISO-8601> }
verified: [ { by: human:<id>, at: <YYYY-MM-DD> } ]   # stamped on approval
---
**What:** one line.

**Why it matters:** one line.
```

## Role -> type -> directory

| Signal | type | directory |
|---|---|---|
| reverts/hotfixes/blocked-then-fixed | RedFlag | red-flags/ |
| bug clusters across >=2 PRs | Pitfall | pitfalls/ |
| high-churn files | Hotspot | hotspots/ |
| domain gotchas that caused change | DomainTrap | domain-traps/ |
| repeated reviewer asks | ReviewPattern | review-patterns/ |
| convention asks that caused change | Convention | conventions/ |

## Reader priority

`load-principle.sh` emits role dirs in this order (most merge-blocking first):
red-flags -> pitfalls -> hotspots -> domain-traps -> review-patterns ->
conventions -> index.md. The index contains `okf_version` (v0.2) and grouped
listing. It skips `status: deprecated`, flags entries past `stale_after` as
`[STALE]`, and marks each concept `[human-reviewed]` or `[machine-confirmed]`.

## Conformance

Every non-reserved `.md`: parseable frontmatter + non-empty `type` +
>=1 `sources[].resource`. See `tests/test_principle_format.sh`.
