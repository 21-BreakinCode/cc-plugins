# code-reviewer History-Learner + Review-Determinism Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `code-reviewer` into a closed loop — add a `refresh-principles` producer skill that mines git + PR history (including reviewer↔author threads) into the `01–07` principle files, plus deterministic coverage guards on the existing `review-pr` pass.

**Architecture:** Four new bash libs do deterministic mining/guards (git log, `gh`, diff parsing). A new user-invoked skill orchestrates: mine → thin-LLM distill (precision-first, every entry cites its source) → propose-diff → user approves → write → advance a watermark stored in the principle dir. The existing orchestrator agent gains a coverage pre-pass and finding line-ref validation.

**Tech Stack:** Bash (`set -euo pipefail`), `jq`, `git`, GitHub CLI (`gh`). Markdown skill/agent files. Offline bash tests with fixtures + a throwaway git repo.

## Global Constraints

- **Bundled paths:** commands/agents/skills reference bundled files via `${CLAUDE_PLUGIN_ROOT}/...`; lib→sibling sourcing uses `$(dirname "${BASH_SOURCE[0]}")/...`. Never `find ~/.claude/plugins`.
- **No cross-plugin references** — no sourcing/dispatching another plugin's files.
- **Platform:** GitHub only, via `gh`. `jq` required. Every script starts `set -euo pipefail`.
- **Precision-first:** a principle entry is emitted ONLY with a citation (PR#/SHA/comment-url). No citation ⇒ reject before showing the diff.
- **Propose-then-approve:** never write principle files without showing a unified diff and getting user approval.
- **Merged PRs only.** Watermark cursor = `mergedAt` timestamp (primary), merge SHA (secondary).
- **Watermark advances ONLY after an approved write.** (Idempotent re-runs, resumable backfill, decline-safe.)
- **Atomic writes** (temp + `mv`). Never auto-commit the principle directory (it may be someone's LifeOS repo).
- **Versioning:** bump `0.2.0 → 0.3.0` in BOTH `.claude-plugin/marketplace.json` (code-reviewer entry) and `code-reviewer/.claude-plugin/plugin.json`. Regenerate docs with `./scripts/cicd.sh GEN`; never hand-edit `README.md`/`CATALOG.md`.
- **Tests are offline** — fixtures or a throwaway git repo, no network.
- **Commit messages:** conventional (`feat:`/`test:`/`docs:`/`chore:`) and end with the trailer `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **Branch:** all work on `feat/code-reviewer-history-learner` (already created).

## File Structure

```
code-reviewer/
├── skills/refresh-principles/
│   ├── SKILL.md                     Task 5  user-invoked producer orchestration
│   └── references/
│       └── principle-file-format.md Task 5  entry schema + citation rule
├── lib/
│   ├── learn-state.sh               Task 1  watermark read/write
│   ├── mine-git-signals.sh          Task 2  reverts · hotfixes · churn
│   ├── mine-pr-signals.sh           Task 3  merged PRs + threads + comment→change
│   └── check-diff-coverage.sh       Task 4  coverage + finding line-ref validation
├── agents/pr-review-orchestrator.md Task 6  MOD: coverage pre-pass + validation
└── tests/
    ├── _assert.sh                   Task 1  shared assert helper
    ├── test_learn_state.sh          Task 1
    ├── test_mine_git_signals.sh     Task 2
    ├── test_mine_pr_signals.sh      Task 3
    ├── test_check_diff_coverage.sh  Task 4
    ├── test_principle_format.sh     Task 5
    └── fixtures/gh/                  Tasks 3–4  canned gh JSON + diff
```

Release wiring (version bump + content + GEN) is Task 7.

---

### Task 1: Watermark state lib + test harness

**Files:**
- Create: `code-reviewer/tests/_assert.sh`
- Create: `code-reviewer/lib/learn-state.sh`
- Test: `code-reviewer/tests/test_learn_state.sh`

**Interfaces:**
- Produces: `learn-state.sh read <principle-dir>` → JSON on stdout (empty string if no state). `learn-state.sh write <principle-dir> <last_merged_at> <last_sha> <counts-json>` → writes `<dir>/.learn-state.json` atomically, echoes its path. JSON shape: `{version,last_merged_at,last_merged_sha,counts,generated_at}`.

- [ ] **Step 1: Write the shared assert helper**

`code-reviewer/tests/_assert.sh`:
```bash
#!/usr/bin/env bash
# Shared assert helper for code-reviewer bash tests.
PASS=0; FAIL=0
assert() {  # <label> <condition-string>
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}
finish() { echo ""; echo "Passed: $PASS  Failed: $FAIL"; [ "$FAIL" -eq 0 ]; }
```

- [ ] **Step 2: Write the failing test**

`code-reviewer/tests/test_learn_state.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/learn-state.sh"

tmp="$(mktemp -d)"
echo "Test: empty read prints nothing"
out="$(bash "$LIB" read "$tmp")"
assert "empty read is blank" '[ -z "$out" ]'

echo "Test: write then read round-trips"
sf="$(bash "$LIB" write "$tmp" "2026-08-01T12:00:00Z" "abc1234" '{"07-red-flags":2}')"
assert "state file created" '[ -f "$sf" ]'
got="$(bash "$LIB" read "$tmp")"
assert "last_merged_at persisted" '[ "$(echo "$got" | jq -r .last_merged_at)" = "2026-08-01T12:00:00Z" ]'
assert "last_merged_sha persisted" '[ "$(echo "$got" | jq -r .last_merged_sha)" = "abc1234" ]'
assert "counts persisted" '[ "$(echo "$got" | jq -r ".counts.\"07-red-flags\"")" = "2" ]'
rm -rf "$tmp"
finish
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash code-reviewer/tests/test_learn_state.sh`
Expected: FAIL — `learn-state.sh` does not exist yet (`No such file`).

- [ ] **Step 4: Implement the lib**

`code-reviewer/lib/learn-state.sh`:
```bash
#!/usr/bin/env bash
# learn-state.sh — per-principle-dir learn watermark.
#   learn-state.sh read  <principle-dir>                 → JSON (empty if none)
#   learn-state.sh write <principle-dir> <merged_at> <sha> <counts-json> → path
set -euo pipefail
cmd="${1:-}"; dir="${2:-}"
die() { echo "$1" >&2; exit "${2:-1}"; }
[[ -n "$cmd" && -n "$dir" ]] || die "usage: learn-state.sh <read|write> <principle-dir> [...]" 64
command -v jq &>/dev/null || die "jq required: brew install jq" 2
state_file="$dir/.learn-state.json"

case "$cmd" in
  read)
    [[ -f "$state_file" ]] && cat "$state_file" || true
    ;;
  write)
    [[ -d "$dir" ]] || die "principle dir not found: $dir" 2
    merged_at="${3:-}"; sha="${4:-}"; counts="${5:-{}}"
    tmp="$(mktemp)"
    jq -n --arg at "$merged_at" --arg sha "$sha" --argjson counts "$counts" \
          --arg gen "$(date -u +%FT%TZ)" \
      '{version:1, last_merged_at:$at, last_merged_sha:$sha, counts:$counts, generated_at:$gen}' \
      > "$tmp"
    mv "$tmp" "$state_file"
    echo "$state_file"
    ;;
  *) die "unknown command: $cmd" 64 ;;
