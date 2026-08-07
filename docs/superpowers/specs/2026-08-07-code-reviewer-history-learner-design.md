# code-reviewer: history-learner + review determinism — design

- **Date:** 2026-08-07
- **Status:** Approved (brainstorming) — pending spec review → implementation plan
- **Plugin:** `code-reviewer` (marketplace `21-breakincode`)
- **Version target:** `0.2.0 → 0.3.0` (minor: new feature)

## 1. Goal

Turn `code-reviewer` from a **consumer-only** plugin into a **closed learning loop**, channeling the "learn-from-production" spirit of Alibaba's `open-code-review` (`ocr`) without depending on it.

Two workstreams, both approved:

1. **Producer skill** (`refresh-principles`) — mines this repo's git + PR history (including reviewer↔author PR conversations) and writes/refreshes the `01–07` principle files that `principle-reviewer` already consumes.
2. **Review-side determinism** — add ocr-style deterministic guards to the existing `review-pr` flow: guaranteed file/hunk coverage and finding line-ref validation.

## 2. Current state (facts)

- The plugin has a principle **consumer** — `agents/principle-reviewer.md` reads `01–07` files via `lib/load-principle.sh`.
- There is **no producer** — nothing in the repo creates or updates principle files.
- `lib/resolve-principle-dir.sh` resolves the per-repo principle directory (env override → cache → config roots).
- `code-reviewer/` has no `skills/` dir yet — this adds the first.
- `session-learner/` is the structural template: `skills/<name>/SKILL.md` + `references/*-format.md` + `tests/` golden fixtures + conformance script.

## 3. Locked decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | Both workstreams (producer skill + review determinism) | User selected "Skill + review determinism" |
| Producer architecture | **C — deterministic mine + thin distill** | Precision-first is enforced by deterministic pre-filtering; lowest tokens |
| Review determinism | **a — coverage pre-pass in orchestrator** | Captures ocr coverage/anti-drift spirit with zero new dependency |
| Platform | GitHub via `gh` | Matches existing `gh pr diff` usage; PR threads via `gh pr view --json reviews,comments` + `gh api` |
| Refresh model | Incremental (watermark) | Cheap re-runs; preserves curated edits |
| First run | Bounded window (~6 months / ~100 merged PRs, configurable) | Cheap, precise bootstrap |
| Extraction policy | Precision-first, evidence-anchored | Every entry cites its source; no invention (mirrors `principle-reviewer` "don't invent" rule) |
| Write policy | Propose-then-approve | User rule: always ask approval when mutating; show unified diff, never silent write |
| Learn source | **Merged PRs only** | A merged PR + its final thread is a *settled* decision; open/rejected PRs are excluded |
| Watermark cursor | `mergedAt` timestamp (primary), merge SHA (secondary) | Survives base-branch rebase/force-push |
| Backfill | `--since <date\|sha>` / `--all`, chunked into windows | Recover un-learned history safely; one approval gate per window |
| Skill invocation | User-invoked (`disable-model-invocation: true`) | Periodic maintenance action; nothing must auto-trigger it → zero context load |

## 4. Architecture — the closed loop

```
        ┌──────────── NEW producer skill: refresh-principles ───────────────┐
        │  watermark → mine (bash, deterministic) → distill (thin LLM)       │
        │           → approve gate → write → advance watermark               │
        └───────────────────────────────┬────────────────────────────────────┘
                                         ▼ writes/merges (diff-gated)
                     01–07 principle files  +  .learn-state.json
                                         │ reads
        ┌────────────────────────────────▼───────────────────────────────────┐
        │  review-pr → orchestrator → principle-reviewer                       │
        │      + NEW coverage pre-pass  + NEW finding line-ref validation       │
        └────────────────────────────────────────────────────────────────────┘
```

Two independent, manually-triggered entry points, coupled only through the principle files (async — neither calls the other):

- **Trigger 1 — `refresh-principles`** (periodic): the only writer. Reads watermark, mines only unread merged PRs + new commits since, distills, user approves, writes, advances watermark.
- **Trigger 2 — `review-pr <n>`** (per-PR): read-only w.r.t. principle files. Original shape unchanged plus two deterministic guards.

## 5. File layout

