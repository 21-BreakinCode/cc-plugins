# Plugin consolidation design

Date: 2026-09-26. Status: draft for review.

Second wave of the consolidation that `docs/specs/2026-09-26-obsidian-kit-design.md`
started. That document folded `note-visualizer`, kepano's `obsidian` plugin, and the
vault-local excalidraw skill into `obsidian-kit` 1.0.0. This document folds in three
more plugins, deletes one, and reworks a fourth.

## Goal

Cut the `21-breakincode` marketplace from 10 plugins to 6. Every plugin that serves
the Obsidian vault becomes one plugin. The claim auditor becomes trustworthy enough
that a `backed` verdict carries its own evidence.

Success criteria:

1. `obsidian-kit` 2.0.0 ships 11 skills and 4 commands. The three merged plugin
   directories are deleted.
2. `uiux-optimizer` is deleted.
3. `/obsidian-kit:handover-wrap-up` finds the 20 notes tagged `type/handover` and not
   `status/archived` in the LifeOS vault. Today the command finds 0. One of the 20 is a
   known mis-tag that this document leaves alone. See Out of scope.
4. `receipts` 0.3.0 writes an evidence trail with every verdict, and scores better
   than its current baseline on a labeled set drawn from real ledger data.
5. `./scripts/cicd.sh VERIFY` passes.
6. `claude-sync reinstall` removes the four retired plugins from this machine.

## Background

Four facts drove this design. Each one is checkable.

1. The vault tag taxonomy changed on 2026-09-26. A peer Claude session applied it
   across 611 files. The flat `handover` and `archive` tags are retired. Live
   handovers carry `type/handover`. Archived ones carry `archived/type/handover`
   plus an unprefixed `status/archived`. The rule lives in
   `03Resource/About/tag-taxonomy.md`.
2. `handover-handler` reads and writes the retired tags. Its discovery grep returns
   0 files. The failure is silent.
3. `handover-handler` cannot resolve the vault on this machine. It requires
   `HH_LIFEOS_ROOT`, which is unset, so every command exits 3. The repo's
   `./handover` symlink is also dangling. It points into iCloud. The vault is at
   `/Users/william.hung/Projects/LifeOS`.
4. `receipts` marks a claim `backed` when any anchor string appears anywhere in a
   flattened blob of tool names, inputs, and outputs. A claim about a file's
   contents scores `backed` when the only tool call listed that file's name.

## Decisions

| Question | Decision |
|---|---|
| Merged plugin name | `obsidian-kit`. The vault is the store of record. |
| Activation | Two gates. Gate A is `cwd/.obsidian`. Gate B is a `./handover` symlink that resolves. |
| Mandarin rules | Gate A only. Today they load in every session. |
| Session cards | `session-pick-up` writes to the vault after one approval. |
| Naming | Family prefixes. `handover-*` and `session-*`. Vault-native skills keep bare names. |
| State contract | Tags are authoritative. The frontmatter `status:` field is dropped. |
| Archive rename | None. Archiving moves the file and rewrites its tags. |
| Vault resolution | One resolver in `scripts/common/vault.py`. The three `HH_*` path variables are deleted. |
| Retired plugins | Hard delete, plus `RETIRED_PLUGINS` in `claude-sync.sh`. |
| Receipts scope | Provenance and precision, measured against a labeled set. |

## Layout

```
obsidian-kit/
  .claude-plugin/plugin.json          2.0.0
  skills/
    create-excali  update-excali      unchanged
    format-note    migrate-notes      unchanged
    audit-tags                        unchanged
    obsidian-bases obsidian-markdown  unchanged
    session-wrap-up                   from session-learner
    session-pick-up                   from session-learner, now writes
    session-recommend                 from session-learner
    simple-mandarin                   from simple-mandarin
  commands/
    handover-new                      from hh
    handover-wrap-up                  from hh
    handover-init-org                 from hh
    handover-init-service             from hh
  scripts/
    common/vault.py                   gains resolve_via_handover()
    handover/discover.py              new
    handover/archive.py               new
    notes/ tags/ excalidraw/          unchanged
  hooks/
    hooks.json                        one file, all events
    session-primer.py                 gate A
    mandarin-rules.sh                 gate A
    mandarin-lint.py                  gate A
    remind-format.py                  gate A
    excali-lint.sh                    gate A
    offer-handover.sh                 gate B
  tests/                              session-learner suite folded in
```

## Gating

