#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
BUILD="$DIR/../lib/build-review-page.py"
DRIFT="$DIR/../lib/check-base-drift.sh"
FX="$DIR/fixtures/review-page"

T="$(cd "$(mktemp -d)" && pwd -P)"
export GIT_CEILING_DIRECTORIES="$T"
git_q() { git -c user.email=t@t -c user.name=t "$@"; }
commit_all() { git_q -C "$REPO" add -A && git_q -C "$REPO" commit -q -m "$1"; }

# main has old_helper. The PR renames it to double. main then adds caller.py,
# which still calls old_helper: a clean merge that breaks at run time.
REPO="$T/repo"
git_q init -q -b main "$REPO"
printf 'def old_helper(value):\n    return value * 2\n\n\ndef total(values):\n    return sum(old_helper(v) for v in values)\n' > "$REPO/app.py"
commit_all base
MERGE_BASE="$(git -C "$REPO" rev-parse HEAD)"
git_q -C "$REPO" switch -q -c pr
printf 'def double(value):\n    return value * 2\n\n\ndef total(values):\n    return sum(double(v) for v in values)\n' > "$REPO/app.py"
commit_all rename
HEAD_SHA="$(git -C "$REPO" rev-parse HEAD)"
git_q -C "$REPO" switch -q main
printf 'from app import old_helper\n\nprint(old_helper(3))\n' > "$REPO/caller.py"
commit_all caller
LATEST_BASE="$(git -C "$REPO" rev-parse HEAD)"

REVIEW="$T/review"
mkdir -p "$REVIEW"
cp "$FX/findings.json" "$FX/page.json" "$REVIEW/"
git -C "$REPO" diff "$MERGE_BASE" "$HEAD_SHA" > "$REVIEW/pr.diff"
bash "$DRIFT" "$REPO" "$LATEST_BASE" "$HEAD_SHA" > "$REVIEW/drift.json"
printf '# PR #7 Review: Rename the helper\n\n## Verdict: NEEDS_DISCUSSION\n' > "$REVIEW/report.md"
jq -n --arg head "$HEAD_SHA" '{number: 7, title: "Rename the helper", url: "https://github.com/acme/widget/pull/7",
  author: {login: "dev"}, headRefName: "rename-helper", baseRefName: "main", headRefOid: $head,
  additions: 2, deletions: 2, changedFiles: 1}' > "$REVIEW/pr.json"

run_case() {  # <page.json jq filter> [findings.json jq filter] ; sets OUT and RC
  local dir
  dir="$(mktemp -d "$T/case.XXXXXX")"
  cp "$REVIEW"/pr.json "$REVIEW"/pr.diff "$REVIEW"/drift.json "$REVIEW"/report.md "$dir/"
  jq "$1" "$REVIEW/page.json" > "$dir/page.json"
  jq "${2:-.}" "$REVIEW/findings.json" > "$dir/findings.json"
  set +e; OUT="$(python3 "$BUILD" "$dir" "$REPO" 2>&1)"; RC=$?; set -e
}

panel_titles() { grep '^## ' "$1" | sed 's/^## //' | paste -sd '|' -; }

echo "Test: build from the fixture"
set +e; OUT="$(python3 "$BUILD" "$REVIEW" "$REPO" 2>&1)"; RC=$?; set -e
PAGE="$REVIEW/pr7-review.html"
D="$REVIEW/pr7-review.md"
assert "builds with exit 0" '[ "$RC" -eq 0 ]'
assert "prints PAGE_FILE" 'grep -qxF "PAGE_FILE=$PAGE" <<<"$OUT"'
assert "prints DRAFT_FILE" 'grep -qxF "DRAFT_FILE=$D" <<<"$OUT"'
[ -f "$PAGE" ] && [ -f "$D" ] || { echo "$OUT"; finish; exit 1; }
assert "am rendered with no error" 'grep -qF "am: ✓ $PAGE" <<<"$OUT" && ! grep -q "✗" <<<"$OUT"'
assert "am kept its state in the review dir" '[ -d "$REVIEW/.am" ]'
assert "page title names the repo and PR" 'grep -qF "<title>widget PR 7 review</title>" "$PAGE"'
assert "page is a doc with the flow diagrams and asks" 'grep -q "8 panels · callout×1 kv×1 flow×2 ask×5" <<<"$OUT"'
assert "panels walk overview, arch, findings most severe first, verdict" \
  '[ "$(panel_titles "$D")" = "Overview|Architecture before|Architecture after|Important: New code on main still calls the old helper|Suggestion: No test covers \`total\`|Done well|How this review was made|Verdict" ]'
