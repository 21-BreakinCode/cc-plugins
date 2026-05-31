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