esac
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash code-reviewer/tests/test_learn_state.sh`
Expected: PASS — 5 asserts pass, `Failed: 0`.

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/tests/_assert.sh code-reviewer/tests/test_learn_state.sh code-reviewer/lib/learn-state.sh
git commit -m "feat(code-reviewer): add learn-state watermark lib + test harness

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Git-signal miner

**Files:**
- Create: `code-reviewer/lib/mine-git-signals.sh`
- Test: `code-reviewer/tests/test_mine_git_signals.sh`

**Interfaces:**
- Produces: `mine-git-signals.sh <since> [<until>]` (`<since>` = a git rev OR a date like `2026-02-01`) → JSON `{reverts:[{sha,subject}], hotfixes:[{sha,subject}], churn:[{file,commits}]}` sorted by churn desc.

- [ ] **Step 1: Write the failing test**

`code-reviewer/tests/test_mine_git_signals.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/mine-git-signals.sh"

tmp="$(mktemp -d)"; ( cd "$tmp"
  git init -q && git config user.email t@t && git config user.name t
  echo a >  f1; git add .; git commit -qm "feat: add f1"
  echo b >> f1; git add .; git commit -qm "fix: correct f1 bug"
  echo c >  f2; git add .; git commit -qm "feat: add f2"
  echo d >> f1; git add .; git commit -qm 'Revert "feat: add f1"'
)
out="$(cd "$tmp" && bash "$LIB" 2000-01-01)"
assert "one revert found"      '[ "$(echo "$out" | jq ".reverts|length")" = "1" ]'
assert "at least one hotfix"   '[ "$(echo "$out" | jq ".hotfixes|length")" -ge "1" ]'
assert "f1 is top churn file"  '[ "$(echo "$out" | jq -r ".churn[0].file")" = "f1" ]'
rm -rf "$tmp"
finish
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash code-reviewer/tests/test_mine_git_signals.sh`
Expected: FAIL — `mine-git-signals.sh` not found.

- [ ] **Step 3: Implement the lib**

`code-reviewer/lib/mine-git-signals.sh`:
```bash
#!/usr/bin/env bash
# mine-git-signals.sh <since> [<until>] — deterministic commit signals.
#   <since> may be a git rev (uses <since>..<until>) or a date (uses --since).
# stdout JSON: {reverts, hotfixes, churn}
set -euo pipefail
since="${1:-}"; until_ref="${2:-HEAD}"
[[ -n "$since" ]] || { echo "usage: mine-git-signals.sh <since> [until]" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }
git rev-parse --git-dir &>/dev/null || { echo "not a git repo" >&2; exit 2; }

