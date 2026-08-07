---
name: refresh-principles
description: Refresh a repo's CodeReviewPrinciple files by learning from merged git + PR history (including reviewer↔author threads). Incremental via a watermark; precision-first; proposes a diff for approval before writing.
disable-model-invocation: true
allowed-tools: ["Bash", "Read", "Edit", "Write", "AskUserQuestion"]
---

# Refresh principles

Mine this repo's **merged** history since the last watermark and distill
evidence-anchored entries into the `01–07` principle files. Never invent — a
finding without a citation is dropped. Never write without approval.

## Step 1 — Resolve (and if needed bootstrap) the principle dir

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-principle-dir.sh"
```
- Exit 0 → `PRINCIPLE_DIR=<stdout>`.
- Exit 1/2 → tell the user no principle dir resolved; ask (AskUserQuestion) for an
  absolute path to create. Create it and seed empty `01`–`07` `.md` files.

## Step 2 — Determine the range

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/learn-state.sh" read "$PRINCIPLE_DIR"
```
- Non-empty → `SINCE=<last_merged_at>`.
- Empty (first run) → `SINCE` = a bounded window (default 6 months ago).
- Backfill: if the user passed `--since <date|sha>` or `--all`, use that; process in
  windows, repeating Steps 3–7 per window.

Base branch: `git remote show origin | sed -n 's/.*HEAD branch: //p'` (fallback `main`).

## Step 3 — Mine (deterministic)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/mine-git-signals.sh" "$SINCE"
bash "${CLAUDE_PLUGIN_ROOT}/lib/mine-pr-signals.sh" "$BASE" "$SINCE"
```

## Step 4 — Distill (precision-first)

Read `references/principle-file-format.md`. Turn ONLY high-signal, corroborated
items into concepts; prefer comments that went **outdated** after being posted
(`caused_change:true`), plus reverts, hotfixes, and clusters recurring across
≥N PRs (N default 2). Each item becomes ONE concept `.md` in its role subdir
(role→type→dir map in the reference), filename = kebab-slug of the title, with
a `sources:` list built from the cited PR#/SHA/comment URLs. Drop anything you
cannot cite.

## Step 5 — Propose (approval gate)

Show a unified diff of the proposed concept files. Use AskUserQuestion:
Approve / Edit / Skip. On **Approve**, stamp each written concept with
`generated: { by: refresh-principles/<model>, at: <now> }` and
`verified: [ { by: human:<id>, at: <today> } ]` — approval doubles as human
sign-off (→ trust tier human-reviewed). Do not proceed without approval.

## Step 6 — Write

On approval, write each concept `.md` into its role subdir; **dedupe by
`sources[].resource`** (never write a concept whose resource already appears in
the bundle). Regenerate `index.md` (okf_version + grouped listing, preserving
any curated prose). Prepend a dated entry to `log.md`. Writes are plain file
writes; do NOT `git commit` the principle dir.

## Step 7 — Advance the watermark (only after a successful write)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/learn-state.sh" write "$PRINCIPLE_DIR" \
  "<newest mergedAt processed>" "<newest merge sha>" '<counts-json>'
```
If the user skipped/declined in Step 5, do NOT advance — the next run retries the
same range.
