---
description: "Vault-wide daily wrap-up. Discovers active handovers, batches user decisions, executes archives/updates/suspensions in parallel. Replaces /op:wrap-up-today."
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Agent", "AskUserQuestion"]
---

# /obsidian-kit:handover-wrap-up

Daily wrap-up routine for renewing handover docs in the Obsidian vault. Vault-wide, not repo-scoped.

## Vault location

```bash
VAULT=$(python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/scripts')
from pathlib import Path
from common.vault import VaultConfigError, resolve_via_handover
try:
    print(resolve_via_handover(Path.cwd()))
except VaultConfigError as error:
    print(error, file=sys.stderr); sys.exit(3)
") || exit 3
```

**If this exits 3**, relay the stderr message to the user verbatim and stop. Do not guess a vault path.

## Archive destination

Resolved per handover by `plan_archive` (`${CLAUDE_PLUGIN_ROOT}/scripts/handover/archive.py`):
`<destination> = <vault>/<handoverArchiveRoot, default 04Archive>/<ORG>`. The filename never changes.

- `<ORG>` comes from `derive_org`: the path segment immediately after `01Project/` (for example, `…/01Project/Appier/Services/CsDomain/handover/foo.md` → `Appier`).
- If the handover is not under `01Project/<ORG>/…`, `derive_org` raises `OrgUnresolved`. Stop and ask the user which ORG to file it under. Do not invent one.
- Group-by-org is mandatory. Never write directly under the archive root.

## What this command does

1. Discover live handovers (`type/handover`, not yet `status/archived`).
2. Dispatch one subagent per handover **in parallel** to analyze state and suggest a default action.
3. Present a single batched table to the user. Collect all decisions in one pass.
4. Execute archives, updates, and suspensions **in parallel** via subagents.
5. Print a `Wrap-up complete (<date>):` report. (The literal phrase `Wrap-up complete` is required. The Stop hook keys off it.)

If no active handovers are found, print `No active handovers — nothing to wrap up.` and stop.

---

## Phase 1 — Discover

Find handovers tagged `type/handover` and not yet `status/archived`. Discovery goes through the Obsidian tag index, not a grep. A grep for the YAML list form misses a note tagged inline in its body.

Run:

```bash
python3 -c "
import sys
sys.path.insert(0, '${CLAUDE_PLUGIN_ROOT}/scripts')
from handover.discover import live_handovers
for path in live_handovers(): print(path)
"
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
> 4. **Visible state:** read the note's `tags` list. If it carries a `status/*` tag, report it. Otherwise report `none`. Also report the checkbox completion ratio (`[x]` count / total).
> 5. **Suggested action:** pick ONE and give a one-phrase reason:
>    - `done`: work is complete. The visible state reads done, complete, live, or shipped.
>    - `superseded`: a newer handover replaces this one. If you can spot it, name it.
>    - `suspended`: work paused. The `status/blocked` tag, or a visible indicator of an indefinite hold, both count.
>    - `active`: still in progress, no fresh entry needed.
>    - `active-update`: still in progress, and the visible state suggests a fresh entry today.
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

If the archive action needs a `superseded by` reference, ask the user which doc supersedes it.

---

## Phase 4 — Execute (parallel where possible)

Group user answers into:
- **archive set** (`Archive: done`, `Archive: superseded`)
- **update set** (`Active — append update`)
- **suspend set** (`Active — suspend`)
- **untouched set** (`Active — no change`)
- **custom set** (`Other`, handle inline, do NOT spawn subagents)

### 4a. Archive set — parallel subagents

For each handover, resolve `<destination>` first via `plan_archive` (see Archive destination, above). Do not let the subagent re-derive it. Then send one Agent call per handover. Issue all calls in a single message.

Subagent prompt:

> Archive one Obsidian handover.
>
> Source (vault-relative): `<source>`
> Destination folder: `<destination>`  (already resolved, do NOT re-derive)
> Filename: unchanged.
>
> Steps:
> 1. Read the source file.
> 2. Rewrite the frontmatter `tags` list: prefix every tag with `archived/`,
>    except a tag that already starts with `archived/`, and except
>    `status/archived`. If `status/archived` is absent, append it.
> 3. If a frontmatter `status:` field is present, remove it.
> 4. `mkdir -p "<destination>"`.
> 5. Move the file: `obsidian move file="<name>" to="<destination>"`.
>    Read the output for `Error:`. The CLI exits 0 even on failure.
> 6. Do NOT rename the file. Do NOT touch any other file.
>
> Report: `{ source, destination, tags_before, tags_after }`.

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
> 2. In the frontmatter `tags` list, add `status/blocked`. If it is already present, leave it.
>    Leave every other tag untouched. Keep `type/handover`. Do NOT add any `archived/` prefix.
>    Suspended is an active-side state.
> 3. If a frontmatter `status:` field is present, remove it.
> 4. Add a `### <YYYY-MM-DD>` subsection. If a `## Suspended` section already exists, append
>    the subsection under it. Otherwise, create the `## Suspended` heading first, then use this
>    form:
>    ```
>    ## Suspended
>    ### <YYYY-MM-DD>
>    <user-reason if non-empty, else "paused — no reason given">
>    ```
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
- <basename> → <destination>
- ...

Updates appended (<M>):
- <basename>

Suspended (<S>):
- <basename>

Untouched (<K>):
- <basename>
```

Print archived paths in copy-pastable form.

---

## Non-negotiable rules

- **Archive destination**: `<destination>/<filename>`, where `<destination>` already includes the `<ORG>` subfolder (see `plan_archive`, above). Default archive root is `04Archive/` inside the vault. Override it via `handoverArchiveRoot` in `.obsidian-kit.json`. Never write directly under the archive root without an `<ORG>` subfolder.
- **ORG resolution**: derive from the source path segment after `01Project/`. If the file is not under `01Project/<ORG>/`, stop and ask the user to pick an ORG. Never guess.
- **Never rename on archive.** The filename is the wikilink target. Status lives
  in tags and the `04Archive/<ORG>/` folder says the rest.
- **Move, never copy then delete.** The vault has no version control.
- **Tag rewrite on archive**: prefix every tag with `archived/`, except a tag already so prefixed and except `status/archived`. If `status/archived` is absent, append it. Never drop an existing tag.
- **No generic aliases**: do not add `aliases:` to the archived file. If genuinely needed, scope it explicitly.
- **Active updates only append content**: only a dated subsection. Do not add tags. Do not change frontmatter. Do not mark "still active" anywhere.
- **Suspended state never archives**: `suspended` is an active-side state. The note keeps `type/handover` and gets `status/blocked`, and never gets any `archived/` prefix.
- **Stop and ask** in two cases. The project prefix is ambiguous. A `superseded` action needs the name of the replacing doc.
- **Phase 5 output must contain the literal phrase `Wrap-up complete`.** The Stop hook keys off it.
</content>
