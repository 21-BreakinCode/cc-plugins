---
description: "Vault-wide daily wrap-up. Discovers active handovers, batches user decisions, executes archives/updates/suspensions in parallel. Replaces /op:wrap-up-today."
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Agent", "AskUserQuestion"]
---

# /hh:wrap-up

Daily wrap-up routine for renewing handover docs in the Obsidian vault. Vault-wide, not repo-scoped.

## Vault location

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/lifeos-root.sh") || exit 3
```

**If this exits 3**, the guard has already written setup guidance to stderr. Relay that output to the user verbatim, and stop. Do not guess a vault path, and do not continue.

The vault location is machine-specific and comes from `HH_LIFEOS_ROOT`. Never hardcode it.

## Archive destination

```bash
ARCHIVE_ROOT="${HH_ARCHIVE_ROOT:-$VAULT/04Archive}"
```

- Defaults to `04Archive/` inside the resolved vault. Override by setting `HH_ARCHIVE_ROOT` in `~/.zshrc`. Keep the value double-quoted. Vault paths can contain spaces.
- Each handover archives under `"$ARCHIVE_ROOT/<ORG>/<new-filename>"`. Group-by-org is mandatory. Never write directly under `$ARCHIVE_ROOT`.
- `<ORG>` is derived from the source path: the segment immediately after `01Project/` (for example, `…/LifeOS/01Project/Appier/Services/CsDomain/handover/foo.md` → `Appier`).
- If a handover is **not** under `…/LifeOS/01Project/<ORG>/…`, stop and ask the user which ORG subfolder to archive it under before proceeding. Do not invent one.

## What this command does

1. Discover active handovers (tagged `handover`, not `archive`).
2. Dispatch one subagent per handover **in parallel** to analyze state and suggest a default action.
3. Present a single batched table to the user. Collect all decisions in one pass.
4. Execute archives, updates, and suspensions **in parallel** via subagents.
5. Update wikilinks in **living** docs only. Leave historical records alone.
6. Print a `Wrap-up complete (<date>):` report. (The literal phrase `Wrap-up complete` is required. The Stop hook keys off it.)

If no active handovers are found, print `No active handovers — nothing to wrap up.` and stop.

---

## Phase 1 — Discover

Find files where the frontmatter `tags` list includes `handover` but does not include `archive`. The vault uses YAML list form for tags:

```yaml
tags:
  - handover
  - <other tags>
```

Run:

```bash
VAULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/lifeos-root.sh") || exit 3
grep -rl --include="*.md" -E "^[[:space:]]*-[[:space:]]+handover[[:space:]]*$" "$VAULT" 2>/dev/null \
| while IFS= read -r f; do
    grep -qE "^[[:space:]]*-[[:space:]]+archive[[:space:]]*$" "$f" || printf '%s\n' "$f"
  done
```

Expect 0–10 results. If the count is unexpectedly high (>15), warn the user and ask whether to proceed before spawning many subagents.

---

## Phase 2 — Parallel analysis (one subagent per handover)

Send all Agent calls in a **single message** so they run concurrently. Use `subagent_type: general-purpose`. Each report fills one row of the Phase 3 table, so keep it to the fields below.

Subagent prompt template (substitute `<file>` and today's date):

> You are analyzing one Obsidian handover doc as part of a daily wrap-up routine. The vault is at `$VAULT`. Substitute the resolved absolute path before dispatching.
>
> File: `<file>`
> Today: `<YYYY-MM-DD>`
>
> Read the file and report these fields, one line each where possible:
>
> 1. **Topic:** one-line summary.
> 2. **ORG:** the path segment immediately after `01Project/` (for example, `…/01Project/Appier/Services/CsDomain/…` → `Appier`). If the file is not under `01Project/<ORG>/`, report `ORG: <unresolved>` so the caller can ask the user.
> 3. **Project prefix:** derive from path. Examples:
>    - `01Project/BustDice/Services/...` → `bust-dice`
>    - filename references `CR-1660` → `CR-1660`
>    - otherwise short topic slug, for example `cs-domain`
> 4. **Visible state:** explicit `status:` field in frontmatter, plus checkbox completion ratio (`[x]` count / total).
> 5. **Suggested action:** pick ONE and give a one-phrase reason:
>    - `done`: work is complete. Status reads done, complete, live, or shipped.
>    - `superseded`: a newer handover replaces this one. If you can spot it, name it.
>    - `suspended`: work paused. An explicit `status: suspended` field, or a visible indicator of an indefinite hold, both count.
>    - `active`: still in progress, no fresh entry needed.
>    - `active-update`: still in progress, and the visible state suggests a fresh entry today.
> 6. **Suggested archive filename:** `<prefix>__<status>-<date>-<topic>.md`. Use today's date for `done`. Use the original or inferred date for `superseded`.
> 7. **Cross-references:** incoming wikilinks. Run `grep -rl "\[\[<basename-no-ext>\]\]" "$VAULT"` and classify each result:
>    - `living`: active reference doc (pitfall notes, current handovers, deploy guides).
>    - `historical`: under `02-Area/Journal/`, or the filename matches `^\d{4}-\d{2}-\d{2}` and lives in a folder such as `handover/` or `meeting/`.
>
> Format as Markdown with bold field labels.

Collect all responses. If any subagent fails, note the file and continue.

---

## Phase 3 — Batched user query

Print a compact table:

```
Active handovers found: <N>