if git rev-parse --verify --quiet "${since}^{commit}" >/dev/null 2>&1; then
  range=("${since}..${until_ref}")
else
  range=("--since=${since}")
fi

log_kv() { git log "${range[@]}" --pretty='%H%x09%s'; }

reverts=$(log_kv | awk -F'\t' 'tolower($2) ~ /^revert/ {print}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{sha:.[0],subject:.[1]})')

hotfixes=$(log_kv | awk -F'\t' 'tolower($2) ~ /(^|[^a-z])(fix|hotfix|bugfix)/ {print}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{sha:.[0],subject:.[1]})')

churn=$(git log "${range[@]}" --name-only --pretty=format: \
  | sed '/^$/d' | sort | uniq -c | sort -rn \
  | awk '{printf "%s\t%s\n",$1,$2}' \
  | jq -R -s 'split("\n")|map(select(length>0)|split("\t")|{file:.[1],commits:(.[0]|tonumber)})')

jq -n --argjson r "$reverts" --argjson h "$hotfixes" --argjson c "$churn" \
  '{reverts:$r, hotfixes:$h, churn:$c}'
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash code-reviewer/tests/test_mine_git_signals.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add code-reviewer/lib/mine-git-signals.sh code-reviewer/tests/test_mine_git_signals.sh
git commit -m "feat(code-reviewer): add git-signal miner (reverts/hotfixes/churn)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: PR-signal miner (with offline fixture seam)

**Files:**
- Create: `code-reviewer/lib/mine-pr-signals.sh`
- Create: `code-reviewer/tests/fixtures/gh/pr-list.json`
- Create: `code-reviewer/tests/fixtures/gh/pr-101.json`
- Test: `code-reviewer/tests/test_mine_pr_signals.sh`

**Interfaces:**
- Consumes: nothing from prior tasks.
- Produces: `mine-pr-signals.sh <base-branch> <since-date> [<until-date>]` → JSON array; each element `{number,title,mergedAt,mergeCommit,reviews:[{state,author}],comments:[{path,line,body,url,author,caused_change}]}`. `caused_change=true` when the comment's `path` is among the PR's changed files.
- **Test seam:** if `CODE_REVIEWER_GH_FIXTURE_DIR` is set, reads `<dir>/pr-list.json` and `<dir>/pr-<N>.json` instead of calling `gh`.

- [ ] **Step 1: Write the fixtures**

`code-reviewer/tests/fixtures/gh/pr-list.json`:
```json
[{"number":101,"title":"Add auth guard","mergedAt":"2026-07-01T00:00:00Z","mergeCommit":{"oid":"deadbee"}}]
```