```
SessionStart  session-primer.py    gate A
              mandarin-rules.sh    gate A   was: every session

PostToolUse   remind-format.py     gate A
(Write|Edit)  excali-lint.sh       gate A
              mandarin-lint.py     gate A   was: every session

Stop          mandarin-lint.py     gate A   was: every session
              offer-handover.sh    gate B
```

Each hook script checks its own gate and exits 0 when the gate does not hold.
No hook reads another hook's state.

## Environment variables

Deleted: `HH_LIFEOS_ROOT`, `HH_ARCHIVE_ROOT`, `CLAUDE_SIMPLE_MANDARIN`,
`CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP`.

Added: `OBSIDIAN_KIT_MANDARIN=0` turns the Mandarin rules off.
`OBSIDIAN_KIT_OFFER_HANDOVER=1` turns the handover offer on.

The two path variables are replaced by resolution. The two behavior toggles are
renamed to match the plugin that owns them.

## Vault resolution

`scripts/common/vault.py` already walks up from the working directory to find
`.obsidian/` and loads `.obsidian-kit.json`. Gate B adds one function.

```
resolve_via_handover(cwd):
    link = cwd / "handover"
    if not link is a symlink:        raise VaultConfigError with setup guidance
    target = readlink -f link
    if target does not exist:        raise VaultConfigError, name the dead path
    return find_vault_root(target)
```

`lib/lifeos-root.sh` is deleted. Its setup guidance moves into the two error paths
above, so a user who hits a dangling symlink reads which path is dead.

`.obsidian-kit.json` gains one key.

```json
{
  "taxonomyPath": "03Resource/About/tag-taxonomy.md",
  "noteFormatFolders": ["03Resource/Zettelkasten"],
  "excludedPaths": ["Excalidraw", "01Project/Appier/Credentials", "03Resource/Credentials"],
  "typeFolders": { "unchanged from today": "see the 1.0.0 spec" },
  "handoverArchiveRoot": "04Archive"
}
```

`vault.py` does not add `handoverArchiveRoot` to `REQUIRED_KEYS`. A vault without
it falls back to `04Archive`, so the note skills keep working in a vault that never
holds a handover.

## Handover state contract

A new handover carries these tags and no `status:` field.

```yaml
tags:
  - type/handover
  - project/<org>/<service>
```

The `<prefix>` tag that `hh` writes today is dropped. Rule 3 of the taxonomy says
not to tag what the filename or the folder already says.

An archived handover carries every tag wrapped, plus one unwrapped state tag.

```yaml
tags:
  - archived/type/handover
  - archived/project/<org>/<service>
  - status/archived
```

`status/archived` is never prefixed. The taxonomy states this exception directly.

## Discovery

```
obsidian tags format=json
  -> files carrying type/handover
  -> minus files carrying status/archived
```

The command does not grep frontmatter. A grep for the YAML list form misses a note
tagged inline in its body, and the vault holds at least one such note. The CLI reads
Obsidian's own tag index, which counts both forms.

## Archiving

```
1  resolve destination:  <vault>/<handoverArchiveRoot>/<ORG>/
2  derive ORG:           the path segment after 01Project/
                         no match -> stop and ask, never guess
3  rewrite tags:         every tag -> archived/<tag>
                         add status/archived
                         remove the status: field
4  move:                 obsidian move file=<name> to=<destination>
5  report:               source, destination, tags before and after
```

The filename does not change. Wikilinks keep resolving, so the living and historical
reference classifier is deleted along with the wikilink rewriting step. Existing
archived files are not renamed.

Step 4 replaces a write followed by `rm`. The vault has no version control. A move
is one operation and Obsidian can undo it. A copy followed by a delete cannot be
undone when the copy lands in the wrong place.

## The two init commands

`handover-init-org` and `handover-init-service` keep today's behavior. Both lose
their `lifeos-root.sh` call and use `resolve_via_handover` instead, except at first
run, when no `./handover` symlink exists yet. There the command asks the user for the
vault path once and writes it into the repo's `.claude/settings.local.json`, so the
next run resolves without asking.

## Session skills

`session-wrap-up` and `session-recommend` keep today's behavior. Both print to the
terminal and write nothing.

`session-pick-up` drafts the cards, prints them, then asks once through
`AskUserQuestion` before writing. On approval it writes each card through the
`format-note` rules into the folder that `typeFolders` maps for its note type. A
card is a `concept` or a `takeaway`. Both map to
`03Resource/Zettelkasten/Permanent`.

The approval is not a formality. The vault's own `CLAUDE.md` states that the vault
holds no version control and that edits are unrecoverable.

## Receipts rework

Three changes to `receipts`, in this order.

