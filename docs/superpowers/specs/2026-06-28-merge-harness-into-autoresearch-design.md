# Merge `harness` → `autoresearch` (autoresearch v2.0.0)

**Date:** 2026-06-28
**Status:** Approved (design), pending spec review
**Branch:** `worktree-merge-harness-into-autoresearch`

## Problem

`harness` (v1.0.1) and `autoresearch` (v1.2.2) are two separately-published plugins
in the `21-breakincode` marketplace, but `harness` cannot function without
`autoresearch`. It reaches across the plugin boundary three ways:

1. `harness/lib/{probes,harness,build}.sh` source `autoresearch/lib/common.sh` at
   runtime via `find -L ~/.claude/plugins -path '*/autoresearch/lib/common.sh'`.
2. `harness/commands/improvement.md` additionally sources autoresearch's
   `experiment-log.sh`, `eval.sh`, `dashboard.sh`, and dispatches the
   `autoresearch:experimenter` subagent.
3. It relies on autoresearch's `experiment-loop` skill for the iteration protocol.

Claude Code plugins have **no formal dependency mechanism**. The `find -L` search is
the only "loose coupling" tool available and is inherently fragile: it breaks if
autoresearch is absent, moved, or renamed. The motivation for this change is to
**eliminate that fragility**.

Vendoring the libs into `harness` was rejected: it fixes only the lib sourcing
(⅓ of the coupling), cannot vendor a subagent dispatch or a skill, and duplicates
four libs that will drift. **Merging is the only complete fix.**

## Goal & success criteria

Fold `harness` into `autoresearch` as same-plugin commands. Done when:

- [ ] No `find -L ~/.claude/plugins/.../autoresearch` sourcing remains anywhere.
- [ ] The three harness commands run as `/autoresearch:harness-{check,build,improvement}`,
      sourcing libs via `${CLAUDE_PLUGIN_ROOT}`.
- [ ] The `harness` plugin is removed from `marketplace.json` **and**
      `content/plugins.content.json` (kept in lockstep — `GEN --check` enforces it).
- [ ] `./scripts/cicd.sh VERIFY` passes (19 node tests + generated-files-in-sync).
- [ ] The moved smoke tests pass.

## Decisions (locked)

| Decision | Choice |
|---|---|
| Approach | Full merge; retire the `harness` plugin |
| Command naming | `harness-` prefix → `/autoresearch:harness-check`, `harness-build`, `harness-improvement` |
| Back-compat | Clean break — no forwarding shell; migration documented via regenerated CATALOG |
| Version | autoresearch `1.2.2` → **`2.0.0`** (breaking; foreshadowed by existing alias text) |

## File moves (`harness/` → `autoresearch/`)

| From | To | Note |
|---|---|---|
| `harness/commands/check.md` | `autoresearch/commands/harness-check.md` | **overwrites** existing deprecated alias |
| `harness/commands/improvement.md` | `autoresearch/commands/harness-improvement.md` | **overwrites** existing deprecated alias |
| `harness/commands/build.md` | `autoresearch/commands/harness-build.md` | new |
| `harness/lib/probes.sh` | `autoresearch/lib/probes.sh` | join existing 4 libs |
| `harness/lib/harness.sh` | `autoresearch/lib/harness.sh` | |
| `harness/lib/build.sh` | `autoresearch/lib/build.sh` | |
| `harness/skills/harness-probes/` | `autoresearch/skills/harness-probes/` | join `experiment-loop` |
| `harness/templates/harness-components/` | `autoresearch/templates/harness-components/` | |
| `harness/tests/test_build_helpers.sh` | `autoresearch/tests/test_build_helpers.sh` | new dir |
| `harness/tests/test_probe_completeness.sh` | `autoresearch/tests/test_probe_completeness.sh` | |
| `harness/CLAUDE.md`, `harness/README.md` | — | content folded in, then deleted |

Then **delete the entire `harness/` directory**.

