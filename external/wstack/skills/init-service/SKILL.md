---
name: init-service
description: "Per-repo setup. Adds a repo to the service mapping table and creates the ./handover symlink into LifeOS. Takes repo paths, or --check for a read-only check of every mapped row."
argument-hint: "[<repo-path> ...] | --check"
allowed-tools: ["Bash", "Read", "Write", "Edit", "AskUserQuestion"]
disable-model-invocation: true
---
