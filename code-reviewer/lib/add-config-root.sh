#!/usr/bin/env bash
# add-config-root.sh <base> <pattern> [org_resolver]
#
# Appends a new root entry to the code-reviewer config and verifies that
# substituting the current git repo lands on an existing directory.
# Called by the orchestrator after the user picks "Set up a global root"
# in the guard prompt.
#
# Arguments:
#   <base>          Base directory. Supports ~, $HOME, $LIFEOS.
#                   Must be absolute (or starting with ~/$LIFEOS/$HOME)
#                   and resolve to an existing directory.
#   <pattern>       Pattern with {org_dir} and {repo} placeholders.
#                   e.g.  "{org_dir}/{repo}"
#                         "{org_dir}/CodeReviewPrinciple/{repo}"
#   [org_resolver]  Optional. "" or "handover_handler".
#
# Behavior:
#   1. Validate base exists (after expansion).
#   2. Validate pattern contains {repo}.
#   3. Resolve {org_dir} using the chosen resolver against the current repo.
#   4. Confirm the substituted full path is an existing directory.
#   5. Append the entry to config.json (creating the file with default
#      schema if missing).
#   6. On stdout: print the resolved absolute path so the caller can use it.
#
# Exit codes:
#   0 = appended; stdout = absolute principle dir path that now resolves
#   1 = validation failed; stderr explains why (no write performed)
#   2 = environment problem (not a git repo, jq missing)
#   64 = usage error

set -euo pipefail

CONFIG_FILE="${CODE_REVIEWER_CONFIG_FILE:-${HOME}/.claude/code-reviewer/config.json}"
LIFEOS_DEFAULT="${HOME}/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS"

die()      { echo "$1" >&2; exit 1; }
die_env()  { echo "$1" >&2; exit 2; }
die_use()  { echo "$1" >&2; exit 64; }

base="${1:-}"
pattern="${2:-}"
resolver="${3:-}"

[[ -n "$base" && -n "$pattern" ]] || \
  die_use "Usage: $(basename "$0") <base> <pattern> [org_resolver]"

[[ "$pattern" == *"{repo}"* ]] || \
  die "Pattern must contain '{repo}' placeholder. Got: $pattern"

if [[ -n "$resolver" && "$resolver" != "handover_handler" ]]; then
  die_use "Unknown org_resolver: $resolver (supported: handover_handler, or omit)"
fi

command -v jq &>/dev/null || \
  die_env "jq is required. Install with: brew install jq"

# Derive owner/repo from current git remote
remote_url=$(git remote get-url origin 2>/dev/null || true)
[[ -n "$remote_url" ]] || die_env "Not in a git repo with an 'origin' remote."

slug=$(echo "$remote_url" \
  | sed -E 's#^(git@|https?://)([^/:]+)[/:]##; s#\.git$##')
[[ "$slug" == */* ]] || die_env "Could not parse owner/repo from remote: $remote_url"

owner="${slug%%/*}"
repo="${slug##*/}"

# Expand base
expand_path() {
  local p="$1"
  p="${p/#\~/$HOME}"
  p="${p//\$LIFEOS/${LIFEOS:-$LIFEOS_DEFAULT}}"
  p="${p//\$HOME/$HOME}"
  echo "$p"
}

base_expanded=$(expand_path "$base")
[[ -d "$base_expanded" ]] || die "Base directory does not exist: $base_expanded"

# Resolve org_dir
if [[ "$resolver" == "handover_handler" ]]; then
  org_dir=""
  for init in "$base_expanded"/*/handover_handler__initiation.md; do
    [[ -f "$init" ]] || continue
    org_line=$(awk '/^github_orgs:/{print; exit}' "$init" 2>/dev/null || true)
    [[ -n "$org_line" ]] || continue
    stripped=$(echo "$org_line" | sed -E 's/.*\[(.*)\].*/\1/')
    IFS=', ' read -ra orgs <<< "$stripped"
    for o in "${orgs[@]}"; do
      [[ -z "$o" ]] && continue
      if [[ "$o" == "$owner" ]]; then
        org_dir=$(basename "$(dirname "$init")")
        break 2
      fi
    done
  done
  [[ -n "$org_dir" ]] || \
    die "handover_handler resolver: no ORG under $base_expanded lists github_org '$owner' in its initiation.md"
else
  org_dir="$owner"
fi

# Substitute and validate
sub="${pattern//\{org_dir\}/$org_dir}"
sub="${sub//\{repo\}/$repo}"
candidate="$base_expanded/$sub"

[[ -d "$candidate" ]] || \
  die "Substituted path does not exist: $candidate (org_dir='$org_dir', repo='$repo')"

# Seed config if missing or empty (mktemp creates empty placeholder files)
mkdir -p "$(dirname "$CONFIG_FILE")"
if [[ ! -s "$CONFIG_FILE" ]]; then
  echo '{"version":1,"roots":[]}' > "$CONFIG_FILE"
fi

# Append the new root (skipping duplicates by base+pattern)
tmp=$(mktemp)
jq --arg base "$base" \
   --arg pattern "$pattern" \
   --arg resolver "$resolver" \
   '
   .roots = (
     (.roots // [])
     | map(select(.base != $base or .pattern != $pattern))
     | . + [{
         base: $base,
         pattern: $pattern,
         org_resolver: (if $resolver == "" then null else $resolver end)
       } | with_entries(select(.value != null))]
   )
   ' "$CONFIG_FILE" > "$tmp"
mv "$tmp" "$CONFIG_FILE"

echo "$candidate"
