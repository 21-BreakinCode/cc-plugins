---
description: "[DEPRECATED] Moved to /harness:improvement. This alias forwards or instructs install."
allowed-tools: ["Read", "Bash"]
---

# /autoresearch:harness-improvement (deprecated alias)

This command has moved to the `harness` plugin.

## Step 1: Check whether `harness` is installed

```bash
harness_imp=$(find -L ~/.claude/plugins -path '*/harness/commands/improvement.md' -print -quit 2>/dev/null)
if [ -z "${harness_imp}" ]; then
  install_status="missing"
else
  install_status="installed"
fi
echo "STATUS: ${install_status}"
```

## Step 2: Tell the user

If `STATUS: installed`, print:

> ⚠️  `/autoresearch:harness-improvement` has moved to `/harness:improvement`. This alias will be removed in autoresearch 2.0. Run `/harness:improvement` to proceed.

Stop.

If `STATUS: missing`, print:

> ⚠️  `/autoresearch:harness-improvement` has moved to a new plugin called `harness`. Install it from the PersonalPlugins repo (sibling of autoresearch) and then run `/harness:improvement`. This alias will be removed in autoresearch 2.0.

Stop.