| # | File                              | Topic                  | Suggested      |
| - | --------------------------------- | ---------------------- | -------------- |
| 1 | 2026-05-09-deploy-complete.md     | Bust Dice prod deploy  | active-update  |
| 2 | ...                               | ...                    | ...            |
```

Then ask via `AskUserQuestion`. Ask one question per handover, all batched in a single tool call:

- `question`: `Handover #<N>: <basename>`
- `header`: `<basename truncated to ~12 chars>`
- `multiSelect`: false
- `options`:
  - `Active — no change`
  - `Active — append update`
  - `Active — suspend`
  - `Archive: done`
  - `Archive: superseded`
  - `Other` (custom action, follow up after)

For any answer of `Active — append update`, `Active — suspend`, or `Other`, send a follow-up `AskUserQuestion` to capture the update/suspend text or custom action.

If the suggested filename needs a `superseded by` reference, ask the user which doc supersedes it before naming.

---

## Phase 4 — Execute (parallel where possible)

Group user answers into:
- **archive set** (`Archive: done`, `Archive: superseded`)
- **update set** (`Active — append update`)
- **suspend set** (`Active — suspend`)
- **untouched set** (`Active — no change`)
- **custom set** (`Other`, handle inline, do NOT spawn subagents)

### 4a. Archive set — parallel subagents

For each handover, send one Agent call. Issue all calls in a single message.

Subagent prompt:

> Archive an Obsidian handover.
>
> Source: `<source-path>`
> Destination: `<archive-root>/<ORG>/<new-filename>`. Both `<archive-root>` and `<ORG>` are resolved by the caller and passed in verbatim. Do NOT re-resolve them. Create the `<ORG>` subdirectory with `mkdir -p` before writing.
> Filename to use (precomputed from Phase 2 analysis): `<new-filename>`. Do NOT re-derive a slug or date.
> Living wikilink references: `<list-of-paths>`
> Historical wikilink references: `<list-of-paths>` (will be left broken intentionally)
>
> Steps:
> 1. Read the source file.
> 2. In the frontmatter `tags` list, append `- archive` (preserve other tags, no duplicates, preserve order).
> 3. Set the frontmatter `status:` field to the archive status (`done` or `superseded`).
> 4. If the destination directory is missing, create it first (`mkdir -p "<archive-root>/<ORG>"`). Then write the modified content to the destination path.
> 5. Delete the source file (`rm <source>`).
> 6. For each living-reference doc, update wikilinks: `[[<old-basename>]]` → `[[<new-basename>]]`. Preserve display text after `|`. Use Edit with `replace_all: true`. Skip historical references entirely.
> 7. Do NOT add aliases to the archived file.
> 8. Do NOT touch any file under `02-Area/Journal/` or any file whose basename matches `^\d{4}-\d{2}-\d{2}` inside `handover/` or `meeting/` directories.
>
> Report JSON-style: `{ source, destination, wikilinks_updated: { <file>: <count>, ... }, wikilinks_skipped_historical: [<file>, ...] }`.

### 4b. Update set — parallel subagents

