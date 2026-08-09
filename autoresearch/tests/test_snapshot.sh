#!/usr/bin/env bash
# Smoke tests for ar_snapshot_save / ar_snapshot_restore.
set -euo pipefail

LIB_DIR="$(cd "$(dirname "$0")/.." && pwd)/lib"
# shellcheck disable=SC1090
source "${LIB_DIR}/common.sh"
# shellcheck disable=SC1090
source "${LIB_DIR}/snapshot.sh"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

ORIG_PWD=$(pwd)
TMP=$(mktemp -d)
cd "${TMP}"

# --- discard restores byte-identical content ---
echo "Test: discard restores byte-identical content"
mkdir -p src
printf 'good state\nline two\n' > src/target.md
ar_snapshot_save src/target.md
printf 'BAD EDIT\n' > src/target.md
ar_snapshot_restore src/target.md
assert "content restored exactly" "[ \"\$(cat src/target.md)\" = \$'good state\nline two' ]"
printf 'good state\nline two\n' > /tmp/ar_expected.$$
assert "byte-identical to original" "cmp -s src/target.md /tmp/ar_expected.$$"
rm -f /tmp/ar_expected.$$

# --- keep advances the revert point ---
echo "Test: keep advances the revert point"
printf 'better state\n' > src/target.md
ar_snapshot_save src/target.md          # keep
printf 'worse state\n' > src/target.md
ar_snapshot_restore src/target.md       # discard
assert "reverts to the KEPT state, not the baseline" \
  "[ \"\$(cat src/target.md)\" = 'better state' ]"

# --- nested paths survive ---
echo "Test: nested paths"
mkdir -p a/b/c
printf 'nested\n' > a/b/c/deep.txt
ar_snapshot_save a/b/c/deep.txt
printf 'clobbered\n' > a/b/c/deep.txt
ar_snapshot_restore a/b/c/deep.txt
assert "nested file restored" "[ \"\$(cat a/b/c/deep.txt)\" = 'nested' ]"

# --- multiple targets in one call ---
echo "Test: multiple targets"
printf 'one\n' > f1.txt; printf 'two\n' > f2.txt
ar_snapshot_save f1.txt f2.txt
printf 'x\n' > f1.txt; printf 'y\n' > f2.txt
ar_snapshot_restore f1.txt f2.txt
assert "both restored" "[ \"\$(cat f1.txt)\" = 'one' ] && [ \"\$(cat f2.txt)\" = 'two' ]"

# --- degrades instead of exploding ---
echo "Test: degradation"
assert "restore with no snapshot leaves file untouched" \
  "printf 'untouched\n' > lone.txt; ar_snapshot_restore lone.txt; [ \"\$(cat lone.txt)\" = 'untouched' ]"
assert "save skips a missing file without failing" "ar_snapshot_save f1.txt missing.txt"
assert "no-arg save returns non-zero" "! ar_snapshot_save"
assert "no-arg restore returns non-zero" "! ar_snapshot_restore"
assert "snapshot_exists true after a save" "ar_snapshot_exists"

# --- state lives under .autoresearch/ (already gitignored) ---
echo "Test: state location"
assert "snapshot dir is under .autoresearch/" "[ -d .autoresearch/snapshot ]"
assert "no git repo was created" "[ ! -e .git ]"

cd "${ORIG_PWD}"
rm -rf "${TMP}"

echo ""
echo "  ${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