assert "verdict comes from report.md" 'grep -qxF "\`\`\`callout warn Verdict: NEEDS_DISCUSSION" "$D"'
assert "before diagram reads the merge base" 'grep -qF "The code at the merge base \`${MERGE_BASE:0:7}\`. Drawn from: \`code app.py:1-6 @base\`." "$D"'
assert "after diagram reads the PR head" 'grep -qF "The code at the PR head \`${HEAD_SHA:0:7}\`." "$D"'
assert "diagram source goes into a flow fence" 'grep -A1 -xF "\`\`\`flow LR" "$D" | grep -qxF "total -> *double: calls"'
assert "file and line come from findings.json" 'grep -qxF "\`app.py:5\`, found by test." "$D"'
assert "areas come from the finding sources" 'grep -qxF "\`app.py:1\`, found by correctness, policy." "$D"'
assert "claims carry their check" 'grep -qxF -- "- **FACT, read, not run:** The import fails at run time. I did not run it." "$D"'

assert "code ref copies the real lines with context" \
  'grep -A4 -F "py title=\"app.py L5-6 at the PR head" "$D" | tail -2 | paste -sd "|" - | grep -qxF "def total(values):|    return sum(double(v) for v in values)"'
assert "code ref numbers and marks the cited lines" 'grep -qF "py title=\"app.py L5-6 at the PR head ${HEAD_SHA:0:7}\" start=3 hl=5-6" "$D"'
assert "diff ref writes a true hunk header" 'grep -A1 -F "diff file=app.py" "$D" | grep -qxF "@@ -1,6 +1,6 @@"'
assert "diff ref shows the removed line" 'grep -qxF -- "-def old_helper(value):" "$D"'
assert "grep ref on the test merge finds the new caller" 'grep -qxF "caller.py:1:from app import old_helper" "$D"'
assert "grep ref names the command and the place" 'grep -qE "^\`\`\`text title=\"git grep -n -I -w -e old_helper [0-9a-f]{7} \(test merge of main" "$D"'
assert "code ref on the test merge names it" 'grep -qF "py title=\"caller.py L1-3 at the test merge" "$D"'
assert "important finding suggests Block" 'grep -A2 -xF "[caller-uses-removed-helper] Your call on this finding?" "$D" | grep -qxF "* Block | must change before merge"'
assert "suggestion finding suggests Suggest" 'grep -A3 -xF "[total-has-no-test] Your call on this finding?" "$D" | grep -qxF "* Suggest | post as a suggestion"'
assert "two fixes get a fix ask, first suggested" 'grep -A1 -xF "[caller-uses-removed-helper] Which fix?" "$D" | grep -qxF "* a. Fix the caller in the merge"'
assert "one fix gets no fix ask" '! grep -qF "[total-has-no-test] Which fix?" "$D"'
assert "verdict asks suggest the report verdict" 'grep -A3 -xF "[review] GitHub action?" "$D" | grep -qxF "* Comment | feedback without a verdict"'
assert "verdict asks who posts" 'grep -qxF "[review] Who posts the review?" "$D"'
assert "method notes come first in the notes" 'grep -A2 -xF "## How this review was made" "$D" | grep -qF "${HEAD_SHA:0:7}"'
assert "page text stays text" 'grep -qF "&lt;/script&gt;&lt;!--" "$PAGE"'
assert "builds with the system python too (3.9 on macOS)" '! [ -x /usr/bin/python3 ] || /usr/bin/python3 "$BUILD" "$REVIEW" "$REPO" >/dev/null'

