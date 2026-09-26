---
name: audit-tags
description: Audit the vault's tags against the approved taxonomy and apply one approved refactor plan. It finds false tags (hex colors, hashes, ticket numbers), merged tags that came back, typos, duplicates, singletons, and off-taxonomy tags. When the user invokes /obsidian-kit:audit-tags, run this skill.
disable-model-invocation: true
---

# audit-tags

Run every command from the vault root. Obsidian must be open. `$T` is
`${CLAUDE_PLUGIN_ROOT}/scripts/tags`. `<work>` is a folder in the scratchpad.

1. **Plan:** `python3 $T/plan.py <work>`. It writes `<work>/tag-plan.tsv` and
   `<work>/inventory.json`.
2. **Show the plan** grouped by kind: false, merged-back, typo, duplicate, then the
   singleton and off-taxonomy counts with the 20 most used off-taxonomy tags. For every
   false-tag row, show the line it comes from, so the user can check it before approval.
3. **Propose merges** for off-taxonomy tags that mean the same thing, for example two
   `domain/*` leaves for one topic. Put each proposal in the TSV as `rename` with its `new`
   tag. Every row ends as `rename`, `code`, or `keep`.
4. Get one approval for the whole plan. Do not apply before it. Use a new `<work>` folder
   for each apply. If `<work>/backup` already exists, `apply.py` refuses to run.
5. **Apply:** `python3 $T/apply.py <work>`. It backs up every affected file to
   `<work>/backup/`, fixes frontmatter tags, then body tags, then adds new rows to the
   taxonomy file's `## Allowed` and `## Merged` tables. `code` removes the tag from
   frontmatter and marks it in the body. Every `keep` row is added to `## Allowed`.
6. Report the log `<work>/tag-log.md`, and ask the user to fill the empty `meaning`
   cells of new Allowed rows.