`code-reviewer/tests/fixtures/gh/pr-101.json`:
```json
{
  "number":101,
  "reviews":[{"state":"CHANGES_REQUESTED","author":{"login":"reviewer1"}}],
  "files":[{"path":"src/auth.ts"}],
  "comments":[
    {"path":"src/auth.ts","line":10,"body":"missing null check","url":"https://x/c1","author":{"login":"reviewer1"}},
    {"path":"src/other.ts","line":3,"body":"nit","url":"https://x/c2","author":{"login":"reviewer1"}}
  ]
}
```

- [ ] **Step 2: Write the failing test**

`code-reviewer/tests/test_mine_pr_signals.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/mine-pr-signals.sh"
export CODE_REVIEWER_GH_FIXTURE_DIR="$DIR/fixtures/gh"

out="$(bash "$LIB" main 2026-01-01)"
assert "one merged PR" '[ "$(echo "$out" | jq length)" = "1" ]'
assert "changed-file comment caused_change=true" \
  '[ "$(echo "$out" | jq -r ".[0].comments[]|select(.path==\"src/auth.ts\")|.caused_change")" = "true" ]'
assert "unchanged-file comment caused_change=false" \
  '[ "$(echo "$out" | jq -r ".[0].comments[]|select(.path==\"src/other.ts\")|.caused_change")" = "false" ]'
assert "review state carried" \
  '[ "$(echo "$out" | jq -r ".[0].reviews[0].state")" = "CHANGES_REQUESTED" ]'
finish
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash code-reviewer/tests/test_mine_pr_signals.sh`
Expected: FAIL — `mine-pr-signals.sh` not found.

- [ ] **Step 4: Implement the lib**

`code-reviewer/lib/mine-pr-signals.sh`:
```bash
#!/usr/bin/env bash
# mine-pr-signals.sh <base> <since-date> [<until-date>] — merged-PR signals via gh.
# Offline test seam: CODE_REVIEWER_GH_FIXTURE_DIR → <dir>/pr-list.json, <dir>/pr-<N>.json
set -euo pipefail
base="${1:-}"; since="${2:-}"; until_date="${3:-}"
[[ -n "$base" && -n "$since" ]] || { echo "usage: mine-pr-signals.sh <base> <since> [until]" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }
fx="${CODE_REVIEWER_GH_FIXTURE_DIR:-}"

_pr_list() {
  if [[ -n "$fx" ]]; then cat "$fx/pr-list.json"; return; fi
  command -v gh &>/dev/null || { echo "gh required: https://cli.github.com" >&2; exit 2; }
  local q="merged:>=$since base:$base"; [[ -n "$until_date" ]] && q="$q merged:<=$until_date"
  gh pr list --state merged --search "$q" --limit 100 \
    --json number,title,mergedAt,mergeCommit
}
_pr_detail() {  # $1 = PR number → {number,reviews,files,comments}
  local n="$1"
  if [[ -n "$fx" ]]; then cat "$fx/pr-$n.json"; return; fi
  local slug pv inline
  slug="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  pv="$(gh pr view "$n" --json number,reviews,files)"
  inline="$(gh api "repos/$slug/pulls/$n/comments" \
    --jq '[.[]|{path, line:(.line // .original_line), body, url:.html_url, author:{login:.user.login}}]')"
  jq -n --argjson pv "$pv" --argjson c "$inline" '$pv + {comments:$c}'
}

_pr_list | jq -c '.[]' | while read -r pr; do
  n="$(echo "$pr" | jq -r '.number')"
  detail="$(_pr_detail "$n")"
  jq -n --argjson pr "$pr" --argjson d "$detail" '
    ($d.files // [] | map(.path)) as $paths
    | $pr + {
        reviews:  ($d.reviews  // [] | map({state, author:(.author.login // "?")})),
        comments: ($d.comments // [] | map({
          path, line, body, url, author:(.author.login // "?"),
          caused_change: (($paths | index(.path)) != null)
        }))
      }'
done | jq -s '.'
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash code-reviewer/tests/test_mine_pr_signals.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/lib/mine-pr-signals.sh code-reviewer/tests/test_mine_pr_signals.sh code-reviewer/tests/fixtures/gh/pr-list.json code-reviewer/tests/fixtures/gh/pr-101.json
git commit -m "feat(code-reviewer): add PR-signal miner with comment->change correlation

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Diff-coverage guard (workstream a)

**Files:**
- Create: `code-reviewer/lib/check-diff-coverage.sh`
- Create: `code-reviewer/tests/fixtures/gh/diff-5.txt`
- Create: `code-reviewer/tests/fixtures/gh/findings-5.json`
- Test: `code-reviewer/tests/test_check_diff_coverage.sh`

**Interfaces:**
- Produces:
  - `check-diff-coverage.sh coverage <pr>` → `{files:[{path,covered,exclude_reason?}], uncovered:[...]}`.
  - `check-diff-coverage.sh validate <pr> <findings-json-file>` → the findings array, each augmented with `location_verified:bool` and (when false) `flag:"unverified location"`.
- **Test seam:** `CODE_REVIEWER_GH_FIXTURE_DIR` → reads `<dir>/diff-<pr>.txt` instead of `gh pr diff`.
- `ponytail:` location check is file-presence only (upgrade path: parse hunk `@@` ranges for true line-in-hunk verification).

- [ ] **Step 1: Write the fixtures**

`code-reviewer/tests/fixtures/gh/diff-5.txt`:
```
diff --git a/src/app.ts b/src/app.ts
--- a/src/app.ts
+++ b/src/app.ts
@@ -1,2 +1,3 @@
 const a = 1;
