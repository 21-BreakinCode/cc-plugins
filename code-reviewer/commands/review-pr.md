---
description: "Multi-agent PR review: five common reviewers plus an optional repo-specific policy layer"
argument-hint: "<pr-number>"
allowed-tools: ["Bash", "Read", "Agent", "AskUserQuestion"]
---

# Multi-agent PR Review

**PR Number**: $ARGUMENTS

## Step 1: Validate input

If `$ARGUMENTS` is empty or not numeric, tell the user:

> Usage: `/code-reviewer:review-pr <pr-number>` (for example, `/code-reviewer:review-pr 5`)

Then stop.

## Step 2: Fetch PR metadata

```bash
gh pr view $ARGUMENTS --json number,title,body,url,headRefName,baseRefName,additions,deletions,changedFiles,files,state,author
```

If the command fails, tell the user the PR was not found and stop.

Display a brief summary:
- PR title, author, branch, changed file count

## Step 3: Ask user for context

Use `AskUserQuestion`:

> "What is this PR about? This helps focus the review on what matters. (For example, 'New feature for user authentication', 'Bugfix for login timeout on slow networks', 'Refactoring payment module to use new SDK')"

Free-text. Wait for the response.

## Step 4: Dispatch the orchestrator

Launch `code-reviewer:pr-review-orchestrator` with the Agent tool and this prompt:

```
Review PR #<number>

PR metadata:
<paste the gh pr view output>

User context: "<user description>"

Run Phase 1 to Phase 6 and emit the report.
```

The orchestrator prepares the shared input, resolves the policy dir, dispatches the reviewers in parallel, and writes the report. It asks no questions. When the orchestrator returns, print its report to the user verbatim.
