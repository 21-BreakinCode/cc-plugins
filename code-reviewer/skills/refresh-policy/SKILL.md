---
name: refresh-policy
description: Refresh a repo's local review policy (.review-policy/) by learning from merged git + PR history, including reviewer↔author threads. Keeps only repo-specific traps. Incremental via a watermark. Proposes a diff for approval before writing.
disable-model-invocation: true
allowed-tools: ["Bash", "Read", "Edit", "Write", "AskUserQuestion"]
---

# Refresh policy

Mine this repo's **merged** history since the last watermark. Distill
evidence-anchored entries into OKF concept files, one concept per entry.
Write each into its role subdir (`red-flags/`, `pitfalls/`, `hotspots/`,
`domain-traps/`, `review-patterns/`, `conventions/`). Never invent. A
finding without a citation is dropped. Never write without approval.

## Step 1 — Resolve (and if needed bootstrap) the policy dir

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-policy-dir.sh"; echo "exit=$?"
```

- Exit 0 → `POLICY_DIR=<stdout>`.
- Exit 3 → stop. Show the stderr line. The user must set `CODE_REVIEWER_POLICY_DIR` (for example `.review-policy`) in the `env` of the settings file that this repo loads, then restart the session.
- Exit 1 → the stderr line names the missing dir. Ask (AskUserQuestion) before you create it. On yes, create it with an `index.md`:

  ```
  ---
  okf_version: "0.2"
  ---
  # Overview — <repo>
  ```

  Role subdirs are created lazily as concepts are written (Step 6).
- Exit 2 → stop. This is not a git repo.

## Step 2 — Determine the range

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/learn-state.sh" read "$POLICY_DIR"
```
- Non-empty → `SINCE=<last_merged_at>`.
- Empty (first run) → `SINCE` = a bounded window (default 6 months ago).
- Backfill: if the user passed `--since <date|sha>` or `--all`, use that. Process in
  windows, repeating Steps 3-7 per window.

Base branch: `git remote show origin | sed -n 's/.*HEAD branch: //p'` (fallback `main`).

## Step 3 — Mine (deterministic)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/mine-git-signals.sh" "$SINCE"
bash "${CLAUDE_PLUGIN_ROOT}/lib/mine-pr-signals.sh" "$BASE" "$SINCE"
```

## Step 4 — Distill (precision-first)

Read `references/policy-file-format.md`. Turn ONLY high-signal, corroborated
items into concepts. Prefer comments that went **outdated** after being posted
(`caused_change:true`), plus reverts, hotfixes, and clusters recurring across
≥N PRs (N default 2). Each item becomes ONE concept `.md` in its role subdir
(role→type→dir map in the reference). Use a kebab-slug of the title as the
filename. Include a `sources:` list built from the cited PR#/SHA/comment URLs.
Drop anything you cannot cite.

**Repo-specific gate:** the common reviewers already cover generic lessons
("add tests", "handle errors", "no hardcoded secrets"). If its **What** line
names a repo path, a repo module, a repo domain term, or a repo constant,
keep the candidate. A PR number or SHA in `sources` does not count, because
every concept has one. A Hotspot always passes, because its anchor is a file
path.

**Misdiagnosis sequences:** look specifically for `revert_chains` in git
signals (a revert whose target was itself reverted) and for revert→different-fix
pairs touching the same files. These signal that the original diagnosis was
wrong and the fix was built on a contaminated premise. A test oracle
answered a question nobody meant to ask. Capture as a **Pitfall** citing both
the original commit and the correction. The **What** names the
misdiagnosis pattern (for example, "synthetic fixture masked a legal encoder
optimization as a regression").

## Step 5 — Propose (approval gate)

Show a unified diff of the proposed concept files. Use AskUserQuestion:
Approve / Edit / Skip. On **Approve**, stamp each written concept with
`generated: { by: refresh-policy/<model>, at: <now> }` and
`verified: [ { by: human:<id>, at: <today> } ]`. Approval doubles as human
sign-off (→ trust tier human-reviewed). Do not proceed without approval.

## Step 6 — Write

On approval, write each concept `.md` into its role subdir. **Dedupe by
`sources[].resource`** (never write a concept whose resource already appears in
the bundle). Regenerate `index.md` (okf_version + grouped listing, preserving
any curated prose). Prepend a dated entry to `log.md`. Writes are plain file
writes. Do NOT `git commit` the policy dir.

## Step 7 — Advance the watermark (only after a successful write)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/learn-state.sh" write "$POLICY_DIR" \
  "<newest mergedAt processed>" "<newest merge sha>" '<counts-json>'
```
If the user skipped/declined in Step 5, do NOT advance. The next run retries the
same range.
