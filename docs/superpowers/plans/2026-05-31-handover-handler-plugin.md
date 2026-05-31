# handover-handler Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin that makes LifeOS the single source of truth for cross-repo handover documents via folder symlinks, with four slash commands (`/hh:init-org`, `/hh:init-service`, `/hh:new`, `/hh:wrap-up`) and an opt-in Stop hook.

**Architecture:** Markdown command prompts drive Claude through each flow, calling deterministic Bash + awk helpers under `lib/` for org/service resolution, mapping-table parsing, and symlink management. The plugin folder is named `handover-handler/` but the command namespace is `hh` via `"name": "hh"` in `plugin.json`. Wrap-up logic ports the existing `/op:wrap-up-today` user command into the plugin and trims state set to `active`/`active-update`/`suspended`/`done`/`superseded`. A Stop hook (off by default) offers `/hh:new` after a wrap-up session.

**Tech Stack:** Bash + awk (lib scripts), Markdown (commands, hook scripts), JSON (hook config). No agents, no skills, no external test framework.

**Spec:** `docs/superpowers/specs/2026-05-31-handover-handler-design.md`

---

## File Structure

```
handover-handler/
├── .claude-plugin/
│   └── plugin.json                  # name: "hh" → /hh:* command namespace
├── commands/
│   ├── init-org.md                  # /hh:init-org
│   ├── init-service.md              # /hh:init-service
│   ├── new.md                       # /hh:new
│   └── wrap-up.md                   # /hh:wrap-up (replaces /op:wrap-up-today)
├── hooks/
│   ├── hooks.json                   # Stop hook registration
│   └── stop-offer-new.sh            # Offers /hh:new after wrap-up
├── lib/
│   ├── parse-mapping.sh             # Markdown table → pipe-separated records
│   ├── resolve-org.sh               # cwd → org name
│   ├── resolve-service.sh           # cwd + org → app_name|lifeos_subpath
│   ├── ensure-symlink.sh            # Idempotent ln -sf with safety checks
│   └── initiation-template.md       # Template for /hh:init-org
├── tests/
│   └── fixtures/
│       ├── initiation-appier.md     # Realistic populated initiation file
│       ├── initiation-empty.md      # Heading present, no data rows
│       └── initiation-no-section.md # Missing Service Mapping heading
└── README.md
```

**Marketplace registration:** `.claude-plugin/marketplace.json` gets a new entry at the end (Task 13).

---

### Task 1: Plugin Scaffold

**Files:**
- Create: `handover-handler/.claude-plugin/plugin.json`
- Create: `handover-handler/README.md`

- [ ] **Step 1: Create directory structure**

```bash
cd /Users/williamhung/Projects/PersonalPlugins
mkdir -p handover-handler/.claude-plugin
mkdir -p handover-handler/commands
mkdir -p handover-handler/hooks
mkdir -p handover-handler/lib
mkdir -p handover-handler/tests/fixtures
```

- [ ] **Step 2: Write plugin.json**

Create `handover-handler/.claude-plugin/plugin.json`:

```json
{
  "name": "hh",
  "description": "LifeOS-as-SSOT handover document management via folder symlinks. Subsumes /op:wrap-up-today.",
  "version": "0.1.0",
  "author": {
    "name": "William Hung"
  }
}
```

The `name: "hh"` field controls the command namespace, so commands appear as `/hh:init-org` etc. The folder name stays `handover-handler/` for clarity.

- [ ] **Step 3: Write README**

Create `handover-handler/README.md`:

```markdown
# handover-handler

Bridge LifeOS ↔ each repo for cross-context handover documents. Subsumes `/op:wrap-up-today`.

## Why

LifeOS (Obsidian vault, iCloud-synced) is the source of truth for project handovers. Each repo gets a `./handover/` symlink into LifeOS so editors, grep, Obsidian, and Claude all see the same files. When you context-switch, the handover survives the switch.

## Commands

| Command | When to use |
|---|---|
| `/hh:init-org` | Once per org. Scaffolds `handover_handler__initiation.md` in `$LifeOS/01Project/$ORG/`. |
| `/hh:init-service` | Once per repo. Adds the repo to the service mapping table and creates the `./handover/` symlink. |
| `/hh:new <topic>` | Mid-task. Creates a well-formed handover under `./handover/`. |
| `/hh:wrap-up` | Daily. Vault-wide state-machine pass. States: `active`, `active-update`, `suspended`, `done`, `superseded`. |

## Plugin Configuration (env vars in `~/.zshrc`)

| Variable | Default | Description |
|---|---|---|
| `CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP` | `0` | When `1`, after a session that ran `/hh:wrap-up`, the Stop hook reminds Claude to offer `/hh:new`. |

## Vault Layout

```
$LifeOS/01Project/$ORG/
├── handover_handler__initiation.md   # frontmatter + Service Mapping table + clone block
└── Services/$APP_NAME/handover/      # symlink target for the repo's ./handover/
```

## Spec & Design

See `docs/superpowers/specs/2026-05-31-handover-handler-design.md` in the cc-plugins repo.
```

- [ ] **Step 4: Verify structure**

```bash
ls handover-handler/.claude-plugin/plugin.json handover-handler/README.md
```

Expected: both paths print, no errors.

- [ ] **Step 5: Commit**

```bash
git add handover-handler/.claude-plugin/plugin.json handover-handler/README.md
git commit -m "feat(handover-handler): scaffold plugin manifest and README"
```

---

### Task 2: initiation-template.md

**Files:**
- Create: `handover-handler/lib/initiation-template.md`

- [ ] **Step 1: Write the template**

Create `handover-handler/lib/initiation-template.md`:

```markdown
---
org: __ORG__
workspace_root: $HOME/Projects/__ORG__
github_orgs: []
tags: [handover-handler-init]
---

# __ORG__ — handover_handler initiation

## Service Mapping

| app_name | repo_path | lifeos_subpath |
| --- | --- | --- |

## One Prompt Clone

```bash
# Fill in: gh repo clone loop for github_orgs above.
# Example pattern:
#
# cd "$HOME/Projects/__ORG__"
# for org in <org1> <org2>; do
#   mkdir -p "$org"
#   gh repo list "$org" --limit 1000 --no-archived \
#        --json nameWithOwner -q '.[].nameWithOwner' \
#     | xargs -P 8 -I {} sh -c '
#         repo="$1"
#         if [ -d "$repo/.git" ]; then
#           printf "[%s] already cloned, skipping\n" "$repo"
#         else
#           gh repo clone "$repo" "$repo" 2>&1 | sed "s#^#[$repo] #"
#         fi
#       ' _ {}
# done
```

## Notes

<free-form notes about the org go here>
```

The `__ORG__` placeholder is replaced by `/hh:init-org` at scaffold time using `sed`.

- [ ] **Step 2: Smoke test the substitution**

```bash
sed 's/__ORG__/TestOrg/g' handover-handler/lib/initiation-template.md | head -5
```

Expected output (first 5 lines):
```
---
org: TestOrg
workspace_root: $HOME/Projects/TestOrg
github_orgs: []
tags: [handover-handler-init]
```

- [ ] **Step 3: Commit**

```bash
git add handover-handler/lib/initiation-template.md
git commit -m "feat(handover-handler): add initiation.md scaffold template"
```

---

### Task 3: parse-mapping.sh + fixtures

**Files:**
- Create: `handover-handler/tests/fixtures/initiation-appier.md`
- Create: `handover-handler/tests/fixtures/initiation-empty.md`
- Create: `handover-handler/tests/fixtures/initiation-no-section.md`
- Create: `handover-handler/lib/parse-mapping.sh`