Subagent prompt:

> Append a dated update to an active handover.
>
> File: `<file>`
> Today: `<YYYY-MM-DD>`
> Update content (verbatim):
> ```
> <user-supplied-text>
> ```
>
> Steps:
> 1. Read the file.
> 2. If a `## Updates` heading exists, append a new subsection. Otherwise, create the heading
>    at the bottom. If a `## Cross-References` block exists, put the new heading above it. If
>    not, put it at the very end.
> 3. Append:
>    ```
>    ### <YYYY-MM-DD>
>    <user-content>
>    ```
> 4. Do NOT modify frontmatter.
> 5. Do NOT add or change tags.
>
> Report: `{ file, action: "appended" | "created-heading-and-appended" }`.

### 4c. Suspend set — parallel subagents

Subagent prompt:

> Suspend an active handover.
>
> File: `<file>`
> Today: `<YYYY-MM-DD>`
> Reason (verbatim, can be empty):
> ```
> <user-supplied-reason>
> ```
>
> Steps:
> 1. Read the file.
> 2. In frontmatter, set `status: suspended`. If the field is missing, insert it. Otherwise,
>    overwrite the existing status.
> 3. Add a `### <YYYY-MM-DD>` subsection. If a `## Suspended` section already exists, append
>    the subsection under it. Otherwise, create the `## Suspended` heading first, then use this
>    form:
>    ```
>    ## Suspended
>    ### <YYYY-MM-DD>
>    <user-reason if non-empty, else "paused — no reason given">
>    ```
> 4. Do NOT change tags. The file keeps `handover`, does NOT get `archive`.
>
> Report: `{ file, action: "suspended" | "re-suspended" }`.

### 4d. Custom set — handle inline

For `Other` answers, present the user-supplied custom action back to the user. Check with them before executing. Do not spawn a subagent for these.

---

## Phase 5 — Report

After all subagents return, print exactly the phrase `Wrap-up complete` on the first line (the Stop hook depends on this):

```
Wrap-up complete (<YYYY-MM-DD>):

Archived (<N>):
- <old-basename> → <archive-root>/<ORG>/<new-basename>
- ...

Updates appended (<M>):
- <basename>

Suspended (<S>):
- <basename>

Untouched (<K>):
- <basename>

Wikilinks rewritten in <Q> living docs (<P> total references)
Wikilinks deliberately left broken in historical records: <R>
```

Print archived paths in copy-pastable form.

---

## Non-negotiable rules

- **Archive destination**: `"$ARCHIVE_ROOT/<ORG>/<filename>"`. Honor the `HH_ARCHIVE_ROOT` env var. The default is `"$VAULT/04Archive"`. Always quote the path. A vault path can contain spaces. Never write directly under `$ARCHIVE_ROOT` without an `<ORG>` subfolder.
- **ORG resolution**: derive from the source path segment after `01Project/`. If the file is not under `01Project/<ORG>/`, stop and ask the user to pick an ORG. Never guess.
- **Naming convention**: `<prefix>__<status>-[date-]<topic>.md`, status ∈ {`done`, `superseded`}. Date is `YYYY-MM-DD`.
- **Add `archive` tag**: append to existing tags list. Never replace, never reorder other tags.
- **Do not edit historical records**: journals (`02-Area/Journal/**`), dated handovers (`^\d{4}-\d{2}-\d{2}-*.md` inside a folder such as `handover/` or `meeting/`). Broken wikilinks in these files are an honest signal of a rename.
- **No generic aliases**: do not add `aliases:` to the archived file as a workaround for broken wikilinks. If genuinely needed, scope it explicitly.
- **Update wikilinks in living docs only**: pitfall notes, current handovers, active references, deploy guides.
- **Active updates only append content**: only a dated subsection. Do not add tags. Do not change frontmatter. Do not mark "still active" anywhere.
- **Suspended state never archives**: `suspended` is an active-side state. The file keeps the `handover` tag, and does NOT get `archive`.
- **Stop and ask** in three cases. The project prefix is ambiguous. A `superseded` action needs the name of the replacing doc. A cross-reference scan finds a file that is hard to classify.
- **Phase 5 output must contain the literal phrase `Wrap-up complete`.** The Stop hook keys off it.
