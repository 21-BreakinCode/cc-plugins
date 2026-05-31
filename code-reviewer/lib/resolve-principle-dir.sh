#!/usr/bin/env bash
# resolve-principle-dir.sh
#
# Resolves a CodeReviewPrinciple directory for the current git repo.
#
# Lookup order:
#   1. Cache: $HOME/.claude/code-reviewer/principle-map.json
#      key = "<github_owner>/<repo>"
#      If entry exists AND the cached dir still exists on disk → use it.
#      Stale entry (dir vanished) → treat as miss; fall through.
#
#   2. LifeOS chain via handover-handler SSOT:
#        git remote → <github_owner>/<repo>
#        → scan $LIFEOS/01Project/*/handover_handler__initiation.md
#          for an ORG whose `github_orgs:` array contains <github_owner>
#        → check $LIFEOS/01Project/$ORG/CodeReviewPrinciple/<repo>/
#
#   3. Miss → exit 1 with reason on stderr (caller shows guard prompt).
#
# Exit codes:
#   0 = success; stdout is the absolute principle dir path
#   1 = miss; stderr explains why
#   2 = environment problem (LifeOS unreachable, not in a git repo, etc.)
#
# Env overrides:
#   CODE_REVIEWER_PRINCIPLE_DIR     hard override (skip lookup)
#   CODE_REVIEWER_CACHE_FILE        cache file path
#   LIFEOS                          LifeOS vault root

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────
LIFEOS="${LIFEOS:-${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS}"
CACHE_FILE="${CODE_REVIEWER_CACHE_FILE:-${HOME}/.claude/code-reviewer/principle-map.json}"

die_miss() { echo "$1" >&2; exit 1; }
die_env()  { echo "$1" >&2; exit 2; }

# ── 0. Hard override ────────────────────────────────────────────────
if [[ -n "${CODE_REVIEWER_PRINCIPLE_DIR:-}" ]]; then
  [[ -d "$CODE_REVIEWER_PRINCIPLE_DIR" ]] || \
    die_env "CODE_REVIEWER_PRINCIPLE_DIR set but path does not exist: $CODE_REVIEWER_PRINCIPLE_DIR"
  echo "$CODE_REVIEWER_PRINCIPLE_DIR"
  exit 0
fi

# ── Derive github_owner/repo from git remote ────────────────────────
remote_url=$(git remote get-url origin 2>/dev/null || true)
[[ -n "$remote_url" ]] || die_env "Not in a git repo with an 'origin' remote."

# Strip protocol + host, drop .git suffix → owner/repo
slug=$(echo "$remote_url" \
  | sed -E 's#^(git@|https?://)([^/:]+)[/:]##; s#\.git$##')
[[ "$slug" == */* ]] || die_env "Could not parse owner/repo from remote: $remote_url"

owner="${slug%%/*}"
repo="${slug##*/}"
key="${owner}/${repo}"

# ── 1. Cache lookup ─────────────────────────────────────────────────
if [[ -f "$CACHE_FILE" ]] && command -v jq &>/dev/null; then
  cached=$(jq -r --arg k "$key" '.entries[$k] // empty' "$CACHE_FILE" 2>/dev/null || true)
  if [[ -n "$cached" && -d "$cached" ]]; then
    echo "$cached"
    exit 0
  fi
fi

# ── 2. LifeOS chain ─────────────────────────────────────────────────
[[ -d "$LIFEOS/01Project" ]] || \
  die_env "LifeOS not reachable at: $LIFEOS/01Project (check iCloud sync)"

# Scan each ORG's initiation.md frontmatter for github_orgs: [...] containing $owner.
matched_org=""
for init in "$LIFEOS"/01Project/*/handover_handler__initiation.md; do
  [[ -f "$init" ]] || continue
  # github_orgs line example: github_orgs: [plaxieappier, appier, foo]
  org_line=$(awk '/^github_orgs:/{print; exit}' "$init" || true)
  [[ -n "$org_line" ]] || continue
  # Strip brackets, split on commas/spaces, trim each, compare.
  stripped=$(echo "$org_line" | sed -E 's/.*\[(.*)\].*/\1/')
  IFS=', ' read -ra orgs <<< "$stripped"
  for o in "${orgs[@]}"; do
    [[ -z "$o" ]] && continue
    if [[ "$o" == "$owner" ]]; then
      matched_org=$(basename "$(dirname "$init")")
      break 2
    fi
  done
done

if [[ -z "$matched_org" ]]; then
  die_miss "No LifeOS ORG maps github_org '$owner'. (No handover_handler__initiation.md frontmatter lists it.)"
fi

candidate="$LIFEOS/01Project/$matched_org/CodeReviewPrinciple/$repo"
if [[ -d "$candidate" ]]; then
  echo "$candidate"
  exit 0
fi

die_miss "Mapped to ORG '$matched_org' but no principle dir at: $candidate"