### Change 1: scope what counts as a claim

`check.py` scans every line of every assistant message since the last user prompt.
The ledger shows what that costs: of 1185 `cheating` verdicts, 49 are markdown table
rows, 21 are headings, 63 are mid-turn narration starting with "Let me", and 6 carry
an `**ASSUME:**` tag.

After the change, `extract_claims` reads the final assistant message, plus any line
carrying a `**FACT:**` tag anywhere in the turn. It skips table rows, headings, and
`**ASSUME:**` lines.

### Change 2: a verdict carries its evidence

`classify()` returns a verdict and the evidence for it.

```
evidence = {
  "tool_index":  int,
  "field":       "output" | "input" | "name",
  "line_range":  [int, int],
  "matched":     str
}
```

A claim about content must match tool output. An anchor found only in a tool input
no longer proves the claim. A file name appearing in `ls config.yaml` does not back
a claim about what `config.yaml` contains. Such a claim escalates instead.

### Change 3: `unproven` becomes a verdict

`run_judge` returning `None` today maps to `backed`, and the ledger cannot tell that
apart from a real verdict. After the change the turn still proceeds, and the ledger
records `unproven` with the reason.

The ledger becomes JSONL so the evidence survives. `/receipts` reads both formats
and prints the trail.

### Eval

The current eval scores 100.0 on 12 fixture claims written from the same intuition
as the classifier, which is why it caught neither bug above.

```
1  sample 120 rows from the 4522 real ledger rows
   stratified across backed and cheating, and across claim shapes
2  the user labels each row right or wrong
3  score the current classifier      -> baseline precision and recall
4  score after each change           -> delta
5  measure the escalation rate       -> it drives the Haiku call cost
```

Change 2 raises the escalation rate by refusing weak matches. The size of that rise
is unknown until step 5 measures it. If the cost is too high, the fix is more
deterministic prefilter rules, not a looser matcher.

## Rollout

```
1  receipts eval        sample, label, baseline
                        verify: baseline precision and recall printed
2  receipts rework      changes 1 to 3
                        verify: beats baseline on the labeled set
3  obsidian-kit merge   move 7 skills and commands, family prefixes,
                        one resolver, one hooks.json
                        verify: test suites pass, each gate fires correctly
4  handover fixes       tags, CLI discovery, move without rename
                        verify: discovery returns 20, one nominated
                        handover archives correctly under review
5  delete 4 plugins     git rm, marketplace entries, content entries,
                        root README tree
                        verify: ./scripts/cicd.sh VERIFY
6  version bumps        obsidian-kit 2.0.0, receipts 0.3.0,
                        marketplace 2.0.0, both changelogs
                        verify: GEN clean, versions equal in both files
7  dotfiles             move 4 names into RETIRED_PLUGINS
                        verify: claude-sync reinstall removes them
```

Commit 4 runs against a vault with no version control. The first archive runs on one
handover the user nominates. The user sees the move result and the rewritten tags
before the other 19 are touched.

## Safety

- No command writes to the vault without an approval step.
- Archiving moves. It never copies and then deletes.
- `ORG` is derived, never guessed. An unresolved `ORG` stops the command.
- Gate A and gate B are checked by each hook. A hook outside its gate exits 0.
- `receipts` fails open. An error in the auditor never blocks a session.

## Tests

- `scripts/handover/test_discover.py`: tag queries, inline tags, archived exclusion.
- `scripts/handover/test_archive.py`: tag rewriting, the `status/archived` exception,
  `ORG` derivation, and the unresolved-`ORG` stop.
- `scripts/common/test_common.py`: extended for `resolve_via_handover`, including a
  dangling symlink and a target outside any vault.
- `receipts/tests/eval.py`: scores the classifier against the labeled set.
- The `session-learner` conformance tests move in unchanged.

## Migration

The user runs one command after commit 7.

```
claude-sync reinstall
```

Until then the old plugins stay installed and their hooks fire alongside the merged
plugin's. The user would see the Mandarin lint twice and two handover offers. This is
why the receipts commits land first.

## Out of scope

- Renaming existing archived files. The vault holds two naming conventions. Both stay.
- Fixing `01Project/Leetcode/Strategy/DP/00__map__DP.md`, which carries an inline
  `#type/handover` tag and is not a handover. It was reported to the peer session.
  It belongs to the tag refactor, not to this one.
- Editing the vault's `CLAUDE.md`, which still documents `tags: [daily]`.
- `autoresearch`, `code-reviewer`, `humanize`, and `adhd-review`. Untouched.