+const b = 2;
diff --git a/package-lock.json b/package-lock.json
--- a/package-lock.json
+++ b/package-lock.json
@@ -1,1 +1,2 @@
+  "added": true
```

`code-reviewer/tests/fixtures/gh/findings-5.json`:
```json
[{"file":"src/app.ts","line":2,"summary":"real finding"},
 {"file":"src/ghost.ts","line":9,"summary":"finding on unchanged file"}]
```

- [ ] **Step 2: Write the failing test**

`code-reviewer/tests/test_check_diff_coverage.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
LIB="$DIR/../lib/check-diff-coverage.sh"
export CODE_REVIEWER_GH_FIXTURE_DIR="$DIR/fixtures/gh"

cov="$(bash "$LIB" coverage 5)"
assert "src/app.ts covered" \
  '[ "$(echo "$cov" | jq -r ".files[]|select(.path==\"src/app.ts\")|.covered")" = "true" ]'
assert "lockfile excluded (uncovered)" \
  '[ "$(echo "$cov" | jq -r ".files[]|select(.path==\"package-lock.json\")|.covered")" = "false" ]'
assert "uncovered lists the lockfile" \
  '[ "$(echo "$cov" | jq -r ".uncovered[0]")" = "package-lock.json" ]'

val="$(bash "$LIB" validate 5 "$DIR/fixtures/gh/findings-5.json")"
assert "app.ts finding verified" \
  '[ "$(echo "$val" | jq -r ".[]|select(.file==\"src/app.ts\")|.location_verified")" = "true" ]'
assert "ghost.ts finding flagged" \
  '[ "$(echo "$val" | jq -r ".[]|select(.file==\"src/ghost.ts\")|.flag")" = "unverified location" ]'
finish
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash code-reviewer/tests/test_check_diff_coverage.sh`
Expected: FAIL — `check-diff-coverage.sh` not found.

- [ ] **Step 4: Implement the lib**

`code-reviewer/lib/check-diff-coverage.sh`:
```bash
#!/usr/bin/env bash
# check-diff-coverage.sh coverage <pr>
# check-diff-coverage.sh validate <pr> <findings-json-file>
# Offline seam: CODE_REVIEWER_GH_FIXTURE_DIR → <dir>/diff-<pr>.txt
set -euo pipefail
mode="${1:-}"; pr="${2:-}"
[[ -n "$mode" && -n "$pr" ]] || { echo "usage: check-diff-coverage.sh <coverage|validate> <pr> [findings.json]" >&2; exit 64; }
command -v jq &>/dev/null || { echo "jq required: brew install jq" >&2; exit 2; }
fx="${CODE_REVIEWER_GH_FIXTURE_DIR:-}"

