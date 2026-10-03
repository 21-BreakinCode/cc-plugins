#!/usr/bin/env bash
# Blind paired judging for LLM-judge evals.
#
# An agent that scores its own edit on an absolute 1-10 scale reports mostly
# noise: the same text can move a full point between calls, and the editor is
# biased toward its own change. Instead, fresh judges read the last kept version
# (the snapshot) and the edited version side by side. A judge's bias then hits
# both versions equally and cancels out.
#
# The labels A and B hide which version is new. Odd judges see the edit as A,
# even judges see it as B, so position bias also cancels across the panel.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/snapshot.sh"

AR_JUDGE_DIR="${AR_AUTORESEARCH_DIR}/judge"

# ar_judge_stage <judge_id> <file>...
# Copies the kept and edited version of each target into
# .autoresearch/judge/<judge_id>/{A,B}/<file>.
# Prints the label (A or B) that holds the edited version.
ar_judge_stage() {
  local judge_id="${1:-}"
  case "${judge_id}" in
    ''|*[!0-9]*) ar_log "judge_stage: judge_id must be a positive integer, got '${judge_id}'"; return 1 ;;
  esac
  shift
  [ "$#" -gt 0 ] || { ar_log "judge_stage: no target files given"; return 1; }

  local edited_label="B" kept_label="A"
  if [ $((judge_id % 2)) -eq 1 ]; then edited_label="A"; kept_label="B"; fi

  local stage_dir="${AR_JUDGE_DIR}/${judge_id}"
  rm -rf "${stage_dir}"

  local target_file
  for target_file in "$@"; do
    [ -f "${AR_SNAPSHOT_DIR}/${target_file}" ] || { ar_log "judge_stage: no snapshot for '${target_file}'"; return 1; }
    [ -f "${target_file}" ] || { ar_log "judge_stage: edited file '${target_file}' not found"; return 1; }
    mkdir -p "${stage_dir}/A/$(dirname "${target_file}")" "${stage_dir}/B/$(dirname "${target_file}")"
    cp -p "${AR_SNAPSHOT_DIR}/${target_file}" "${stage_dir}/${kept_label}/${target_file}"
    cp -p "${target_file}" "${stage_dir}/${edited_label}/${target_file}"
  done

  echo "${edited_label}"
}

# ar_judge_tally <edited_label>:<verdict>...
# One argument per judge: the label that held the edit, then the judge's verdict
# (A, B, or tie). Example: ar_judge_tally "A:A" "B:tie" "A:B"
# Prints {"better": n, "worse": n, "tie": n, "keep": true|false}.
# Keep needs a strict majority of judges preferring the edit. A tie is no gain,
# so keeping ties would let the target drift without improving.
ar_judge_tally() {
  [ "$#" -gt 0 ] || { ar_log "judge_tally: no verdicts given"; return 1; }

  local better=0 worse=0 tie=0 vote edited_label verdict
  for vote in "$@"; do
    edited_label="${vote%%:*}"
    verdict="${vote#*:}"
    case "${edited_label}" in
      A|B) ;;
      *) ar_log "judge_tally: invalid edited label in '${vote}'"; return 1 ;;
    esac
    case "${verdict}" in
      tie) tie=$((tie + 1)) ;;
      A|B)
        if [ "${verdict}" = "${edited_label}" ]; then better=$((better + 1)); else worse=$((worse + 1)); fi ;;
      *) ar_log "judge_tally: invalid verdict in '${vote}'"; return 1 ;;
    esac
  done

  local keep=false
  if [ $((better * 2)) -gt "$#" ]; then keep=true; fi
  printf '{"better": %d, "worse": %d, "tie": %d, "keep": %s}\n' "${better}" "${worse}" "${tie}" "${keep}"
}
