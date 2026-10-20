---
description: "Multi-agent PR review with an interactive review page: five common reviewers plus an optional repo-specific policy layer"
argument-hint: "<pr-number>"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Agent", "AskUserQuestion", "Skill", "ToolSearch", "Artifact", "ArtifactData"]
---

# Multi-agent PR Review

**PR Number**: $ARGUMENTS

Every run is a new review. For a PR that you reviewed before, run every step again, and publish a new page with empty choices. Never look up, read, reuse, or update an older review page or its db.

## Step 1: Validate input

If `$ARGUMENTS` is empty or not numeric, tell the user:

> Usage: `/code-reviewer:review-pr <pr-number>` (for example, `/code-reviewer:review-pr 5`)

Then stop.

## Step 2: Fetch PR metadata

```bash
gh pr view $ARGUMENTS --json number,title,body,url,headRefName,baseRefName,headRefOid,additions,deletions,changedFiles,files,state,author
```

If the command fails, the active gh account can be one that cannot see this repo. List the other accounts with `gh auth status`. For each other account, run the same command again with `GH_TOKEN="$(gh auth token --user <login>)"` in front of `gh`. When one works, set `GH_LOGIN=<login>`, and put the same prefix in front of every later `gh` command of this review. Never run `gh auth switch`, and never print a token. If no account works, tell the user the PR was not found and stop.

Display a brief summary:
- PR title, author, branch, changed file count

## Step 3: Find the latest base

Take `<owner>/<repo>` from the PR `url`.

```bash
gh api "repos/<owner>/<repo>/branches/<baseRefName>" --jq .commit.sha
```

Keep the output as `LATEST_BASE`. If the command fails, `LATEST_BASE` is empty, and the review has no base drift check. Then check which commits the local clone has. If `LATEST_BASE` is empty, run only the first line.

```bash
git cat-file -e "<headRefOid>^{commit}" && echo HEAD_LOCAL=yes || echo HEAD_LOCAL=no
git cat-file -e "<LATEST_BASE>^{commit}" && echo BASE_LOCAL=yes || echo BASE_LOCAL=no
```

If either line says `no`, ask with `AskUserQuestion` before you fetch:

- "Fetch (recommended)": run `git fetch <remote> <baseRefName> "pull/<number>/head"`. `<remote>` is the remote whose URL has `<owner>/<repo>`, usually `origin`. The fetch adds commits to the local clone and changes no branch or file.
- "Skip": the reviewers read the diff only. Without the PR head, there is no review page. Without the latest base, there is no base drift check.

## Step 4: Ask user for context

Use `AskUserQuestion`:

> "What is this PR about? This helps focus the review on what matters. (For example, 'New feature for user authentication', 'Bugfix for login timeout on slow networks', 'Refactoring payment module to use new SDK')"

Free-text. Wait for the response.

## Step 5: Dispatch the orchestrator

Launch `code-reviewer:pr-review-orchestrator` with the Agent tool and this prompt:

```
Review PR #<number>

PR metadata:
<paste the gh pr view output>

User context: "<user description>"
LATEST_BASE=<sha, or empty>
GH_LOGIN=<login, or empty>

Run Phase 1 to Phase 6 and emit the report.
```

The orchestrator prepares the shared input and test-merges the PR into the latest base. It resolves the policy dir, dispatches the reviewers in parallel, and writes the report. It asks no questions. When the orchestrator returns, print its report to the user verbatim. Keep `REVIEW_DIR` and `REPO_ROOT` from its `Review files:` line.

## Step 6: Build the review page

If the local clone does not have the PR head, skip Steps 6 to 8. Tell the user that the review page needs the PR head in the local clone.

Launch `code-reviewer:review-page-builder` with the Agent tool and this prompt:

```
REVIEW_DIR=<path>
REPO_ROOT=<path>
CONTEXT=<user context>
```

It writes `page.json`, builds the page, and returns `PAGE_FILE=<path>`. If it returns `error: ...`, show the error and stop. The report above is then the full result.

## Step 7: Publish the review page

