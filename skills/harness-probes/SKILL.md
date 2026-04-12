---
name: harness-probes
description: "Guide for adding custom probes to the autoresearch harness-check system."
---

# Harness Probes

This skill describes how probes work and how to add new ones.

## Probe Contract

Every probe is a bash function in `lib/probes.sh` that:

1. Takes a tool name as its first argument (or empty/"null" to skip)
2. Prints a single JSON object to stdout
3. Returns exit code 0 (even on skip)

### Required JSON Shape

```json
{
  "category": "string",
  "score": "0-100 | null",
  "max": 100,
  "skipped": "true | false",
  "reason": "string (only if skipped)",
  "tool": "string | null",
  "findings": [
    { "type": "string", "file": "string" }
  ],
  "fix_targets": ["file/paths"],
  "estimated_iterations": 1
}
```

### Score Calculation

- Start at 100 (perfect)
- Deduct points per finding based on severity
- Clamp to 0 minimum
- Return null if skipped

### Adding a New Probe

1. Add a detection case in `ar_probe_detect_tooling()`
2. Write the `ar_probe_<name>()` function following the contract above
3. Add the call to `ar_probe_run_all()`
4. Add the weight in `ar_harness_init()` (in `lib/harness.sh`)

### Example: Adding a security probe

```bash
ar_probe_security() {
  local tool="${1:-}"
  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    echo '{"category":"security","score":null,"max":100,"skipped":true,"reason":"no security scanner detected","tool":null,"findings":[],"fix_targets":[],"estimated_iterations":0}'
    return 0
  fi
  # Run scanner, parse output, return JSON...
}
```

Then add `"security": 1.3` to the weights dict in `ar_harness_init()`.
