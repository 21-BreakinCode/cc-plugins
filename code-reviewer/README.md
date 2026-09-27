# code-reviewer

> Multi-agent PR review with a per-repo policy layer

Runs five reviewers in parallel on a PR: correctness, tests, security, ops, and simplicity (ponytail and /simplify rules). If the repo has a local review policy, a sixth reviewer cites the repo's own red-flags, pitfalls, and hotspots. Includes `refresh-policy`, which learns that policy from merged git and PR history.

## Install

```bash
claude plugin install code-reviewer@21-breakincode
```

## Commands

- **`/code-reviewer:review-pr`** — Multi-agent PR review: five common reviewers plus an optional repo-specific policy layer

## Configuration

| Variable | Default | Description |
|---|---|---|
| `CODE_REVIEWER_POLICY_DIR` | `—` | Repo review-policy dir. A relative value resolves against the main clone root. Unset means the policy layer is off. |

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