_diff() {
  if [[ -n "$fx" ]]; then cat "$fx/diff-$pr.txt"; return; fi
  command -v gh &>/dev/null || { echo "gh required: https://cli.github.com" >&2; exit 2; }
  gh pr diff "$pr"
}

EXCLUDE_RE='(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|\.min\.(js|css)$|\.(png|jpe?g|gif|svg|pdf|lock)$)'

# ponytail: line check is file-presence only; upgrade = parse @@ hunk ranges.
changed="$(_diff | sed -n 's#^+++ b/##p')"

case "$mode" in
  coverage)
    printf '%s\n' "$changed" | jq -R -s --arg re "$EXCLUDE_RE" '
      split("\n") | map(select(length>0)) | map(
        if test($re) then {path:., covered:false, exclude_reason:"generated/binary/lock"}
        else {path:., covered:true} end) as $files
      | {files:$files, uncovered:[$files[]|select(.covered==false)|.path]}'
    ;;
  validate)
    findings="${3:-}"; [[ -f "$findings" ]] || { echo "findings json file required" >&2; exit 64; }
    printf '%s\n' "$changed" | jq -R -s --slurpfile f "$findings" '
      (split("\n")|map(select(length>0))) as $c
      | $f[0] | map(. + {location_verified: (($c|index(.file)) != null)})
      | map(if .location_verified then . else . + {flag:"unverified location"} end)'
    ;;
  *) echo "unknown mode: $mode" >&2; exit 64 ;;
esac
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash code-reviewer/tests/test_check_diff_coverage.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/lib/check-diff-coverage.sh code-reviewer/tests/test_check_diff_coverage.sh code-reviewer/tests/fixtures/gh/diff-5.txt code-reviewer/tests/fixtures/gh/findings-5.json
git commit -m "feat(code-reviewer): add diff-coverage guard (coverage + finding validation)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: `refresh-principles` skill + principle-file format

**Files:**
- Create: `code-reviewer/skills/refresh-principles/SKILL.md`
- Create: `code-reviewer/skills/refresh-principles/references/principle-file-format.md`
- Test: `code-reviewer/tests/test_principle_format.sh`

**Interfaces:**
- Consumes: `learn-state.sh`, `mine-git-signals.sh`, `mine-pr-signals.sh` (Tasks 1–3) via `${CLAUDE_PLUGIN_ROOT}/lib/`; `resolve-principle-dir.sh` (existing).
- Produces: the user-facing producer flow. No programmatic return (LLM-orchestrated).

- [ ] **Step 1: Write the principle-file format reference**

`code-reviewer/skills/refresh-principles/references/principle-file-format.md`:
```markdown
# Principle file format

Each of `01-overview` … `07-red-flags` is a Markdown file of **entries**. Every
entry MUST carry an `Evidence:` line citing at least one source — no citation,
no entry (precision-first).

## Entry template

### <short imperative title>
- **What:** one-line description of the pattern/pitfall/hotspot.
- **Evidence:** PR #<n> (<url>) · commit <sha> · comment <url> — <YYYY-MM-DD>
- **Why it matters:** one line (impact / what breaks).

## File roles

| File | Holds |
|---|---|
| 07-red-flags | patterns that caused reverts/hotfixes or blocked-then-fixed reviews |
| 02-pitfalls | bug clusters recurring across ≥N PRs |
| 05-hotspots | high-churn files (cite commit counts) |
| 04-domain-traps | domain gotchas raised in review that caused a change |
| 03-review-patterns | what reviewers repeatedly ask for |
| 06-conventions | recurring style/convention asks that caused a change |
| 01-overview | auto-generated manifest: repo, window, counts, watermark |

## Mechanical rule (test-checked)
Every `###` entry outside `01-overview` has a line beginning `- **Evidence:**`
with at least one of `PR #`, a 7+ hex SHA, or an `http` URL.
```

- [ ] **Step 2: Write the format-conformance test (with a golden example)**

`code-reviewer/tests/fixtures/golden-entry.md`:
```markdown
### Guard external API responses
- **What:** null-check payloads from the ads API before indexing.
- **Evidence:** PR #101 (https://x/c1) · commit deadbee — 2026-07-01
- **Why it matters:** unchecked payloads caused the 2026-07 hotfix.
```

`code-reviewer/tests/test_principle_format.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
GOLDEN="$DIR/fixtures/golden-entry.md"

