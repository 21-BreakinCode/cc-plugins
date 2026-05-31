# code-reviewer

Principle-aware PR review for Claude Code. Layers a repo-specific review mindset on top of the standard `pr-review-toolkit` 4+6 perspectives.

## What this plugin adds over `pr-review-toolkit`

`pr-review-toolkit` provides generic, repo-agnostic review agents (code quality, error handling, tests, types, comments, simplification). This plugin keeps all of those, **and adds one more agent**: `principle-reviewer`, which reviews the PR against a **distilled, repo-specific principle directory** — tribal knowledge derived from the repo's own git history and reviewer comments.

If no principle directory exists for the repo, the review degrades gracefully to the standard 4+6 review (with a guard prompt offering to point at a path).

## Surface

One command:

```
/code-reviewer:review-pr <pr-number>
```

That's it. No flags. Principle-miss behavior is handled by an interactive guard prompt.

## Flow

```
1. Validate PR#
2. gh pr view + gh pr diff
3. Ask user: "what is this PR about?"
4. Resolve principle directory:
   - cache hit?       → use it.
   - LifeOS auto-resolve via handover-handler ORG mapping?  → use it.
   - miss?            → guard prompt (Provide path / Skip / Abort)
5. Dispatch reviews in parallel:
   - 4 built-in perspectives (Dev / QA / Security / DevOps)
   - 6 pr-review-toolkit agents
   - 1 principle-reviewer (only if principle dir was found)
6. Aggregated report with a "Principle-Based Findings" section
```

## Principle directory layout

The plugin expects per-repo directories under a LifeOS path, with up to 7 files (subset allowed):

```
$LIFEOS/01Project/<ORG>/CodeReviewPrinciple/<repo>/
├── 01-overview.md
├── 02-pitfalls.md
├── 03-review-patterns.md
├── 04-domain-traps.md
├── 05-hotspots.md
├── 06-conventions.md
└── 07-red-flags.md
```

Files are loaded in priority order: `07 → 02 → 05 → 04 → 03 → 06 → 01`, soft-capped at ~30K chars.

## Resolution chain

`lib/resolve-principle-dir.sh` resolves the principle directory in this order:

1. **Hard override**: `CODE_REVIEWER_PRINCIPLE_DIR` env var.
2. **Cache lookup**: `$HOME/.claude/code-reviewer/principle-map.json`, keyed by `<github_owner>/<repo>`. Stale entries (path no longer exists) fall through.
3. **LifeOS auto-resolve**: derives `<github_owner>/<repo>` from `git remote get-url origin`, then scans `$LIFEOS/01Project/*/handover_handler__initiation.md` for an ORG whose `github_orgs:` frontmatter contains `<github_owner>`, then checks `$LIFEOS/01Project/<ORG>/CodeReviewPrinciple/<repo>/`.
4. **Miss** → exit 1; orchestrator shows the guard prompt.

## Cache

User-provided paths (from the guard prompt's "Provide path" option) are persisted silently to `$HOME/.claude/code-reviewer/principle-map.json`:

```json
{
  "version": 1,
  "entries": {
    "plaxieappier/some-repo": "/abs/path/to/principle/dir"
  }
}
```

### To "forget" a cached entry

```bash
jq 'del(.entries["plaxieappier/some-repo"])' \
   "$HOME/.claude/code-reviewer/principle-map.json" \
   > /tmp/x && mv /tmp/x "$HOME/.claude/code-reviewer/principle-map.json"
```

The next review of that repo will re-run the auto-resolve chain.

### "Skip" is not cached

Picking "Skip principle layer" in the guard prompt is per-review, not persistent. Next invocation re-prompts. Rationale: missing principle is a fixable state (create the dir), and the prompt keeps that opt-in visible.

## Dependencies

- **Runtime**: `gh` CLI, `git`, `bash`, `jq` (recommended), Python 3 (jq fallback).
- **Plugin dependencies**:
  - `pr-review-toolkit` (from `claude-plugins-official`) — for the 6 toolkit agents.
  - `handover-handler` (from `cc-plugins`) — for the LifeOS ORG mapping via `handover_handler__initiation.md`.

If `handover-handler` is not installed but you maintain LifeOS principles manually, the resolution chain still works as long as `01Project/<ORG>/handover_handler__initiation.md` frontmatter exists with the right `github_orgs:` array.

## Environment overrides

| Variable | Purpose |
|---|---|
| `CODE_REVIEWER_PRINCIPLE_DIR` | Hard override; skip resolution chain entirely. |
| `CODE_REVIEWER_CACHE_FILE` | Override cache file location. |
| `LIFEOS` | Override LifeOS vault root. |

## Files

```
code-reviewer/
├── .claude-plugin/plugin.json
├── README.md
├── commands/review-pr.md
├── agents/
│   ├── pr-review-orchestrator.md   # forked from pr-review-toolkit, adds principle layer
│   └── principle-reviewer.md       # new — reads principle dir, emits cited findings
└── lib/
    ├── resolve-principle-dir.sh    # cache + LifeOS chain
    ├── persist-principle-path.sh   # writes user-provided path to cache
    └── load-principle.sh           # priority-ordered concat with soft cap
```