`parse-mapping.sh` reads `## Service Mapping` markdown table and emits one pipe-separated record per data row.

- [ ] **Step 1: Write the populated fixture**

Create `handover-handler/tests/fixtures/initiation-appier.md`:

```markdown
---
org: Appier
workspace_root: $HOME/Projects/Appier
github_orgs: [plaxieappier, appier, william-hung-appier]
tags: [handover-handler-init]
---

# Appier — handover_handler initiation

## Service Mapping

| app_name        | repo_path                                       | lifeos_subpath           |
| --------------- | ----------------------------------------------- | ------------------------ |
| CreativeStudio  | $HOME/Projects/Appier/appier/creative-studio    | Services/CreativeStudio  |
| CrPerf2         | $HOME/Projects/Appier/appier/cr-perf-2          | Services/CrPerf2         |

## One Prompt Clone

```bash
# clone script here
```

## Notes
```

- [ ] **Step 2: Write the empty-table fixture**

Create `handover-handler/tests/fixtures/initiation-empty.md`:

```markdown
---
org: Ryocal
workspace_root: $HOME/Projects/Ryocal
github_orgs: []
tags: [handover-handler-init]
---

# Ryocal — handover_handler initiation

## Service Mapping

| app_name | repo_path | lifeos_subpath |
| --- | --- | --- |

## One Prompt Clone

```bash
# tbd
```

## Notes
```

- [ ] **Step 3: Write the no-section fixture**

Create `handover-handler/tests/fixtures/initiation-no-section.md`:

```markdown
---
org: Broken
workspace_root: $HOME/Projects/Broken
github_orgs: []
tags: [handover-handler-init]
---

# Broken — initiation

No Service Mapping section here.

## Notes

just notes
```

