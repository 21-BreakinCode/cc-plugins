# Design: adhd-review + receipts → default-on with per-session opt-out

**Date:** 2026-07-29
**Plugins:** `adhd-review`, `receipts`
**Version bump:** both `0.1.0` → `0.2.0` (minor — behavior default inverts, but backward-compatible)

## Problem

Both plugins currently ship **opt-in**: installing them changes nothing until the
user flips a switch.

- `adhd-review` (`scripts/session-start.sh`): injects its output style only if the
  flag file `~/.claude/.adhd-review-always` exists.
- `receipts` (`hooks/receipts-check.sh`): runs its Stop-hook auditor only if
  `CLAUDE_RECEIPTS=1`.

The user wants both **active by default once installed**, with a **per-session env
var to disable**, and for `receipts` specifically, a non-blocking default plus a way
to change the audit mode from inside a Claude session.

## Goal

Invert both plugins from opt-**in** to opt-**out**, per-plugin and independent (no
shared coupling between the two plugins). Add an in-session mode switcher for
`receipts`.

## Env contract (after change)

| Plugin | Default | Disable (per session) | Notes |
|---|---|---|---|
| `receipts` | **on**, mode = `warn` | `CLAUDE_RECEIPTS=0` | `CLAUDE_RECEIPTS=1` still works (redundant now) |
| `adhd-review` | **on** | `CLAUDE_ADHD_REVIEW=0` | `.adhd-review-always` flag file removed entirely |

`receipts` mode is resolved with precedence: **`/receipts <mode>` override file >
`CLAUDE_RECEIPTS_MODE` env var > `warn` default.**

## Design

### 1. receipts — master switch flip

`hooks/receipts-check.sh`: change the opt-in guard

```sh
# before
[ "${CLAUDE_RECEIPTS:-0}" = "1" ] || exit 0
# after — on by default; only an explicit 0 disables
[ "${CLAUDE_RECEIPTS:-1}" = "0" ] && exit 0
```

The `RECEIPTS_NESTED` recursion guard and the fail-open `cat | python3 … || exit 0`
line are unchanged.

### 2. receipts — default mode `warn` + in-session override

`lib/check.py:150` currently:

```python
mode = os.environ.get("CLAUDE_RECEIPTS_MODE", "block").lower()
```

Replace with a resolver that honors an override file, then the env var, then the new
`warn` default:

```python
def _resolve_mode():
    """Mode precedence: /receipts override file > CLAUDE_RECEIPTS_MODE > warn."""
    try:
        with open(os.path.join(_config_dir(), "mode"), encoding="utf-8") as handle:
            m = handle.read().strip().lower()
        if m in ("block", "warn", "report"):
            return m
    except OSError:
        pass
    return os.environ.get("CLAUDE_RECEIPTS_MODE", "warn").lower()
```

…and `mode = _resolve_mode()` at line 150. `_config_dir()` already returns
`${CLAUDE_CONFIG_DIR:-~/.claude}/receipts` (`check.py:53-55`), the same directory the
`/receipts` command reads, so the `mode` file is shared cleanly.

The explicit-override file wins over the env var on purpose: the in-session command
must be able to change behavior even when the user launched with
`CLAUDE_RECEIPTS_MODE` set.

**Deliberate simplification (`ponytail:`):** the `mode` file is **global** (one file,
`.../receipts/mode`), not per-session. A slash command's bash block does not receive
the Stop-hook `session_id`, so a per-session mode file isn't reachable from the
command. Global scope means the chosen mode persists across sessions until changed —
which matches "set the behavior I want." Upgrade path: if per-session isolation is
ever needed, thread `session_id` into the command and key the file by it.

### 3. receipts — `/receipts` gains a mode argument

`commands/receipts.md`: add `argument-hint: "[block|warn|report|default]"`, branch on
`$ARGUMENTS`:

- **no arg** → print the ledger (current behavior, unchanged).
- **`block` | `warn` | `report`** → write that word to `.../receipts/mode`; confirm
  `receipts mode → <mode> (persists until changed)`.
- **`default` | `reset`** → `rm -f` the mode file; confirm revert to env/`warn`.

The stale "Enable the auditor with: `export CLAUDE_RECEIPTS=1`" hint (shown when no
ledger exists yet) is reworded — the auditor is now on by default; to silence it use
`export CLAUDE_RECEIPTS=0`.

### 4. adhd-review — default-on, drop the flag file

`scripts/session-start.sh`: replace the flag-file gate

```sh
# before
[ -f "$config_dir/.adhd-review-always" ] || exit 0
# after — on by default; only an explicit 0 disables
[ "${CLAUDE_ADHD_REVIEW:-1}" = "0" ] && exit 0
```

The `$config_dir` computation is only there to locate the flag file; once the flag is
gone, that line and the `CLAUDE_CONFIG_DIR` lookup for it are removed. The
`CLAUDE_PLUGIN_ROOT` / `style_file` existence guards stay (they keep the silent-no-op
contract total). The awk that strips frontmatter and emits the style stays.

## Files touched

**Logic**
- `receipts/hooks/receipts-check.sh` — master switch flip
- `receipts/lib/check.py` — `_resolve_mode()`, default `warn`
- `receipts/commands/receipts.md` — mode argument + reworded hint
- `adhd-review/scripts/session-start.sh` — default-on, drop flag file

**Hook descriptions (hand-edited, not generated)**
- `receipts/hooks/hooks.json` — "Off unless CLAUDE_RECEIPTS=1" → "On by default; CLAUDE_RECEIPTS=0 disables; default mode warn"
- `adhd-review/hooks/hooks.json` — "when the opt-in flag … exists" → "on by default; CLAUDE_ADHD_REVIEW=0 disables"

**Docs mention (hand-edited)**
- `adhd-review/skills/adhd-review-mode/SKILL.md` — drop the `.adhd-review-always` flag-file reference

**Source-of-truth for generated docs**
- `.claude-plugin/marketplace.json` — both versions `0.1.0`→`0.2.0`; receipts description "Opt-in, fail-open" → "On by default, fail-open"
- `content/plugins.content.json` — both summaries + `config` blocks rewritten to the opt-out model (adhd-review: replace the flag-file config entry with `CLAUDE_ADHD_REVIEW`; receipts: reword `CLAUDE_RECEIPTS` to on-by-default, change `CLAUDE_RECEIPTS_MODE` default to `warn`, document the `/receipts <mode>` override)
- `receipts/.claude-plugin/plugin.json` — version + description ("Opt-in, fail-open" → "On by default, fail-open")
- `adhd-review/.claude-plugin/plugin.json` — version

**Generated (DO NOT hand-edit — regenerated)**
- `CATALOG.md`, `adhd-review/README.md`, `receipts/README.md`, `site/*` via `./scripts/cicd.sh GEN`

## Testing

- `receipts/tests/test_conformance.sh` — update: default (unset) → auditor active;
  `CLAUDE_RECEIPTS=0` → no-op; default mode is `warn` (tests asserting a *block*
  decision must now set `CLAUDE_RECEIPTS_MODE=block` explicitly). Add: mode-file
  precedence (file `block` overrides env `warn`); `/receipts default` clears it.
- `adhd-review/tests/ac-eval.sh` — update: default (no flag, no var) → style injected;
  `CLAUDE_ADHD_REVIEW=0` → silent no-op. Remove flag-file setup.
- `./scripts/cicd.sh VERIFY` — tests + generated-docs-in-sync gate must pass.

## Out of scope

- No change to the deterministic prefilter, judge, extraction, or classification logic.
- No change to `CLAUDE_RECEIPTS_MODEL`.
- `adhd-review` gets no mode dial — it's a single behavior (inject or don't).
- No shared/coupled kill-switch across the two plugins (per plugin-rules.md §2).