# Every '### ' entry must be followed (within its block) by an Evidence line
# carrying a PR#, a 7+ hex SHA, or an http URL.
check_evidence() {  # <file>
  awk '
    /^### /      { if (title!="" && !ok) exit 1; title=$0; ok=0 }
    /^- \*\*Evidence:\*\*/ {
      if ($0 ~ /PR #[0-9]+/ || $0 ~ /[0-9a-f]{7,}/ || $0 ~ /http/) ok=1
    }
    END { if (title!="" && !ok) exit 1 }
  ' "$1"
}
echo "Test: golden entry satisfies the evidence rule"
assert "golden entry has valid evidence" 'check_evidence "$GOLDEN"'

echo "Test: an entry with no evidence fails"
bad="$(mktemp)"; printf '### no evidence\n- **What:** x\n' > "$bad"
assert "evidence-less entry rejected" '! check_evidence "$bad"'
rm -f "$bad"
finish
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `bash code-reviewer/tests/test_principle_format.sh`
Expected: FAIL — `fixtures/golden-entry.md` not found (create it in Step 2 before running; if run before the file exists it errors, confirming the dependency).

- [ ] **Step 4: Write the skill**

`code-reviewer/skills/refresh-principles/SKILL.md`:
```markdown
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
items into entries; prefer PR comments with `caused_change:true`, reverts,
hotfixes, and clusters recurring across ≥N PRs (N default 2). Every entry gets an
`Evidence:` line. Route entries to files per the format table. Drop anything you
cannot cite.

## Step 5 — Propose (approval gate)

Show a unified diff of the proposed additions/updates to the principle files.
Use AskUserQuestion: Approve / Edit / Skip. Do not proceed without approval.

## Step 6 — Write

On approval, merge entries into the files (append new; update in place; dedupe by
title+citation — never duplicate an existing PR#/SHA-cited entry). Regenerate
`01-overview.md` (repo, window, counts). Writes are plain file writes; do NOT
`git commit` the principle dir.

## Step 7 — Advance the watermark (only after a successful write)

```bash
bash "${CLAUDE_PLUGIN_ROOT}/lib/learn-state.sh" write "$PRINCIPLE_DIR" \
  "<newest mergedAt processed>" "<newest merge sha>" '<counts-json>'
```
If the user skipped/declined in Step 5, do NOT advance — the next run retries the
same range.
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash code-reviewer/tests/test_principle_format.sh`
Expected: PASS — `Failed: 0`.

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/skills/refresh-principles code-reviewer/tests/test_principle_format.sh code-reviewer/tests/fixtures/golden-entry.md
git commit -m "feat(code-reviewer): add refresh-principles producer skill + format ref

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Wire coverage guards into the orchestrator

**Files:**
- Modify: `code-reviewer/agents/pr-review-orchestrator.md`

**Interfaces:**
- Consumes: `check-diff-coverage.sh` (Task 4) via `${CLAUDE_PLUGIN_ROOT}/lib/`.
- No test (agent prose); verified by reading + a live `review-pr` dry-run.

- [ ] **Step 1: Insert the coverage pre-pass after Phase 1**

In `code-reviewer/agents/pr-review-orchestrator.md`, immediately after the Phase 1 section ("## Phase 1: Gather the PR diff" and its code block), insert:
```markdown
## Phase 1.5: Coverage pre-pass (deterministic)

```bash
bash ${CLAUDE_PLUGIN_ROOT}/lib/check-diff-coverage.sh coverage <PR_NUMBER>
```

Every `covered:true` file MUST be reflected in the review. Report every
`uncovered` file explicitly as `excluded: <reason>` in the final report — a
changed file is never silently omitted.
```

- [ ] **Step 2: Add finding-location validation to Phase 4**

In the "## Phase 4: Aggregate and report" section, add this bullet under `## Notes`:
```markdown
- **Validate finding locations.** Before emitting, run
  `bash ${CLAUDE_PLUGIN_ROOT}/lib/check-diff-coverage.sh validate <PR_NUMBER> <findings.json>`
  (write the aggregated findings to a temp JSON of `{file,line,summary}` objects).
  Any finding returned with `flag: "unverified location"` is kept but tagged
  `(unverified location)` — never silently dropped.
```

- [ ] **Step 3: Verify the edits read correctly**

Run: `grep -n "check-diff-coverage" code-reviewer/agents/pr-review-orchestrator.md`
Expected: 2 matches (Phase 1.5 + Phase 4 note).

- [ ] **Step 4: Commit**

```bash
git add code-reviewer/agents/pr-review-orchestrator.md
git commit -m "feat(code-reviewer): wire deterministic coverage guards into orchestrator

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Version bump, content, regenerate docs, full gate

**Files:**
- Modify: `.claude-plugin/marketplace.json` (code-reviewer entry `version`)
- Modify: `code-reviewer/.claude-plugin/plugin.json` (`version`)
- Modify: `content/plugins.content.json` (code-reviewer summary)

**Interfaces:** none (release task).

- [ ] **Step 1: Bump both versions to 0.3.0**

Edit `code-reviewer/.claude-plugin/plugin.json`: `"version": "0.2.0"` → `"version": "0.3.0"`.
Edit `.claude-plugin/marketplace.json`: the code-reviewer entry's `"version"` → `"0.3.0"` (keep equal to plugin.json).

- [ ] **Step 2: Mention the learn-loop in content**

In `content/plugins.content.json`, find the `code-reviewer` entry and extend its summary prose to mention the new capability, e.g. append: " Includes `refresh-principles`, which learns the repo's own principle files from merged git + PR history." Do NOT list the skill/commands (auto-harvested).

- [ ] **Step 3: Run the plugin bash test suite**

Run: `for t in code-reviewer/tests/test_*.sh; do echo "== $t =="; bash "$t" || exit 1; done`
Expected: every suite prints `Failed: 0`.

- [ ] **Step 4: Regenerate docs**

Run: `./scripts/cicd.sh GEN`
Expected: `CATALOG.md`, `code-reviewer/README.md`, `site/*` regenerated; `git status` shows only generated files changed (plus the sources you edited).

- [ ] **Step 5: Run the full CI gate**

Run: `./scripts/cicd.sh VERIFY`
Expected: generator tests pass + doc-sync check passes (exit 0).

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore(code-reviewer): bump to 0.3.0 + regenerate catalog

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage** — every spec section maps to a task:
- §6 `learn-state.sh` → T1 · `mine-git-signals.sh` → T2 · `mine-pr-signals.sh` (+comment→change) → T3 · `check-diff-coverage.sh` (2 modes) → T4 · `refresh-principles` skill + format ref → T5 · orchestrator MOD → T6.
- §7 producer data flow → T5 skill steps 1–7. §8 mapping → T5 format ref + distill step. §9 `.learn-state.json` → T1 (note: `runs[]`/`window` from the schema are deferred — `ponytail:` YAGNI, watermark stores `last_merged_at/last_merged_sha/counts/generated_at`, which is all the invariant needs). §10 error handling → per-lib `die`/early-exit + skill Steps 1/5/7. §11 edge cases → merged-only (T3 search query), dedupe (T5 Step 6), fixture-seam offline tests. §12 testing → T1–T5 tests + T7 gate. §13 versioning → T7.
- §14 invariant (watermark advances only after approved write) → T5 Step 7.

**2. Placeholder scan** — no TBD/TODO; every code step has complete, runnable code; the one deliberate simplification (file-presence line check) is marked with a `ponytail:` upgrade path, not left vague.

**3. Type/name consistency** — `CODE_REVIEWER_GH_FIXTURE_DIR` identical across T3/T4. `learn-state.sh read|write` signature identical T1↔T5. `check-diff-coverage.sh coverage|validate` identical T4↔T6. Field names (`caused_change`, `covered`, `uncovered`, `location_verified`, `flag`) consistent between each lib and its test.

**Deviation from spec noted:** `.learn-state.json` drops the `runs[]` history array and `window` object (YAGNI) — flagged above; re-add if run-history reporting is later wanted.