```
code-reviewer/
├── skills/refresh-principles/
│   ├── SKILL.md                     NEW  user-invoked orchestration of the producer flow
│   └── references/
│       └── principle-file-format.md NEW  schema + entry/citation format for 01–07
├── lib/
│   ├── mine-git-signals.sh          NEW  reverts · hotfix commits · file-churn rank (git log)
│   ├── mine-pr-signals.sh           NEW  gh: merged PRs, review threads, inline comments,
│   │                                     + comment→change correlation
│   ├── learn-state.sh               NEW  read/write watermark (.learn-state.json in principle dir)
│   └── check-diff-coverage.sh       NEW  coverage pre-pass + finding line-ref validation (2 modes)
├── agents/pr-review-orchestrator.md MOD  insert coverage pre-pass + finding-location validation
└── tests/                           NEW  offline golden fixtures + conformance script
```

## 6. Component contracts

Each unit: one purpose, explicit interface, isolated + testable.

### `lib/learn-state.sh`
- **Purpose:** read/write the per-principle-dir watermark.
- **Interface:** `learn-state.sh read <principle-dir>` → JSON on stdout (empty if none). `learn-state.sh write <principle-dir> <last_merged_at> <last_sha> <counts-json>` → atomic write (temp + `mv`).
- **Depends:** `jq`.

### `lib/mine-git-signals.sh`
- **Purpose:** deterministic commit-level signals (works even with no PRs).
- **Interface:** `mine-git-signals.sh <since-ref-or-date> [<until>]` → JSON `{ reverts:[{sha,subject,reverts_sha}], hotfixes:[{sha,subject,files}], churn:[{file,pr_count,fix_count,rank}] }`. Renames tracked via `git log --follow`.
- **Depends:** `git`.

### `lib/mine-pr-signals.sh`
- **Purpose:** deterministic PR-level signals via `gh` (robust to squash vs merge-commit).
- **Interface:** `mine-pr-signals.sh <base-branch> <since-date> [<until-date>]` → JSON, per merged PR: `{ number, title, mergedAt, mergeCommit, reviews:[{state,author}], comments:[{path,line,body,url,author,caused_change}] }`.
- **comment→change correlation:** for each inline review comment, flag `caused_change=true` if a later commit in that PR modified the commented path near the commented line (the highest-value precision seed).
- **Depends:** `gh`, `jq`.

### `lib/check-diff-coverage.sh` (workstream a)
- **Purpose:** deterministic review guards.
- **Mode 1 — coverage:** `check-diff-coverage.sh coverage <pr-number>` → JSON `{ files:[{path,hunks,covered,exclude_reason?}], uncovered:[...] }`. Toolkit agents review the whole diff; this mode produces a deterministic checklist so the report can *assert* every changed file was covered rather than the LLM silently reviewing a subset. Binary/lockfile/generated files marked `excluded: <reason>`, never silently dropped.
- **Mode 2 — validate:** `check-diff-coverage.sh validate <pr-number> <findings-json>` → each finding whose `file:line` is absent from the diff is flagged `unverified location` (downgraded, **not deleted**).
- **Depends:** `gh`/`git`, `jq`.

### `skills/refresh-principles/SKILL.md`
- **Purpose:** orchestrate the producer flow (see §7). User-invoked; `${CLAUDE_PLUGIN_ROOT}/lib/*` for bundled scripts.
- **Depends:** the four libs above + `resolve-principle-dir.sh`.

### `agents/pr-review-orchestrator.md` (modified)
- Add **Phase 2.5 — coverage pre-pass** (before dispatch): run `check-diff-coverage.sh coverage`; ensure every changed file/hunk is accounted for in the review — covered or explicitly excluded — so no file is silently skipped.
- Add to **Phase 4** — run `check-diff-coverage.sh validate` on aggregated findings; flag unverified locations.

## 7. Data flow — producer skill

```
1. resolve principle dir  (resolve-principle-dir.sh; bootstrap+create if missing)
2. learn-state.sh read    → last_merged_at / last_sha   (first run: bounded window)
3. mine-git-signals.sh    → reverts, hotfixes, churn rank                [deterministic]
4. mine-pr-signals.sh     → merged PRs in range + threads + comment→change [deterministic]
5. thin LLM distill       → ONLY high-signal, evidence-tagged items become entries;
                            each cites PR#/SHA/comment-url + date; no citation ⇒ rejected
6. approve gate           → show unified diff of proposed 01–07 changes → user approves
7. write                  → merge into 01–07 (append/update, dedupe, never clobber curated text)
8. learn-state.sh write   → advance watermark + counts (ONLY after a successful approved write)
```

Backfill (`--since`/`--all`): steps 3–8 loop over bounded windows, one approval gate per window; watermark advances per completed window (resumable).

## 8. Signal → principle-file mapping