1. Load the `artifact-design` skill, or call the Artifact tool with `action: "quickstart"` and `intent: "other"`. Then load the `artifact-capabilities` skill. The page is already designed and built, so keep its design. Compare the db calls of the page script with the `db.d.ts` of the skill: `claude.use("db")`, `doc(path).set(body)`, `doc(path).onSnapshot`, and `collection(path).onSnapshot`. If they do not match, tell the user and stop.
2. Read the whole page file with the Read tool, with `offset` and `limit`. The builder keeps every line short. You publish only what you read. If a code block shows a secret, such as a key, a token, or a password, do not publish. Tell the user which ref shows it.
3. Call the Artifact tool with `file_path: "<PAGE_FILE>"`, `capabilities: {"db": {}}`, `icon: "code"`, and a one-sentence `description`. Leave out `url`. Each run has a new REVIEW_DIR, so the file path is new, and the tool makes a new private page.
4. Run one ArtifactData `list` on the `decisions` collection of the new page. If the ArtifactData tool is deferred, load it with ToolSearch (`select:ArtifactData`). A new page has no documents.
5. Give the user the link, and tell them: "Choose a call for each finding, answer the overall questions, and press I am done. Then tell me in the chat. After the review is on GitHub, I delete the page. Claude Code then shows you a delete prompt."

To fix the page during the same review, edit `<REVIEW_DIR>/page.json`, and keep every finding id. Run the builder again, read the changed lines, and publish the same `PAGE_FILE` again without `icon` and `capabilities`. The tool updates the same page, and the saved choices stay.

## Step 8: Post the review

When the user says that they are done:

1. Read the choices with ArtifactData: `list` on collection `decisions`, and `get` on collection `review` with `doc_id` `overall`. Each `decisions/<finding id>` document has `decision`, `fix`, and `note`. The `review/overall` document has `github_action`, `posting`, `note`, and `readyAt`. If the page did not save and the user pasted the feedback text, use that text. The notes are the user's guidance for the review text. If a note asks for something else, ask the user in the chat first.
2. If `github_action` is `hold`, do not post and do not delete the page. Tell the user that the page stays, and stop.
3. If a finding has no call or the call `discuss`, talk it over with the user in the chat. When each finding has `block`, `suggest`, or `skip`, continue.
4. Draft the review:
   - The event: `request_changes` is `--request-changes`, `comment` is `--comment`, and `approve` is `--approve`.
   - The body: one line on what is done well. Then "Before merge" with the `block` findings, and "Suggestions" with the `suggest` findings. Leave out the `skip` findings.
   - Each finding: its title, a link to `<repo url>/blob/<headRefOid>/<file>#L<line>`, and the chosen fix. If the steps of the fix help, add them.
   - Write the body in simple English to `<REVIEW_DIR>/review-body.md`, and show it in the chat in full.
5. Ask for approval with `AskUserQuestion`: "Post it", "Change it first", or "Do not post". Never post without approval. For "Change it first", change the draft and ask again. For "Do not post", keep the page, and stop.
6. Post the review:
   - If `posting` is `claude_after_ok`, run `gh pr review <number> <event> --body-file "<REVIEW_DIR>/review-body.md"`. When `GH_LOGIN` is set, use the `GH_TOKEN` prefix. If the command fails, show the error, keep the page, and stop.
   - If `posting` is `me`, give the user the text and the event to choose on GitHub. Then use `AskUserQuestion` to ask about the post. When the user did not post it, keep the page, and stop.
7. Delete the page once: call the Artifact tool with `action: "delete"` and the page `url`. Do not ask about the delete with `AskUserQuestion` first. That answer does not count for the tool. The tool shows its own prompt for every delete, and that prompt is expected. When no one can answer the prompt in this session, the tool refuses the delete. If the tool refuses the delete, do not try again. Give the user the page URL and these steps: in the Claude Code terminal, run `/artifacts`, select the page, and press `d`. On claude.ai, open the page and delete it from its menu.
8. When the review is on GitHub, the review is finished. This is also true after a failed delete. Tell the user the PR link, and whether the page is deleted.