echo "Test: rejects bad input, all errors of one kind at once"
run_case 'del(.findings["total-has-no-test"])'
assert "missing finding is an error" '[ "$RC" -eq 1 ] && grep -q "finding total-has-no-test is not on the page" <<<"$OUT"'
run_case '.headline = "It — works" | .notes = ["It doesn'"'"'t run."]'
assert "em-dash is an error" 'grep -q "headline: replace the em-dash" <<<"$OUT"'
assert "contraction is an error in the same run" 'grep -qF "write \"doesn'"'"'t\" in full" <<<"$OUT"'
run_case '.findings["total-has-no-test"].claims[0].kind = "assume"'
assert "ASSUME must be not checked" 'grep -q "an ASSUME claim has check \"none\"" <<<"$OUT"'
run_case '.findings["total-has-no-test"].claims[0].refs = []'
assert "seen in code needs a ref" 'grep -q "needs a ref that shows the code" <<<"$OUT"'
run_case '.findings["total-has-no-test"].claims[0].refs = ["code caller.py:1-3"]'
assert "code ref missing at the head points to diff" 'grep -qE "caller.py is not in the PR head [0-9a-f]{7}. For removed code, use a diff ref" <<<"$OUT"'
run_case '.findings["total-has-no-test"].claims[0].refs = ["grep -O less old_helper"]'
assert "grep flags are allow-listed" 'grep -q "flag -O is not allowed" <<<"$OUT"'
run_case '.findings["total-has-no-test"].claims[0].refs = ["diff app.py \"no such text\""]'
assert "diff marker must exist" 'grep -q "no hunk of app.py has the text" <<<"$OUT"'
run_case '.findings["total-has-no-test"].claims[0].refs = ["curl https://example.com"]'
assert "unknown ref form is an error" 'grep -q "use one ref form of the review contract" <<<"$OUT"'
run_case '.notes = "one note"'
assert "notes must be a list" '[ "$RC" -eq 1 ] && grep -q "notes must be a list" <<<"$OUT"'
run_case '.' '.[1].id = "total-has-no-test"'
assert "duplicate finding id is an error" 'grep -q "id total-has-no-test is used more than once" <<<"$OUT"'
run_case 'del(.arch)'
assert "arch is required" '[ "$RC" -eq 1 ] && grep -q "arch: write an object" <<<"$OUT"'
run_case '.arch.after.kind = "class"'
assert "both diagrams use one kind" 'grep -q "arch: use the same kind" <<<"$OUT"'
run_case '.arch.before.source = "```flow\nA -> B\n```"'
assert "diagram source has no fence lines" 'grep -q "arch.before.source: write only the diagram body" <<<"$OUT"'
run_case '.arch.before.refs = ["code caller.py:1 @base"]'
assert "@base ref reads the merge base" 'grep -q "caller.py is not in the merge base" <<<"$OUT"'
run_case '.findings["total-has-no-test"].fixes = [range(7) | {id: "f\(.)", label: "Fix"}]'
assert "at most six fixes fit an ask" 'grep -q "write at most 6 fixes" <<<"$OUT"'
run_case '.arch.after.source = "total ->"'
assert "am errors come back as error lines with the draft" 'grep -q "^error: am: ✗" <<<"$OUT" && grep -q "fix page.json, the draft is" <<<"$OUT"'

echo "Test: PR head must be local"
CASE="$(mktemp -d "$T/case.XXXXXX")"
cp "$REVIEW"/*.json "$REVIEW"/pr.diff "$REVIEW"/report.md "$CASE/"
jq '.headRefOid = "1111111111111111111111111111111111111111"' "$REVIEW/pr.json" > "$CASE/pr.json"
set +e; OUT="$(python3 "$BUILD" "$CASE" "$REPO" 2>&1)"; RC=$?; set -e
assert "missing head names the fetch command" '[ "$RC" -eq 1 ] && grep -qF "git fetch origin pull/7/head" <<<"$OUT"'

echo "Test: usage"
set +e; python3 "$BUILD" >/dev/null 2>&1; RC=$?; set -e
assert "no arguments exits 64" '[ "$RC" -eq 64 ]'

finish
