#!/usr/bin/env bash
# resolve-principle-dir.sh
#
# Resolves a CodeReviewPrinciple directory for the current git repo.
#
# Lookup order:
#   1. Hard override: CODE_REVIEWER_PRINCIPLE_DIR env var.
#   2. Cache: $HOME/.claude/code-reviewer/principle-map.json
#      key = "<github_owner>/<repo>"; stale entries fall through.
#   3. User config roots: $HOME/.claude/code-reviewer/config.json
#      Each root entry: { base, pattern, org_resolver? }.
#        - base supports ~, $HOME, $LIFEOS expansion.
#        - pattern supports {org_dir} and {repo} substitution.
#        - org_resolver:
#            absent / ""        → {org_dir} = github owner (literal)
#            "handover_handler" → scan <base>/*/handover_handler__initiation.md
#                                 frontmatter for `github_orgs:` containing the
#                                 owner; matching subdir name becomes {org_dir}.
#      First root whose substituted path exists wins.
#      If config.json is missing, a default is auto-created on first run
#      containing one entry that reproduces the legacy LifeOS chain.
#   4. Miss → exit 1 with reasons on stderr (caller shows guard prompt).
#
# Exit codes:
#   0 = success; stdout is the absolute principle dir path
#   1 = miss; stderr explains why
#   2 = environment problem (not a git repo, jq missing, malformed config)
#
# Env overrides:
#   CODE_REVIEWER_PRINCIPLE_DIR   hard override (skip lookup)
#   CODE_REVIEWER_CACHE_FILE      cache file path
#   CODE_REVIEWER_CONFIG_FILE     config file path
#   LIFEOS                        used when config root references $LIFEOS

set -euo pipefail

# ── Paths ───────────────────────────────────────────────────────────
CACHE_FILE="${CODE_REVIEWER_CACHE_FILE:-${HOME}/.claude/code-reviewer/principle-map.json}"
CONFIG_FILE="${CODE_REVIEWER_CONFIG_FILE:-${HOME}/.claude/code-reviewer/config.json}"
LIFEOS_DEFAULT="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"

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

# ── 2. Ensure config file exists (seed legacy LifeOS default) ──────
if [[ ! -s "$CONFIG_FILE" ]]; then
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" <<'JSON'
{
  "version": 1,
  "roots": [
    {
      "base": "$LIFEOS/01Project",
      "pattern": "{org_dir}/CodeReviewPrinciple/{repo}",
      "org_resolver": "handover_handler"
    }
  ]
}
JSON
fi

command -v jq &>/dev/null || \
  die_env "jq is required for config-based resolution. Install with: brew install jq"

jq -e '.roots' "$CONFIG_FILE" >/dev/null 2>&1 || \
  die_env "Config file malformed (missing .roots array): $CONFIG_FILE"

# ── Helpers ─────────────────────────────────────────────────────────
expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  p="${p//\$LIFEOS/${LIFEOS:-$LIFEOS_DEFAULT}}"
  p="${p//\$HOME/$HOME}"
  echo "$p"
}

substitute_pattern() {
  local pattern="$1" org_dir="$2" repo_arg="$3"
  pattern="${pattern//\{org_dir\}/$org_dir}"
  pattern="${pattern//\{repo\}/$repo_arg}"
  echo "$pattern"
}

# Scans <base>/*/handover_handler__initiation.md frontmatter for
# `github_orgs:` containing $owner. Echoes matching ORG subdir name on success.
resolve_org_handover_handler() {
  local base="$1" target_owner="$2"
  local init org_line stripped orgs o
  for init in "$base"/*/handover_handler__initiation.md; do
    [[ -f "$init" ]] || continue
    org_line=$(awk '/^github_orgs:/{print; exit}' "$init" 2>/dev/null || true)
    [[ -n "$org_line" ]] || continue
    stripped=$(echo "$org_line" | sed -E 's/.*\[(.*)\].*/\1/')
    IFS=', ' read -ra orgs <<< "$stripped"
    for o in "${orgs[@]}"; do
      [[ -z "$o" ]] && continue
      if [[ "$o" == "$target_owner" ]]; then
        basename "$(dirname "$init")"
        return 0
      fi
    done
  done
  return 1
}

# ── 3. Iterate config roots ────────────────────────────────────────
miss_reasons=()
root_count=0

while IFS=$'\t' read -r r_base r_pattern r_resolver; do
  [[ -z "$r_base" ]] && continue
  root_count=$((root_count + 1))

  base_expanded=$(expand_path "$r_base")

  if [[ ! -d "$base_expanded" ]]; then
    miss_reasons+=("base not found: $base_expanded")
    continue
  fi

  if [[ "$r_resolver" == "handover_handler" ]]; then
    if ! org_dir=$(resolve_org_handover_handler "$base_expanded" "$owner"); then
      miss_reasons+=("no handover_handler ORG maps owner '$owner' under $base_expanded")
      continue
    fi
  else
    org_dir="$owner"
  fi

  sub=$(substitute_pattern "$r_pattern" "$org_dir" "$repo")
  candidate="$base_expanded/$sub"

  if [[ -d "$candidate" ]]; then
    echo "$candidate"
    exit 0
  fi

  miss_reasons+=("no dir at: $candidate")
done < <(jq -r '.roots[] | [.base, .pattern, (.org_resolver // "")] | @tsv' "$CONFIG_FILE")

# ── 4. Miss ────────────────────────────────────────────────────────
if (( root_count == 0 )); then
  die_miss "No principle directory found for $key. Config has no roots configured: $CONFIG_FILE"
fi

{
  echo "No principle directory found for $key after trying $root_count configured root(s):"
  for r in "${miss_reasons[@]}"; do
    echo "  - $r"
  done
} >&2
exit 1
