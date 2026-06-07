---
description: "[DEPRECATED] Moved to /harness:check. This alias forwards or instructs install."
allowed-tools: ["Read", "Bash"]
---

# /autoresearch:harness-check (deprecated alias)

This command has moved to the `harness` plugin.

## Step 1: Check whether `harness` is installed

```bash
harness_check=$(find -L ~/.claude/plugins -path '*/harness/commands/check.md' -print -quit 2>/dev/null)
if [ -z "${harness_check}" ]; then
  install_status="missing"
else
  install_status="installed"
fi
echo "STATUS: ${install_status}"
```

## Step 2: Tell the user

If `STATUS: installed`, print:

> ⚠️  `/autoresearch:harness-check` has moved to `/harness:check`. This alias will be removed in autoresearch 2.0. Forwarding now...

Then dispatch the new command in your next response (do **not** try to source the harness libs directly from here — just instruct the user to run `/harness:check` and stop).

If `STATUS: missing`, print:

> ⚠️  `/autoresearch:harness-check` has moved to a new plugin called `harness`. Install it from the PersonalPlugins repo (sibling of autoresearch) and then run `/harness:check`. This alias will be removed in autoresearch 2.0.

Stop.
