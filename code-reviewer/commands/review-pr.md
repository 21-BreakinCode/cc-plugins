---
description: "Principle-aware PR review — layers a repo-specific review mindset on top of the standard 4+6 multi-agent review"
argument-hint: "<pr-number>"
allowed-tools: ["Bash", "Read", "Glob", "Grep", "Task", "AskUserQuestion"]
---

# Principle-aware PR Review

**PR Number**: $ARGUMENTS

## Step 1: Validate input

If `$ARGUMENTS` is empty or not numeric, tell the user:

> Usage: `/code-reviewer:review-pr <pr-number>` (e.g., `/code-reviewer:review-pr 5`)

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

> "What is this PR about? This helps focus the review on what matters. (e.g., 'New feature for user authentication', 'Bugfix for login timeout on slow networks', 'Refactoring payment module to use new SDK')"

Free-text. Wait for the response.

## Step 4: Dispatch orchestrator

Launch `code-reviewer:pr-review-orchestrator` via the `Task` tool with:

```
Review PR #<number>

PR metadata:
<paste gh pr view output>

User context: "<user description>"

Resolve the principle directory (Phase 2), run all reviews in parallel
(Phase 3), and produce the full report (Phase 4).
```

The orchestrator handles principle resolution, the guard prompt on miss, the parallel review dispatch, and the final aggregated report.