| Principle file | Fed by | Evidence required |
|---|---|---|
| **07-red-flags** | reverts / hotfixes; review comments that blocked merge then got fixed | SHA of revert, or change-requested→fix |
| **02-pitfalls** | same fix pattern recurring across ≥N PRs | ≥N PR#s citing the cluster |
| **05-hotspots** | file-churn ranking (most PRs / most fix-commits) | commit counts per file |
| **04-domain-traps** | review comments explaining a domain gotcha that caused a change | comment url + resulting edit |
| **03-review-patterns** | what reviewers repeatedly ask for across PRs | ≥N recurring comment theme |
| **06-conventions** | style/convention comments that recurred and led to change | comment url + edit |
| **01-overview** | run manifest: repo, window, counts, watermark | auto-generated |

`N` (recurrence threshold) is a skill arg, default 2.

## 9. `.learn-state.json` schema (lives inside the principle dir)

```json
{
  "version": 1,
  "repo": "owner/repo",
  "last_merged_at": "2026-08-01T12:00:00Z",
  "last_merged_sha": "abc1234",
  "window": { "first_run_since": "2026-02-01", "strategy": "bounded-6mo|since|all" },
  "counts": { "07-red-flags": 3, "02-pitfalls": 4, "05-hotspots": 6 },
  "runs": [ { "generated_at": "2026-08-07T09:00:00Z", "range": "...", "prs_processed": 12, "entries_added": 5 } ]
}
```

## 10. Error handling (fail fast, never silently swallow)

| Condition | Behavior |
|---|---|
| `gh` unauth/missing, no git remote, `jq` missing | Early-exit with fix (`gh auth login` / `brew install jq`), reuse `die_env` pattern |
| Principle dir absent (first ever run) | Bootstrap: resolve intended path → ask to create → seed empty `01–07` skeleton |
| No new merged PRs since watermark | Clean exit `Nothing new since <date>`; no write |
| Distilled entry without citation | Rejected before diff shown (precision guard) |
| User declines approval gate | Write nothing **and do not advance watermark** → next run retries same range |
| Coverage: unassignable file | Flag `excluded: <reason>`, never silently dropped |
| Finding `file:line` not in diff | Downgrade + flag `unverified location`, do not delete |

## 11. Edge cases

- **Merge strategy** — PR mining via `gh pr list --state merged`, not raw-log parsing (robust to squash/merge-commit).
- **Rebase/force-push** — `mergedAt` timestamp is the primary cursor (SHA can vanish).
- **Dedupe** — write keys entries by `(principle-type, primary-citation)`; overlapping re-runs never duplicate.
- **Renamed files** — churn uses `git log --follow`.
- **Backfill resumability** — per-window watermark advance; mid-backfill failure resumes from last completed window.
- **Principle dir writes are file-only** — never auto-commit someone's principle repo (e.g. LifeOS); `.learn-state.json` written atomically.
- **Out of scope v1:** monorepo `--path` scoping; GitLab/Gerrit (GitHub-only, matching current plugin).

## 12. Testing (session-learner pattern: offline golden fixtures)

The distill step is LLM (non-deterministic) → test the **deterministic spine**, not prose.

- **Fixtures** (`tests/fixtures/`): canned `git log` + canned `gh` JSON (offline, no network).
- **Conformance asserts:** miners bucket signals correctly · every emitted entry carries a citation · dedupe rejects a repeat · watermark read/write round-trips · coverage assigns-or-excludes every file · a planted bad line-ref gets flagged.
- **Format-only check** on distilled entries (schema: citation present + valid file target), not wording.
- Repo gate: `./scripts/cicd.sh VERIFY` must pass.

## 13. Versioning & generated docs (plugin-rules)

- Bump `0.2.0 → 0.3.0` in **both** `marketplace.json` + `code-reviewer/.claude-plugin/plugin.json`.
- Update `content/plugins.content.json` summary to mention the learn-loop; skill is auto-harvested (don't list it). Run `./scripts/cicd.sh GEN`.
- No new env vars (watermark in principle dir; `--since`/`--all`/window-size/`N` are skill args). Existing `CODE_REVIEWER_*` unchanged.

## 14. Invariant that makes it safe

**The watermark only advances after an approved write.** This single rule yields idempotent re-runs, resumable backfill, and a decline-safe approval gate for free.

## 15. Out of scope / future

- Delegating the review pass to `ocr` as an external engine (kept as a future option, not a coupling).
- GitLab/Gerrit sources; monorepo path scoping.
- Auto-committing the principle directory.
