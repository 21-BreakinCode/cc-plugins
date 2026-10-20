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

extract() {  # <html file> <json|script>
  python3 - "$1" "$2" <<'PY'
import re, sys
page = open(sys.argv[1], encoding='utf-8').read()
pattern = r'<script type="application/json" id="data">(.*?)</script>' if sys.argv[2] == 'json' else r'<script>\n(.*?)\n</script>'
print(re.search(pattern, page, re.DOTALL).group(1))
PY
}

run_case() {  # <page.json jq filter> [findings.json jq filter] ; sets OUT and RC
  local dir
  dir="$(mktemp -d "$T/case.XXXXXX")"
  cp "$REVIEW"/pr.json "$REVIEW"/pr.diff "$REVIEW"/drift.json "$REVIEW"/report.md "$dir/"
  jq "$1" "$REVIEW/page.json" > "$dir/page.json"
  jq "${2:-.}" "$REVIEW/findings.json" > "$dir/findings.json"
  set +e; OUT="$(python3 "$BUILD" "$dir" "$REPO" 2>&1)"; RC=$?; set -e
}

echo "Test: build from the fixture"
set +e; OUT="$(python3 "$BUILD" "$REVIEW" "$REPO" 2>&1)"; RC=$?; set -e
PAGE="$REVIEW/pr7-review.html"
assert "builds with exit 0" '[ "$RC" -eq 0 ]'
assert "prints PAGE_FILE" 'grep -qF "PAGE_FILE=$PAGE" <<<"$OUT"'
[ -f "$PAGE" ] || { echo "$OUT"; finish; exit 1; }
assert "title names the repo and PR" 'grep -qF "<title>widget PR 7 Review</title>" "$PAGE"'
extract "$PAGE" json > "$T/data.raw"
assert "data block has no raw <" '! grep -q "<" "$T/data.raw"'
assert "data block parses as JSON" 'python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$T/data.raw"'
python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))" "$T/data.raw" > "$T/data.json"
D="$T/data.json"
assert "escaped text survives the round trip" 'jq -e ".notes | any(contains(\"</script><!--\"))" "$D" >/dev/null'
assert "every line stays short enough to read" '[ "$(awk "length > 2000" "$PAGE" | wc -l)" -eq 0 ]'
assert "findings sorted most severe first" '[ "$(jq -r "[.findings[].id] | join(\",\")" "$D")" = "caller-uses-removed-helper,total-has-no-test" ]'
assert "areas come from the finding sources" '[ "$(jq -c ".findings[0].areas" "$D")" = "[\"correctness\",\"policy\"]" ]'
assert "file and line come from findings.json" '[ "$(jq -r ".findings[1] | \"\(.file):\(.line)\"" "$D")" = "app.py:5" ]'
assert "verdict comes from report.md" '[ "$(jq -r .verdict "$D")" = "NEEDS_DISCUSSION" ]'
assert "review id names this run" 'jq -r .review_id "$D" | grep -q "^acme/widget#7@${HEAD_SHA:0:7}:"'

S='.snippets["code app.py:1-2"]'
assert "code ref links the lines at the PR head" '[ "$(jq -r "$S.url" "$D")" = "https://github.com/acme/widget/blob/$HEAD_SHA/app.py#L1-L2" ]'
assert "code ref marks the cited lines" '[ "$(jq -c "[$S.rows[] | select(.hl) | .n]" "$D")" = "[1,2]" ]'
assert "code ref adds context lines" '[ "$(jq -c "[$S.rows[].n]" "$D")" = "[1,2,3,4]" ]'
assert "code ref copies the real line" '[ "$(jq -r "$S.rows[0].t" "$D")" = "def double(value):" ]'
S='.snippets["diff app.py \"def old_helper(value):\""]'
assert "diff ref shows the removed line, marked" '[ "$(jq -c "[$S.rows[] | select(.hl) | .d]" "$D")" = "[\"del\"]" ]'
ANCHOR="$(printf 'app.py' | shasum -a 256 | cut -d' ' -f1)"
assert "diff ref links the PR files view" '[ "$(jq -r "$S.url" "$D")" = "https://github.com/acme/widget/pull/7/files#diff-$ANCHOR" ]'
S='.snippets["grep -w old_helper @merged"]'
assert "grep ref shows the command that ran" 'jq -r "$S.command" "$D" | grep -q "^git grep -n -I -w -e old_helper [0-9a-f]\{7\}$"'
assert "grep ref on the test merge finds the new caller" 'jq -r "$S.output[]" "$D" | grep -qxF "caller.py:1:from app import old_helper"'
S='.snippets["code caller.py:1-3 @merged"]'
assert "test merge code has no GitHub link" '[ "$(jq -r "$S.url" "$D")" = "" ] && jq -r "$S.where" "$D" | grep -q "test merge"'
assert "method notes come first" 'jq -r ".notes[0]" "$D" | grep -qF "${HEAD_SHA:0:7}" && jq -r ".notes[1]" "$D" | grep -q "test merge"'
extract "$PAGE" script > "$T/page.js"
assert "page script passes node --check" 'node --check "$T/page.js"'
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
assert "code ref missing at the head points to diff" 'grep -q "caller.py is not in the PR head. For removed code, use a diff ref" <<<"$OUT"'
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