- [ ] **Step 4: Write the failing assertion (script doesn't exist yet)**

```bash
bash handover-handler/lib/parse-mapping.sh handover-handler/tests/fixtures/initiation-appier.md
```

Expected: error (`No such file or directory`).

- [ ] **Step 5: Implement parse-mapping.sh**

Create `handover-handler/lib/parse-mapping.sh`:

```bash
#!/usr/bin/env bash
# parse-mapping.sh — parse the "## Service Mapping" markdown table from an
# initiation.md file. Emits one pipe-separated record per data row to stdout:
#   <app_name>|<repo_path>|<lifeos_subpath>
# Whitespace is trimmed. $HOME and $LifeOS are NOT expanded — caller does that.
# Exit 0 even when table is empty or missing (caller handles).

set -euo pipefail

init_file="${1:?usage: parse-mapping.sh <path-to-initiation.md>}"

if [ ! -f "$init_file" ]; then
    echo "parse-mapping.sh: file not found: $init_file" >&2
    exit 2
fi

awk '
BEGIN { in_section=0; saw_header=0; saw_sep=0 }
/^## Service Mapping[[:space:]]*$/ { in_section=1; next }
/^## / && in_section { exit }
in_section && /^$/ && saw_sep { exit }
in_section && /^\|/ {
    if (!saw_header) { saw_header=1; next }
    if (!saw_sep)    { saw_sep=1;    next }
    n = split($0, cols, /[[:space:]]*\|[[:space:]]*/)
    out = ""
    for (i=2; i<n; i++) {
        if (out != "") out = out "|"
        out = out cols[i]
    }
    if (out != "") print out
}
' "$init_file"
```

```bash
chmod +x handover-handler/lib/parse-mapping.sh
```

- [ ] **Step 6: Verify against populated fixture**

```bash
bash handover-handler/lib/parse-mapping.sh handover-handler/tests/fixtures/initiation-appier.md
```

Expected stdout (exactly these two lines):
```
CreativeStudio|$HOME/Projects/Appier/appier/creative-studio|Services/CreativeStudio
CrPerf2|$HOME/Projects/Appier/appier/cr-perf-2|Services/CrPerf2
```

- [ ] **Step 7: Verify against empty-table fixture**

```bash
bash handover-handler/lib/parse-mapping.sh handover-handler/tests/fixtures/initiation-empty.md
echo "exit=$?"
```

Expected: no stdout, `exit=0`.

- [ ] **Step 8: Verify against no-section fixture**

```bash
bash handover-handler/lib/parse-mapping.sh handover-handler/tests/fixtures/initiation-no-section.md
echo "exit=$?"
```

Expected: no stdout, `exit=0`.

- [ ] **Step 9: Verify error on missing file**

```bash
bash handover-handler/lib/parse-mapping.sh /tmp/does-not-exist.md
echo "exit=$?"
```

Expected: stderr `parse-mapping.sh: file not found: ...`, `exit=2`.

- [ ] **Step 10: Commit**

```bash
git add handover-handler/lib/parse-mapping.sh handover-handler/tests/fixtures/
git commit -m "feat(handover-handler): add parse-mapping.sh and table fixtures"
```

---

### Task 4: resolve-org.sh

**Files:**
- Create: `handover-handler/lib/resolve-org.sh`

`resolve-org.sh` resolves the current org by trying git remote → workspace_root path prefix → exit 1 (caller falls back to AskUserQuestion).

- [ ] **Step 1: Write the failing assertion**

```bash
bash handover-handler/lib/resolve-org.sh
```

Expected: error (script doesn't exist).

- [ ] **Step 2: Implement resolve-org.sh**

Create `handover-handler/lib/resolve-org.sh`:

```bash
#!/usr/bin/env bash
# resolve-org.sh — resolve the current org by inspecting initiation files
# under $LifeOS/01Project/. Tries git remote first, then workspace_root prefix.
# Prints the org name to stdout on success, exits 1 if nothing matches.
#
# Optional env var: HH_LIFEOS_ROOT overrides the LifeOS path (for tests).

set -euo pipefail

LIFEOS="${HH_LIFEOS_ROOT:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS}"
PROJECT_ROOT="$LIFEOS/01Project"

if [ ! -d "$PROJECT_ROOT" ]; then
    echo "resolve-org.sh: LifeOS not reachable at $PROJECT_ROOT" >&2
    exit 3
fi

cwd="$(pwd)"
remote_url=""
if remote_url_try=$(git -C "$cwd" remote get-url origin 2>/dev/null); then
    remote_url="$remote_url_try"
fi

# Phase 1: git remote → github_orgs match
if [ -n "$remote_url" ]; then
    for init in "$PROJECT_ROOT"/*/handover_handler__initiation.md; do
        [ -f "$init" ] || continue
        org_dir="$(basename "$(dirname "$init")")"
        gh_orgs_line=$(awk '/^github_orgs:/{
            sub(/^github_orgs:[[:space:]]*\[/, "")
            sub(/\][[:space:]]*$/, "")
            print
            exit
        }' "$init")
        [ -n "$gh_orgs_line" ] || continue
        IFS=',' read -ra gh_orgs <<< "$gh_orgs_line"
        for o in "${gh_orgs[@]}"; do
            o="${o## }"; o="${o%% }"
            o="${o//\"/}"; o="${o//\'/}"
            [ -n "$o" ] || continue
            if [[ "$remote_url" == *"/$o/"* ]] || [[ "$remote_url" == *":$o/"* ]]; then
                echo "$org_dir"
                exit 0
            fi
        done
    done
fi

# Phase 2: workspace_root prefix match
for init in "$PROJECT_ROOT"/*/handover_handler__initiation.md; do
    [ -f "$init" ] || continue
    org_dir="$(basename "$(dirname "$init")")"
    workspace=$(awk '/^workspace_root:/{
        sub(/^workspace_root:[[:space:]]*/, "")
        print
        exit
    }' "$init")
    [ -n "$workspace" ] || continue
    workspace="${workspace//\$HOME/$HOME}"
    if [ "$cwd" = "$workspace" ] || [[ "$cwd" == "$workspace"/* ]]; then
        echo "$org_dir"
        exit 0
    fi
done

# No match
exit 1
```

```bash
chmod +x handover-handler/lib/resolve-org.sh
```

- [ ] **Step 3: Smoke test with fake LifeOS root (git remote path)**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Appier"
cp handover-handler/tests/fixtures/initiation-appier.md "$TMPDIR/01Project/Appier/handover_handler__initiation.md"

# Simulate a repo with appier remote
REPO=$(mktemp -d)
git -C "$REPO" init -q
git -C "$REPO" remote add origin "git@github.com:appier/creative-studio.git"

(cd "$REPO" && HH_LIFEOS_ROOT="$TMPDIR" bash "$OLDPWD/handover-handler/lib/resolve-org.sh")
echo "exit=$?"
rm -rf "$TMPDIR" "$REPO"
```

Expected: `Appier`, then `exit=0`.

- [ ] **Step 4: Smoke test with workspace_root prefix**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Appier"
cp handover-handler/tests/fixtures/initiation-appier.md "$TMPDIR/01Project/Appier/handover_handler__initiation.md"

# Create a dir under workspace_root, no git remote
REPO="$HOME/Projects/Appier/some-non-git-folder"
mkdir -p "$REPO"

(cd "$REPO" && HH_LIFEOS_ROOT="$TMPDIR" bash "$OLDPWD/handover-handler/lib/resolve-org.sh") || echo "no match"
echo "exit=$?"

rmdir "$REPO" 2>/dev/null || true
rm -rf "$TMPDIR"
```

Expected: `Appier`, then `exit=0`.

- [ ] **Step 5: Smoke test with no match**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Appier"
cp handover-handler/tests/fixtures/initiation-appier.md "$TMPDIR/01Project/Appier/handover_handler__initiation.md"

REPO=$(mktemp -d)
(cd "$REPO" && HH_LIFEOS_ROOT="$TMPDIR" bash "$OLDPWD/handover-handler/lib/resolve-org.sh") || echo "no match"
echo "exit=$?"
rm -rf "$TMPDIR" "$REPO"
```

Expected: `no match`, then `exit=1`.

- [ ] **Step 6: Commit**

```bash
git add handover-handler/lib/resolve-org.sh
git commit -m "feat(handover-handler): add resolve-org.sh with git-remote and path-prefix matching"
```

---

### Task 5: resolve-service.sh

**Files:**
- Create: `handover-handler/lib/resolve-service.sh`

`resolve-service.sh` takes cwd + org, parses the org's mapping table via `parse-mapping.sh`, and finds the row whose `repo_path` is `cwd` or contains `cwd` as a descendant. Longest match wins.

- [ ] **Step 1: Write the failing assertion**

```bash
bash handover-handler/lib/resolve-service.sh "$PWD" Appier
```

Expected: error (script doesn't exist).

- [ ] **Step 2: Implement resolve-service.sh**

Create `handover-handler/lib/resolve-service.sh`:

```bash
#!/usr/bin/env bash
# resolve-service.sh — given a cwd and an org, look up the app_name and
# lifeos_subpath from the org's Service Mapping table.
#
# Usage: resolve-service.sh <cwd> <org>
# Output: <app_name>|<lifeos_subpath> on stdout when matched.
# Exit codes:
#   0 — match found
#   1 — no match (caller asks the user)
#   2 — initiation.md missing for org
#   3 — LifeOS unreachable
#
# Optional env var: HH_LIFEOS_ROOT overrides the LifeOS path (for tests).

set -euo pipefail

cwd="${1:?usage: resolve-service.sh <cwd> <org>}"
org="${2:?usage: resolve-service.sh <cwd> <org>}"

LIFEOS="${HH_LIFEOS_ROOT:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS}"
PROJECT_ROOT="$LIFEOS/01Project"

if [ ! -d "$PROJECT_ROOT" ]; then
    echo "resolve-service.sh: LifeOS not reachable at $PROJECT_ROOT" >&2
    exit 3
fi

init="$PROJECT_ROOT/$org/handover_handler__initiation.md"
if [ ! -f "$init" ]; then
    echo "resolve-service.sh: initiation file missing: $init" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
records="$(bash "$SCRIPT_DIR/parse-mapping.sh" "$init")"
[ -n "$records" ] || exit 1

best_match=""
best_match_len=0

while IFS='|' read -r app_name repo_path lifeos_subpath; do
    [ -n "$app_name" ] || continue
    expanded="${repo_path//\$HOME/$HOME}"
    expanded="${expanded//\$LifeOS/$LIFEOS}"

    if [ "$cwd" = "$expanded" ]; then
        echo "$app_name|$lifeos_subpath"
        exit 0
    fi
    if [[ "$cwd" == "$expanded"/* ]]; then
        len=${#expanded}
        if [ "$len" -gt "$best_match_len" ]; then
            best_match="$app_name|$lifeos_subpath"
            best_match_len=$len
        fi
    fi
done <<< "$records"

if [ -n "$best_match" ]; then
    echo "$best_match"
    exit 0
fi
exit 1
```

```bash
chmod +x handover-handler/lib/resolve-service.sh
```

- [ ] **Step 3: Smoke test with exact match**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Appier"
cp handover-handler/tests/fixtures/initiation-appier.md "$TMPDIR/01Project/Appier/handover_handler__initiation.md"

HH_LIFEOS_ROOT="$TMPDIR" bash handover-handler/lib/resolve-service.sh \
    "$HOME/Projects/Appier/appier/creative-studio" Appier
echo "exit=$?"
rm -rf "$TMPDIR"
```

Expected: `CreativeStudio|Services/CreativeStudio`, then `exit=0`.

- [ ] **Step 4: Smoke test with descendant match (subdir of a mapped repo)**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Appier"
cp handover-handler/tests/fixtures/initiation-appier.md "$TMPDIR/01Project/Appier/handover_handler__initiation.md"

HH_LIFEOS_ROOT="$TMPDIR" bash handover-handler/lib/resolve-service.sh \
    "$HOME/Projects/Appier/appier/creative-studio/src/components" Appier
echo "exit=$?"
rm -rf "$TMPDIR"
```

Expected: `CreativeStudio|Services/CreativeStudio`, then `exit=0`.

- [ ] **Step 5: Smoke test with no match**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Appier"
cp handover-handler/tests/fixtures/initiation-appier.md "$TMPDIR/01Project/Appier/handover_handler__initiation.md"

HH_LIFEOS_ROOT="$TMPDIR" bash handover-handler/lib/resolve-service.sh \
    "$HOME/Projects/Appier/appier/something-unmapped" Appier || echo "no match"
echo "exit=$?"
rm -rf "$TMPDIR"
```

Expected: `no match`, then `exit=1`.

- [ ] **Step 6: Smoke test with missing initiation file**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/01Project/Ghost"

HH_LIFEOS_ROOT="$TMPDIR" bash handover-handler/lib/resolve-service.sh "$PWD" Ghost || echo "missing init"
echo "exit=$?"
rm -rf "$TMPDIR"
```

Expected: `missing init`, then `exit=2`.

- [ ] **Step 7: Commit**

```bash
git add handover-handler/lib/resolve-service.sh
git commit -m "feat(handover-handler): add resolve-service.sh with longest-prefix matching"
```

---

### Task 6: ensure-symlink.sh

**Files:**
- Create: `handover-handler/lib/ensure-symlink.sh`

`ensure-symlink.sh` creates or verifies a folder symlink, refusing to destroy data. Exit codes: 0 OK, 1 blocked by content, 3 target missing, 4 different-target symlink without force.

- [ ] **Step 1: Write the failing assertion**

```bash
bash handover-handler/lib/ensure-symlink.sh /tmp/x /tmp/y
```

Expected: error (script doesn't exist).

- [ ] **Step 2: Implement ensure-symlink.sh**

Create `handover-handler/lib/ensure-symlink.sh`:

```bash
#!/usr/bin/env bash
# ensure-symlink.sh — idempotently create a symlink at <link_path> pointing
# to <target>. Refuses to destroy data: if a non-empty directory or regular
# file exists at <link_path>, exits non-zero and reports.
#
# Usage: ensure-symlink.sh <link_path> <target> [force]
# Exit codes:
#   0 — created, or already correct, or empty-dir replaced
#   1 — blocked by existing content (non-empty dir or regular file)
#   3 — target does not exist
#   4 — symlink exists pointing elsewhere, and "force" was not specified

set -euo pipefail

link_path="${1:?usage: ensure-symlink.sh <link_path> <target> [force]}"
target="${2:?usage: ensure-symlink.sh <link_path> <target> [force]}"
mode="${3:-noforce}"

if [ ! -e "$target" ]; then
    echo "ensure-symlink.sh: target does not exist: $target" >&2
    exit 3
fi

if [ ! -e "$link_path" ] && [ ! -L "$link_path" ]; then
    ln -s "$target" "$link_path"
    echo "ensure-symlink.sh: created $link_path -> $target" >&2
    exit 0
fi

if [ -L "$link_path" ]; then
    current="$(readlink "$link_path")"
    if [ "$current" = "$target" ]; then
        echo "ensure-symlink.sh: already correct $link_path -> $target" >&2
        exit 0
    fi
    if [ "$mode" = "force" ]; then
        ln -sfn "$target" "$link_path"
        echo "ensure-symlink.sh: replaced $link_path -> $target (was: $current)" >&2
        exit 0
    fi
    echo "ensure-symlink.sh: $link_path -> $current (wanted: $target). Pass 'force' to overwrite." >&2
    exit 4
fi

if [ -d "$link_path" ]; then
    if [ -z "$(ls -A "$link_path" 2>/dev/null)" ]; then
        rmdir "$link_path"
        ln -s "$target" "$link_path"
        echo "ensure-symlink.sh: replaced empty dir $link_path -> $target" >&2
        exit 0
    fi
    echo "ensure-symlink.sh: directory exists with content: $link_path (move contents manually)" >&2
    exit 1
fi

echo "ensure-symlink.sh: regular file in the way: $link_path" >&2
exit 1
```

```bash
chmod +x handover-handler/lib/ensure-symlink.sh
```

- [ ] **Step 3: Smoke test happy path (link doesn't exist, target does)**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/target"
bash handover-handler/lib/ensure-symlink.sh "$TMPDIR/link" "$TMPDIR/target"
echo "exit=$?"
ls -l "$TMPDIR/link"
rm -rf "$TMPDIR"
```

Expected: `created` message, `exit=0`, ls shows symlink to target.

- [ ] **Step 4: Smoke test idempotency**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/target"
ln -s "$TMPDIR/target" "$TMPDIR/link"
bash handover-handler/lib/ensure-symlink.sh "$TMPDIR/link" "$TMPDIR/target"
echo "exit=$?"
rm -rf "$TMPDIR"
```

Expected: `already correct` message, `exit=0`.

- [ ] **Step 5: Smoke test different-target symlink without force**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/target1" "$TMPDIR/target2"
ln -s "$TMPDIR/target1" "$TMPDIR/link"
bash handover-handler/lib/ensure-symlink.sh "$TMPDIR/link" "$TMPDIR/target2" || echo "blocked"
echo "exit=$?"
rm -rf "$TMPDIR"
```

Expected: `Pass 'force' to overwrite` message, `blocked`, `exit=4`.

- [ ] **Step 6: Smoke test different-target with force**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/target1" "$TMPDIR/target2"
ln -s "$TMPDIR/target1" "$TMPDIR/link"
bash handover-handler/lib/ensure-symlink.sh "$TMPDIR/link" "$TMPDIR/target2" force
echo "exit=$?"
readlink "$TMPDIR/link"
rm -rf "$TMPDIR"
```

Expected: `replaced` message, `exit=0`, `readlink` shows target2.

- [ ] **Step 7: Smoke test non-empty dir blocks**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/target" "$TMPDIR/link"
touch "$TMPDIR/link/important.txt"
bash handover-handler/lib/ensure-symlink.sh "$TMPDIR/link" "$TMPDIR/target" || echo "blocked"
echo "exit=$?"
ls "$TMPDIR/link/important.txt"
rm -rf "$TMPDIR"
```

Expected: `move contents manually`, `blocked`, `exit=1`, `important.txt` still exists.

- [ ] **Step 8: Smoke test empty dir gets replaced**

```bash
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/target" "$TMPDIR/link"
bash handover-handler/lib/ensure-symlink.sh "$TMPDIR/link" "$TMPDIR/target"
echo "exit=$?"
ls -l "$TMPDIR/link"
rm -rf "$TMPDIR"
```

Expected: `replaced empty dir` message, `exit=0`, ls shows symlink.

- [ ] **Step 9: Commit**

```bash
git add handover-handler/lib/ensure-symlink.sh
git commit -m "feat(handover-handler): add ensure-symlink.sh with data-safety guards"
```

---

### Task 7: /hh:init-org command

**Files:**
- Create: `handover-handler/commands/init-org.md`

- [ ] **Step 1: Write the command**

Create `handover-handler/commands/init-org.md`:

```markdown
---
description: "Scaffold handover_handler__initiation.md for the current ORG in $LifeOS/01Project/$ORG/. One-time per ORG."
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion"]
---

# /hh:init-org

One-time setup per ORG. Creates `handover_handler__initiation.md` in `$LifeOS/01Project/$ORG/`. Safe to re-run — no-ops if already initialized.

## Vault location

```bash
LIFEOS="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

## Flow

### Phase 1 — Verify LifeOS reachable

```bash
[ -d "$LIFEOS/01Project" ] || { echo "LifeOS not reachable at $LIFEOS/01Project" >&2; exit 3; }
```

If unreachable, print the message and stop. Tell the user to check iCloud sync.

### Phase 2 — Resolve ORG

Run `bash ${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh` from the current working directory.

- **Exit 0 (org printed):** use that org name. Tell the user "Detected org: $ORG".
- **Exit 1 (no match):** list directories under `$LIFEOS/01Project/` (excluding `RawHandover/`), then `AskUserQuestion`:
  - `question`: "Which ORG should this initiation be for?"
  - `options`: one per existing directory, plus "New ORG (enter name)"
- **Exit 3 (LifeOS unreachable):** stop (already handled in Phase 1, but be defensive).

If the user picks "New ORG", follow up via `AskUserQuestion` with a free-form question for the ORG name (use a single option whose label is "Continue").

### Phase 3 — Check existing initiation.md

```bash
INIT="$LIFEOS/01Project/$ORG/handover_handler__initiation.md"
```

- If `$INIT` exists: report "Already initialized at $INIT" and stop.
- Otherwise continue.

### Phase 4 — Confirm with user

`AskUserQuestion`:
- `question`: "Scaffold initiation.md for $ORG?"
- `options`:
  - "Yes, scaffold the template"
  - "No, abort"

### Phase 5 — Write template

If confirmed:

```bash
mkdir -p "$LIFEOS/01Project/$ORG"
sed "s/__ORG__/$ORG/g" "${CLAUDE_PLUGIN_ROOT}/lib/initiation-template.md" > "$INIT"
```

### Phase 6 — Report

Print:
```
Scaffolded: $INIT

Next steps:
  1. Edit the file in Obsidian. Fill in:
     - github_orgs (frontmatter)
     - One Prompt Clone (bash block)
  2. Run /hh:init-service from each repo to populate the Service Mapping table.
```

## Non-negotiable rules

- Never overwrite an existing `handover_handler__initiation.md`. Always check first.
- Always use `${CLAUDE_PLUGIN_ROOT}/lib/initiation-template.md` as the source (do not inline the template — keep it editable in one place).
- Always confirm via `AskUserQuestion` before writing.
```

- [ ] **Step 2: Smoke test (read the command back)**

```bash
head -3 handover-handler/commands/init-org.md
```

Expected: yaml frontmatter visible.

- [ ] **Step 3: Commit**

```bash
git add handover-handler/commands/init-org.md
git commit -m "feat(handover-handler): add /hh:init-org command"
```

---

### Task 8: /hh:init-service command

**Files:**
- Create: `handover-handler/commands/init-service.md`

- [ ] **Step 1: Write the command**

Create `handover-handler/commands/init-service.md`:

```markdown
---
description: "Per-repo setup. Adds the current repo to the service mapping table and creates the ./handover symlink into LifeOS."
allowed-tools: ["Bash", "Read", "Write", "Edit", "AskUserQuestion"]
---

# /hh:init-service

One-time per repo. Resolves the current org, finds (or appends) the service mapping row for this repo, creates the LifeOS handover folder if missing, symlinks `./handover` to it, and ensures `.gitignore` covers it.

## Vault location

```bash
LIFEOS="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

## Flow

### Phase 1 — Resolve ORG

```bash
ORG=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh") || ORG=""
```

- If `$ORG` is empty: tell the user "Could not auto-detect ORG. Run /hh:init-org first if this is a new ORG, or use AskUserQuestion to pick from existing ORGs." Then `AskUserQuestion` listing existing ORG dirs under `$LIFEOS/01Project/`. If user picks one with no initiation.md, stop and instruct them to run `/hh:init-org $ORG` first.

Report: "Org: $ORG".

### Phase 2 — Verify initiation.md exists

```bash
INIT="$LIFEOS/01Project/$ORG/handover_handler__initiation.md"
[ -f "$INIT" ] || { echo "Run /hh:init-org first — $INIT missing"; exit 1; }
```

### Phase 3 — Resolve service mapping

```bash
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-service.sh" "$PWD" "$ORG") && EXIT=$? || EXIT=$?
```

- **Exit 0:** parse `app_name|lifeos_subpath` from `$RESULT`. Report "Mapped: $APP_NAME → $LIFEOS_SUBPATH" and skip to Phase 5.
- **Exit 1:** not mapped yet. Continue to Phase 4.
- **Exit 2 or 3:** report the error and stop.

### Phase 4 — Append new mapping row

Compute defaults:
- `DEFAULT_APP_NAME` = current directory name converted to PascalCase (e.g. `creative-studio` → `CreativeStudio`, `bust-backend` → `BustBackend`).
- `DEFAULT_LIFEOS_SUBPATH` = `Services/$DEFAULT_APP_NAME`.

`AskUserQuestion` (batched, 2 questions in a single call). The Q2 default uses `$DEFAULT_APP_NAME`, not the user's Q1 answer, because batched questions resolve simultaneously:

1. `header: "app_name"`, `question: "App name for this repo?"`, options: `[$DEFAULT_APP_NAME]`, `[Other...]`
2. `header: "lifeos path"`, `question: "LifeOS subpath under $ORG/?"`, options: `[Services/$DEFAULT_APP_NAME]`, `[Other...]`

For "Other..." answers, follow up with a free-form `AskUserQuestion`. If the user picked a non-default `app_name` in Q1 but accepted the default Q2 (`Services/$DEFAULT_APP_NAME`), prompt one more time: "Use `Services/<app_name>` instead?" → adjust accordingly.

Append a new row to the `## Service Mapping` table in `$INIT`:

```bash
# Compute a row like:
#   | NewApp          | $HOME/Projects/Appier/appier/new-app      | Services/NewApp           |
# Use a Python heredoc to align columns to existing widths if reliable;
# otherwise just append with single-space padding (Obsidian tables tolerate it).
```

Use `Edit` to append the new row after the last existing data row (or after the separator row if the table is empty). Preserve all other content.

### Phase 5 — Create LifeOS handover folder

```bash
mkdir -p "$LIFEOS/01Project/$ORG/$LIFEOS_SUBPATH/handover"
```

### Phase 6 — Symlink ./handover

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/ensure-symlink.sh" \
    "$PWD/handover" \
    "$LIFEOS/01Project/$ORG/$LIFEOS_SUBPATH/handover"
EXIT=$?
```

Handle exit codes:
- 0 — proceed.
- 1 — `./handover/` exists with content. Stop and report; do not destroy data.
- 4 — symlink exists pointing elsewhere. `AskUserQuestion`: `[Keep existing]`, `[Overwrite — force]`, `[Abort]`. If overwrite, re-run with `force`.

### Phase 7 — Ensure .gitignore

If `.gitignore` does not exist, create it with `handover/\n`.

Else, check whether `handover/` is already present (any of: `^handover/?$`, with or without leading whitespace). If missing, append `handover/` on a new line (with a separating blank line if file ends mid-content).

### Phase 8 — Report

```
✓ Service initialized:
    ORG:            $ORG
    APP_NAME:       $APP_NAME
    LIFEOS path:    $LIFEOS/01Project/$ORG/$LIFEOS_SUBPATH/handover/
    Symlink:        $PWD/handover -> (above)
    .gitignore:     handover/ (added | already present)

Next: /hh:new <topic>
```

## Non-negotiable rules

- Never destroy a non-empty `./handover/` directory. If conflict, stop and ask the user.
- Service mapping rows are append-only via this command — never rewrite existing rows.
- The .gitignore edit only adds `handover/`. It never removes or reorders existing lines.
- BustDice currently uses `Devops/` instead of `Services/`. If the user picks a non-`Services/` `lifeos_subpath`, warn but allow.
```

- [ ] **Step 2: Smoke test (validate frontmatter parses)**

```bash
head -5 handover-handler/commands/init-service.md
```

Expected: yaml frontmatter, then the H1.

- [ ] **Step 3: Commit**

```bash
git add handover-handler/commands/init-service.md
git commit -m "feat(handover-handler): add /hh:init-service command"
```

---

### Task 9: /hh:new command

**Files:**
- Create: `handover-handler/commands/new.md`

- [ ] **Step 1: Write the command**

Create `handover-handler/commands/new.md`:

```markdown
---
description: "Create a well-formed handover document under ./handover/ (= LifeOS via symlink) seeded from the current conversation context."
allowed-tools: ["Bash", "Read", "Write", "AskUserQuestion"]
argument-hint: "<topic>"
---

# /hh:new

Create a new handover document. The topic argument becomes the slug. Frontmatter, filename, and a seed body are filled in automatically. The new file lands under the canonical LifeOS path via the `./handover` symlink.

## Vault location

```bash
LIFEOS="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

## Flow

### Phase 1 — Verify the symlink

```bash
[ -L "./handover" ] || { echo "Run /hh:init-service first — ./handover is not a symlink."; exit 1; }
readlink -e "./handover" >/dev/null || { echo "LifeOS target unreachable — check iCloud sync."; exit 3; }
```

If either check fails, stop and report.

### Phase 2 — Resolve ORG + APP_NAME

```bash
ORG=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-org.sh") || { echo "Could not resolve ORG"; exit 1; }
RESULT=$(bash "${CLAUDE_PLUGIN_ROOT}/lib/resolve-service.sh" "$PWD" "$ORG") || { echo "Could not resolve service"; exit 1; }
APP_NAME="${RESULT%%|*}"
```

### Phase 3 — Build filename

- `TOPIC` = the slash-command argument (`$ARGUMENTS`). If missing, `AskUserQuestion` for a free-form topic.
- `PREFIX` = `$APP_NAME` converted from PascalCase/camelCase to kebab-case.
  - Examples: `CreativeStudio` → `creative-studio`, `CrPerf2` → `cr-perf-2`, `BustDice` → `bust-dice`, `bustBackend` → `bust-backend`.
  - Algorithm: insert `-` before each uppercase letter (except position 0), lowercase the result, collapse repeated `-`.
- `SLUG` = topic kebab-cased, lowercased, non-alphanumerics → `-`, collapsed repeats, trimmed to 60 chars.
- `DATE` = `$(date +%Y-%m-%d)`.
- `FILENAME` = `${PREFIX}__${DATE}-${SLUG}.md`.

### Phase 4 — Seed body

Read the current conversation context. Summarize the last few turns in 3–6 lines, focusing on:
- What we're working on (1 sentence).
- Relevant file paths or commands (bulleted).
- Open decisions or blockers (if any).

Build the file content:

```markdown
---
created: $DATE
project: $APP_NAME
status: open
tags:
  - handover
  - <PREFIX-as-tag>
---

# $APP_NAME — $TOPIC

## TL;DR

<one-line summary the user can fill in or refine>

## Context

<3–6 line summary you wrote from the conversation>

## What's next

- [ ] <suggested next step, blank if unclear>

## Notes
```

### Phase 5 — Write

```bash
TARGET="./handover/$FILENAME"
[ -e "$TARGET" ] && { echo "File already exists: $TARGET"; exit 1; }
```

Use `Write` to create the file at `$TARGET`.

### Phase 6 — Report

Print:
```
Created: $TARGET
  Resolved to LifeOS: $(readlink -e "$TARGET")

Open it in Obsidian to refine TL;DR / What's next.
```

## Non-negotiable rules

- Never overwrite an existing file. If filename collides, stop and report.
- Filename pattern is fixed: `<prefix>__<YYYY-MM-DD>-<slug>.md`. Do not invent variations.
- `tags` always includes `handover`. Never include `archive` here.
- `status: open` is the only initial status. Wrap-up changes it later.
```

- [ ] **Step 2: Smoke test (validate frontmatter)**

```bash
head -5 handover-handler/commands/new.md
```

Expected: yaml frontmatter visible.

- [ ] **Step 3: Commit**

```bash
git add handover-handler/commands/new.md
git commit -m "feat(handover-handler): add /hh:new command"
```

---

### Task 10: /hh:wrap-up command

**Files:**
- Create: `handover-handler/commands/wrap-up.md`

This command ports `/op:wrap-up-today` into the plugin with the reduced state set and the added `suspended` state. Most of the prompt content is preserved verbatim to keep behavior identical on archive-side actions.

- [ ] **Step 1: Write the command**

Create `handover-handler/commands/wrap-up.md`:

```markdown
---
description: "Vault-wide daily wrap-up. Discovers active handovers, batches user decisions, executes archives/updates/suspensions in parallel. Replaces /op:wrap-up-today."
allowed-tools: ["Bash", "Read", "Write", "Edit", "Glob", "Grep", "Agent", "AskUserQuestion"]
---

# /hh:wrap-up

Daily wrap-up routine for renewing handover docs in the Obsidian vault. Vault-wide, not repo-scoped.

## Vault location

```bash
VAULT="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
```

The vault is iCloud-synced across macOS machines. Always reference via `${HOME}` so the command works on every machine.

## What this command does

1. Discover active handovers (tagged `handover`, not `archive`).
2. Dispatch one subagent per handover **in parallel** to analyze state and suggest a default action.
3. Present a single batched table to the user; collect all decisions in one pass.
4. Execute archives, updates, and suspensions **in parallel** via subagents.
5. Update wikilinks in **living** docs only — leave historical records alone.
6. Print a `Wrap-up complete (<date>):` report. (The literal phrase `Wrap-up complete` is required — the Stop hook keys off it.)

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
VAULT="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"
grep -rl --include="*.md" -E "^[[:space:]]*-[[:space:]]+handover[[:space:]]*$" "$VAULT" 2>/dev/null \
| while IFS= read -r f; do
    grep -qE "^[[:space:]]*-[[:space:]]+archive[[:space:]]*$" "$f" || printf '%s\n' "$f"
  done
```

Expect 0–10 results. If the count is unexpectedly high (>15), warn the user and ask whether to proceed before spawning many subagents.

---

## Phase 2 — Parallel analysis (one subagent per handover)

Send all Agent calls in a **single message** so they run concurrently. Use `subagent_type: general-purpose`. Cap response to ~150 words each.

Subagent prompt template (substitute `<file>` and today's date):

> You are analyzing one Obsidian handover doc as part of a daily wrap-up routine. The vault is at `${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS`.
>
> File: `<file>`
> Today: `<YYYY-MM-DD>`
>
> Read the file and report under 150 words, structured as:
>
> 1. **Topic** — one-line summary.
> 2. **Project prefix** — derive from path. Examples:
>    - `01Project/BustDice/Services/...` → `bust-dice`
>    - filename references `CR-1660` → `CR-1660`
>    - otherwise short topic slug, e.g. `cs-domain`
> 3. **Visible state** — explicit `status:` field in frontmatter, plus checkbox completion ratio (`[x]` count / total).
> 4. **Suggested action** — pick ONE and explain in <20 words:
>    - `done` — work is complete; status reads done/complete/live/shipped
>    - `superseded` — newer handover replaces this one (name it if you can spot it)
>    - `suspended` — work paused; explicit `status: suspended` or visible indicators of indefinite hold
>    - `active` — still in progress, no fresh entry needed
>    - `active-update` — still in progress AND visible state suggests fresh entry today
> 5. **Suggested filename if archiving** — `<prefix>__<status>-<date>-<topic>.md`. Use today's date for `done`; original/inferred date for `superseded`.
> 6. **Cross-references** — incoming wikilinks. Run `grep -rl "\[\[<basename-no-ext>\]\]" "$VAULT"` and classify each result:
>    - `living` — active reference doc (pitfall notes, current handovers, deploy guides)
>    - `historical` — under `02-Area/Journal/`, or filename matches `^\d{4}-\d{2}-\d{2}` and lives in `handover/`/`meeting/`/etc.
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

Then ask via `AskUserQuestion` — one question per handover, all batched in a single tool call:

- `question`: `Handover #<N>: <basename>`
- `header`: `<basename truncated to ~12 chars>`
- `multiSelect`: false
- `options`:
  - `Active — no change`
  - `Active — append update`
  - `Active — suspend`
  - `Archive: done`
  - `Archive: superseded`
  - `Other` (custom action; will follow up)

For any answer of `Active — append update`, `Active — suspend`, or `Other`, send a follow-up `AskUserQuestion` to capture the update/suspend text or custom action.

If the suggested filename needs a `superseded by` reference, ask the user which doc supersedes it before naming.

---

## Phase 4 — Execute (parallel where possible)

Group user answers into:
- **archive set** (`Archive: done`, `Archive: superseded`)
- **update set** (`Active — append update`)
- **suspend set** (`Active — suspend`)
- **untouched set** (`Active — no change`)
- **custom set** (`Other` — handle inline; do NOT spawn subagents)

### 4a. Archive set — parallel subagents

For each handover, send one Agent call. Issue all calls in a single message.

Subagent prompt:

> Archive an Obsidian handover.
>
> Source: `<source-path>`
> Destination: `${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/04-Archive/<new-filename>`
> Living wikilink references: `<list-of-paths>`
> Historical wikilink references: `<list-of-paths>` (will be left broken intentionally)
>
> Steps:
> 1. Read the source file.
> 2. In the frontmatter `tags` list, append `- archive` (preserve other tags, no duplicates, preserve order).
> 3. Set the frontmatter `status:` field to the archive status (`done` or `superseded`).
> 4. Write the modified content to the destination path.
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
> 2. If a `## Updates` heading exists, append a new subsection. Otherwise, create the heading at the bottom (above any `## Cross-References` block; otherwise at the end).
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
> Reason (verbatim, may be empty):
> ```
> <user-supplied-reason>
> ```
>
> Steps:
> 1. Read the file.
> 2. In frontmatter, set `status: suspended` (insert the field if missing; overwrite existing status).
> 3. Append a `## Suspended` section at the end of the file:
>    ```
>    ## Suspended
>    ### <YYYY-MM-DD>
>    <user-reason if non-empty, else "paused — no reason given">
>    ```
>    If `## Suspended` already exists, append a new `### <YYYY-MM-DD>` subsection under it.
> 4. Do NOT change tags. The file keeps `handover`, does NOT get `archive`.
>
> Report: `{ file, action: "suspended" | "re-suspended" }`.

### 4d. Custom set — handle inline

For `Other` answers, present the user-supplied custom action back to the user and ask for confirmation before executing. Do not spawn a subagent for these.

---

## Phase 5 — Report

After all subagents return, print exactly the phrase `Wrap-up complete` on the first line (the Stop hook depends on this):

```
Wrap-up complete (<YYYY-MM-DD>):

Archived (<N>):
- <old-basename> → 04-Archive/<new-basename>
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

- **Naming convention**: `<prefix>__<status>-[date-]<topic>.md`, status ∈ {`done`, `superseded`}. Date is `YYYY-MM-DD`.
- **Add `archive` tag**: append to existing tags list. Never replace, never reorder other tags.
- **Don't edit historical records**: journals (`02-Area/Journal/**`), dated handovers (`^\d{4}-\d{2}-\d{2}-*.md` inside `handover/`/`meeting/`/etc.). Broken wikilinks in these files are an honest signal of a rename.
- **No generic aliases**: do not add `aliases:` to the archived file as a workaround for broken wikilinks. If genuinely needed, scope it explicitly.
- **Update wikilinks in living docs only**: pitfall notes, current handovers, active references, deploy guides.
- **Active updates only append content**: only a dated subsection. Don't add tags, don't change frontmatter, don't mark "still active" anywhere.
- **Suspended state never archives**: `suspended` is an active-side state. The file keeps `handover` tag, does NOT get `archive`.
- **Stop and ask** when project prefix is ambiguous, when a `superseded` action requires naming the replacing doc, or when a cross-reference scan finds a file that's hard to classify.
- **Phase 5 output must contain the literal phrase `Wrap-up complete`** — the Stop hook keys off it.
```

- [ ] **Step 2: Smoke test (validate frontmatter)**

```bash
head -5 handover-handler/commands/wrap-up.md
```

Expected: yaml frontmatter visible.

- [ ] **Step 3: Commit**

```bash
git add handover-handler/commands/wrap-up.md
git commit -m "feat(handover-handler): add /hh:wrap-up command (ports /op:wrap-up-today)"
```

---

### Task 11: Stop hook — hooks.json + stop-offer-new.sh

**Files:**
- Create: `handover-handler/hooks/hooks.json`
- Create: `handover-handler/hooks/stop-offer-new.sh`

- [ ] **Step 1: Write hooks.json**

Create `handover-handler/hooks/hooks.json`:

```json
{
  "description": "Offer /hh:new after a wrap-up session ends (opt-in via CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1)",
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash '${CLAUDE_PLUGIN_ROOT}/hooks/stop-offer-new.sh'",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Write stop-offer-new.sh**

Create `handover-handler/hooks/stop-offer-new.sh`:

```bash
#!/usr/bin/env bash
# stop-offer-new.sh — Claude Code Stop hook.
# When CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1, scans the recent transcript for a
# /hh:wrap-up run that completed, and emits a hookSpecificOutput.additionalContext
# message asking Claude to offer /hh:new via AskUserQuestion.
#
# Disabled by default. Set CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1 in ~/.zshrc to enable.

set -euo pipefail

[ "${CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP:-0}" = "1" ] || exit 0

payload="$(cat)"

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

transcript_path=$(printf '%s' "$payload" | jq -r '.transcript_path // empty')
[ -n "$transcript_path" ] && [ -f "$transcript_path" ] || exit 0

recent="$(tail -200 "$transcript_path" 2>/dev/null || true)"
[ -n "$recent" ] || exit 0

# Heuristic: user invoked /hh:wrap-up AND assistant printed "Wrap-up complete"
echo "$recent" | grep -q '/hh:wrap-up' || exit 0
echo "$recent" | grep -q 'Wrap-up complete' || exit 0

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Reminder: /hh:wrap-up just ran. Ask the user via AskUserQuestion whether they'd like to start a new handover with /hh:new for any new threads of work surfaced by the wrap-up. Single question, two options: 'Yes — /hh:new <topic>' / 'No — done for today'."}}
JSON
```

```bash
chmod +x handover-handler/hooks/stop-offer-new.sh
```

- [ ] **Step 3: Smoke test the hook script directly**

Build a fake transcript and payload:

```bash
TMPDIR=$(mktemp -d)
TRANSCRIPT="$TMPDIR/transcript.jsonl"
cat > "$TRANSCRIPT" <<'EOF'
{"type":"user","content":"/hh:wrap-up"}
{"type":"assistant","content":"Wrap-up complete (2026-05-31):\n\nArchived (2): ..."}
EOF

# Hook disabled by default — should emit nothing
echo "{\"transcript_path\":\"$TRANSCRIPT\"}" | bash handover-handler/hooks/stop-offer-new.sh
echo "exit(disabled)=$?"

# Hook enabled — should emit JSON
echo "{\"transcript_path\":\"$TRANSCRIPT\"}" | CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1 bash handover-handler/hooks/stop-offer-new.sh
echo "exit(enabled)=$?"

# Hook enabled but no wrap-up in transcript — should emit nothing
echo "{}" > "$TMPDIR/no-wrap.jsonl"
echo "{\"type\":\"user\",\"content\":\"hello\"}" > "$TMPDIR/no-wrap.jsonl"
echo "{\"transcript_path\":\"$TMPDIR/no-wrap.jsonl\"}" | CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1 bash handover-handler/hooks/stop-offer-new.sh
echo "exit(no-wrap)=$?"

rm -rf "$TMPDIR"
```

Expected:
- Disabled: no stdout, `exit(disabled)=0`.
- Enabled with wrap-up: JSON with `hookSpecificOutput`, `exit(enabled)=0`.
- Enabled, no wrap-up: no stdout, `exit(no-wrap)=0`.

- [ ] **Step 4: Commit**

```bash
git add handover-handler/hooks/hooks.json handover-handler/hooks/stop-offer-new.sh
git commit -m "feat(handover-handler): add Stop hook that offers /hh:new after wrap-up"
```

---

### Task 12: Register plugin in marketplace

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Read current marketplace.json**

```bash
cat .claude-plugin/marketplace.json
```

Confirm three plugins are registered: `session-learner`, `autoresearch`, `remotion-maker`.

- [ ] **Step 2: Append handover-handler entry**

Edit `.claude-plugin/marketplace.json`. Inside the `plugins` array, after the `remotion-maker` block (preserving its trailing comma if needed), add:

```json
    {
      "name": "handover-handler",
      "source": "./handover-handler",
      "description": "LifeOS-as-SSOT handover document management via folder symlinks. Subsumes /op:wrap-up-today.",
      "version": "0.1.0",
      "strict": true
    }
```

After editing, the `plugins` array has four entries with consistent comma placement.

- [ ] **Step 3: Bump marketplace version**

In `.claude-plugin/marketplace.json`, change:

```json
  "metadata": {
    "description": "Knowledge management and workflow automation plugins for Claude Code",
    "version": "1.2.0"
  },
```

to:

```json
  "metadata": {
    "description": "Knowledge management and workflow automation plugins for Claude Code",
    "version": "1.3.0"
  },
```

- [ ] **Step 4: Validate JSON syntax**

```bash
cat .claude-plugin/marketplace.json | python3 -m json.tool > /dev/null && echo "valid"
```

Expected: `valid`.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "sync: register handover-handler 0.1.0 in marketplace (bump to 1.3.0)"
```

---

### Task 13: End-to-end smoke run

This task is **manual verification** on real LifeOS state. No code changes; just a structured walkthrough to confirm the plugin works as designed. Do not skip — each command has subtle interactions only visible in real use.

- [ ] **Step 1: Install the plugin locally**

```bash
# Reload the marketplace so the new plugin shows up
# (exact reload mechanism depends on the user's Claude Code setup; in most
# cases, restarting Claude Code or running /plugin reload is sufficient)
```

Verify the plugin loaded by checking that `/hh:init-org`, `/hh:init-service`, `/hh:new`, `/hh:wrap-up` appear in the slash-command list.

- [ ] **Step 2: Smoke `/hh:init-org` on Ryocal (no initiation.md exists)**

```bash
cd ~/Projects   # any path outside known orgs
/hh:init-org
```

Expected flow: `resolve-org.sh` fails → `AskUserQuestion` lists existing orgs → pick `Ryocal` → confirm scaffold → `$LifeOS/01Project/Ryocal/handover_handler__initiation.md` created.

Verify:

```bash
ls "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/01Project/Ryocal/handover_handler__initiation.md"
```

- [ ] **Step 3: Re-run `/hh:init-org` on Ryocal (already initialized)**

Expected: prints "Already initialized" and exits without writing.

- [ ] **Step 4: Smoke `/hh:init-service` on a known Appier repo**

```bash
cd ~/Projects/Appier/appier/<some-creative-studio-repo>  # if you have one
/hh:init-service
```

Expected:
- `resolve-org.sh` returns `Appier` (via git remote match).
- `resolve-service.sh` either matches (if mapping already covers this repo) or exits 1.
- On no-match, `AskUserQuestion` prompts for app_name + lifeos_subpath; mapping row appended.
- `mkdir -p` creates the LifeOS handover folder.
- `./handover` symlinked into LifeOS.
- `.gitignore` has `handover/`.

Verify:

```bash
ls -la ./handover
readlink -e ./handover
grep '^handover/$' .gitignore
```

- [ ] **Step 5: Re-run `/hh:init-service` (idempotency)**

Expected: `ensure-symlink.sh` reports "already correct"; no duplicate mapping row; `.gitignore` unchanged.

- [ ] **Step 6: Smoke `/hh:new "smoke test handover"`**

```bash
/hh:new "smoke test handover"
```

Expected: a file appears under `./handover/<prefix>__<date>-smoke-test-handover.md` with frontmatter, the seed sections, and `tags: [handover, <prefix>]`.

Verify:

```bash
ls ./handover/
cat ./handover/*smoke-test-handover.md | head -20
```

- [ ] **Step 7: Smoke `/hh:wrap-up` with the test file**

```bash
/hh:wrap-up
```

Expected: discover finds the smoke-test file (and any other active handovers); analyzer subagent reports; user prompted; user picks `Archive: done`; file moves to `$LifeOS/04-Archive/...`; report contains `Wrap-up complete`.

Verify:

```bash
ls "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/04-Archive/" | grep smoke-test
```

- [ ] **Step 8: Smoke the Stop hook**

In `~/.zshrc`:

```bash
export CLAUDE_HH_OFFER_NEW_AFTER_WRAPUP=1
```

Open a new Claude Code session in any repo, run `/hh:wrap-up`, wait for it to complete, then end the response. The next-turn context (or visible behavior) should include the offer to run `/hh:new`.

- [ ] **Step 9: Document any failures**

If any step fails, capture the failure mode and either fix it (and re-run from the failing step) or open a follow-up task with the exact reproduction.

- [ ] **Step 10: No commit needed** — this task is verification only.

---

### Task 14: Migration — retire /op:wrap-up-today

This task happens **after** Task 13 confirms parity. Do not do this earlier.

**Files:**
- Delete: `~/.claude/commands/op/wrap-up-today.md`

- [ ] **Step 1: Confirm /hh:wrap-up has been run successfully at least twice on real data**

Check `$LifeOS/04-Archive/` and the wrap-up reports. If both runs produced expected output with no surprises, proceed.

- [ ] **Step 2: Move the old command to a backup location**

```bash
mkdir -p "$HOME/.claude/commands/_retired"
mv "$HOME/.claude/commands/op/wrap-up-today.md" "$HOME/.claude/commands/_retired/wrap-up-today.md.bak"
```

(Move, not delete — recoverable for at least a week.)

- [ ] **Step 3: Verify the old command no longer shows up in slash-command listing**

Restart Claude Code or reload commands. `/op:wrap-up-today` should no longer appear.

- [ ] **Step 4: After one week of stable use, delete the backup**

```bash
rm "$HOME/.claude/commands/_retired/wrap-up-today.md.bak"
```

- [ ] **Step 5: No commit needed** — these are user-level changes outside this repo.

---

## Self-Review (run after all tasks complete)

Verify each spec section maps to a task:

- ✅ Plugin Structure → Tasks 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
- ✅ Vault Layout → Task 7 (init-org creates `$LifeOS/01Project/$ORG/handover_handler__initiation.md`); Task 8 (init-service creates `Services/$APP_NAME/handover/`)
- ✅ Commands → Tasks 7, 8, 9, 10
- ✅ Data Model (frontmatter + mapping table) → Task 2 (template), Task 3 (parser)
- ✅ State Machine → Task 10 (5 active/archive options + Other)
- ✅ Symlink Contract → Task 6 (ensure-symlink), Task 8 (Phase 6)
- ✅ Hook (stop-offer-new) → Task 11
- ✅ Org Resolution → Task 4
- ✅ Service Resolution → Task 5
- ✅ Edge Cases → Task 6 (data-safety guards), Task 8 (.gitignore handling, BustDice Devops/ warning), Task 10 (high-count warning, prefix ambiguity, superseded naming)
- ✅ Out of Scope → respected (no cross-platform layer, no auto-cloning, no `pickup`, no auto-`follow_up`)
- ✅ Migration from /op:wrap-up-today → Task 14
- ✅ Marketplace registration → Task 12
- ✅ Testing Strategy → Task 13 (manual smoke tests per command)

No spec requirement is left untouched.

---