## Source-line rewrites (the actual fix)

**Commands** (`.md` bash blocks) — replace the `find -L` search with the plugin-root
variable, which Claude Code guarantees inside a command:

```bash
# before
source "$(find -L ~/.claude/plugins -path '*/harness/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find -L ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
# after
source "${CLAUDE_PLUGIN_ROOT}/lib/probes.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/common.sh"
```

Applies to `harness-check.md`, `harness-build.md`, `harness-improvement.md` for the
moved harness libs **and** the autoresearch libs (`common`, `eval`, `experiment-log`,
`dashboard`) they reference.

**Libs** (`probes.sh`, `harness.sh`, `build.sh`) — they are sourced (not executed),
so resolve the sibling relative to their own location:

```bash
# before
source "$(find -L ~/.claude/plugins -path '*/autoresearch/lib/common.sh' -print -quit 2>/dev/null || echo '/dev/null')"
# after
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
```

**Tests** (`test_build_helpers.sh`, `test_probe_completeness.sh`) — currently locate
the lib under test via `find -L ~/.claude/plugins -path '*/harness/lib/*'`. Rewrite to
resolve relative to the test file's own directory so they test the working tree:

```bash
# after
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
source "${LIB_DIR}/probes.sh"   # or build.sh
```

**No change needed:** `harness-improvement.md`'s `subagent_type: "autoresearch:experimenter"`
and its "read the experiment-loop skill" reference both resolve within autoresearch now.

## Manifest / catalog edits (source-of-truth files only)

- `autoresearch/.claude-plugin/plugin.json`: version → `2.0.0`; description updated to
  mention the harness scan/scaffold commands.
- `.claude-plugin/marketplace.json`: remove the `harness` entry; update autoresearch's
  version + description; bump `metadata.version`; plugin count 7 → 6.
- `content/plugins.content.json`: remove the `harness` entry; update autoresearch's
  `summary` + commands list (`improve`, `harness-check`, `harness-build`, `harness-improvement`).
- `autoresearch/CLAUDE.md`: hand-edit to absorb harness's Project-Structure and
  Runtime-Artifacts sections; drop the "depends on autoresearch" framing. (Not generated.)

**Do NOT hand-edit** `CATALOG.md`, `autoresearch/README.md`, `harness/README.md`, or
`site/*` — the pre-commit hook (`.githooks/pre-commit`) regenerates them from the two
source-of-truth JSON files. They update automatically on commit (or via `cicd.sh GEN`).

## Back-compat: clean break

No forwarding shell. `/harness:*` ceases to exist for new installs. Existing local
`harness@` installs keep a stale copy until the user uninstalls it. The regenerated
CATALOG naturally drops `harness`, which documents the change.

## Execution order

1. (done) Create isolated worktree + branch; verify clean baseline.
2. Move the three lib files; rewrite their `common.sh` source line.
3. Move + rename the three command files; rewrite their source lines to `${CLAUDE_PLUGIN_ROOT}`.
4. Move the skill, templates, and tests; rewrite test lib-resolution.
5. Edit `plugin.json`, `marketplace.json`, `content/plugins.content.json`, `autoresearch/CLAUDE.md`.
6. `git rm -r harness/`.
7. Verify: `grep -rn "find -L" autoresearch/` returns nothing; run moved tests; `./scripts/cicd.sh VERIFY`.

## Risks

- **Missed `source` rewrite** leaving a stale `find -L` path — caught by step-7 grep + tests.
- **Manifest/content drift** — `GEN --check` throws if one JSON has `harness` and the
  other does not; both must be edited together.
- Mechanically low-risk overall: the `ar_` function namespace and `.autoresearch/`
  runtime dir are already shared between the two plugins, so no symbol or path collisions.

## Out of scope

- No behavior changes to any command, probe, or the experiment loop.
- No refactor of autoresearch's existing libs beyond the merge.
- No deprecation-shell plugin (explicitly rejected in favor of the clean break).
