#!/usr/bin/env bash
# Keep/discard revert point for the experiment loop.
#
# Replaces the git commit/checkout pair the loop used to rely on. Git required
# the target to live inside a repo, which silently broke on targets that were
# not repos and polluted real repos with dozens of "iteration N" commits nobody
# wanted. Nothing ever read that history: the dashboard reads reasoning and
# diff_summary out of experiments.json.
#
# Contract: the snapshot holds the LAST KNOWN GOOD state.
#   loop start -> ar_snapshot_save     (baseline)
#   keep       -> ar_snapshot_save     (advance the revert point)
#   discard    -> ar_snapshot_restore  (back to last good)
#   eval error -> ar_snapshot_restore
#
# Save only on keep — never before each edit. A crash mid-edit would otherwise
# poison the revert point with a broken state.

set -euo pipefail

AR_SNAPSHOT_DIR="${AR_AUTORESEARCH_DIR:-.autoresearch}/snapshot"

# ar_snapshot_save <file>...
# Records the current content of each target file as the revert point.
ar_snapshot_save() {
  [ "$#" -gt 0 ] || { ar_log "snapshot_save: no target files given"; return 1; }
  mkdir -p "${AR_SNAPSHOT_DIR}"
  local f
  for f in "$@"; do
    if [ ! -f "${f}" ]; then
      ar_log "snapshot_save: skipping '${f}' (not a regular file)"
      continue
    fi
    mkdir -p "${AR_SNAPSHOT_DIR}/$(dirname "${f}")"
    cp -p "${f}" "${AR_SNAPSHOT_DIR}/${f}"
  done
}

# ar_snapshot_restore <file>...
# Restores each target file from the last snapshot. Files with no snapshot are
# left untouched — a missing snapshot means the file was never a target.
ar_snapshot_restore() {
  [ "$#" -gt 0 ] || { ar_log "snapshot_restore: no target files given"; return 1; }
  local f restored=0
  for f in "$@"; do
    if [ ! -f "${AR_SNAPSHOT_DIR}/${f}" ]; then
      ar_log "snapshot_restore: no snapshot for '${f}', leaving as-is"
      continue
    fi
    mkdir -p "$(dirname "${f}")"
    cp -p "${AR_SNAPSHOT_DIR}/${f}" "${f}"
    restored=$((restored + 1))
  done
  [ "${restored}" -gt 0 ] || ar_log "snapshot_restore: nothing restored"
}

# ar_snapshot_exists — true when a baseline has been taken.
ar_snapshot_exists() {
  [ -d "${AR_SNAPSHOT_DIR}" ]
}
