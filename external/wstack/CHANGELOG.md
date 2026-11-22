# Changelog

## 0.4.0 - 2026-11-22

- **feat:** `/wstack:pause-work` stops work in the middle, in any session. It writes a resume note first. Then it stops the background agents, shells, and processes that this session started. The note records what it stopped and what still runs. Inside a wStack task, it also sets the task status to `paused`.
- **feat:** `/wstack:resume-work` finds the newest pause note for the current folder. It compares the git state with the note, shows the note, and goes on from the next step. It never resets or stashes. For a paused task, it prints the command that resumes the task in its own folder.
- **feat:** A new task status, `paused`, with `paused_from` in `spec.md`. `/wstack:start-task --task <task_id>` resumes a paused task, and the open-task list shows it. Notes for a session outside a task go in `~/.wstack/pauses/`.
- **feat:** `/wstack:init-service` checks the service contract as its last step. If the contract exists, it reports the status. If there is none, it offers to launch a contract task. Outside herdr, it creates the task and prints the command that starts it.
- **feat:** `/wstack:run-retro` walks contract drift. It resolves pending write-backs, fetches the base branch, and fast-forwards only a clean base branch. It asks which stale sections to update in the same question as the proposals. It writes the contract under the lock and records the undo under `## Contract`.
- **change:** `/wstack:run-retro` goes on in a week with no task folders, so the drift walk still runs.
- **change:** Outside herdr, a code task gets a worktree at `~/.wstack/tasks/<task_id>`, and you start `claude` there. A leftover `wstack/<slug>` branch stops the launch with exit 6.
- **change:** A failed launch (exit 4 or 6) sets the task to `cancelled`.
- **breaking:** The guard always asks. `WSTACK_GUARD_MODE=deny` and the `WSTACK_APPROVED=1` prefix are gone.
- **fix:** The guard also catches `git` and `gh` called by full path, and it judges each command segment. It sees a switch to the default branch behind a prefix such as `env`, `bash -c`, or `then`.
- **fix:** Web checks run playwright-cli in a scratch folder, pick a free port, and close the browser before they delete the folder. No browser and no `.playwright-cli/` folder stay behind.
- **fix:** The contract scripts handle CRLF files, accept only a hex `verified_commit`, keep file modes, and write `set-verified` in one step. `pending-add` skips duplicates. `apply` warns about a new section and takes a repeatable `--section`. If a write fails, `delete-section` exits 2.
- **fix:** The contract hook matches compound and full-path git commands, but not an echoed one.
- **fix:** The gate undo deletes the sections it added and restores `verified_commit`. A closed pull request sets its decision files to `withdrawn`, and a retried write-back adds no duplicate decisions.
- **fix:** The redactor keeps short counters, such as `max_tokens=4096`, and redacts every other secret value, including a 6-digit code and non-string JSON values.
- **fix:** The evidence step replaces old evidence lines, videos are never scaled up, and images are checked against `pr_media_max_mb`.
- **docs:** The README, the spec, and CLAUDE.md describe the new commands, the drift walk, and the `paused` status.

## 0.3.1 - 2026-11-22

- **fix:** The guard asks before a push that follows a switch to the default branch. It also asks for `git push --all`, for a push inside parentheses, and for `pnpm publish`, `yarn publish`, and `cargo publish`.
- **fix:** The redactor uses one name list for headers, URL parameters, and JSON keys. It also redacts every plain-text evidence file before upload, and it handles text with invalid UTF-8.
- **fix:** A repository in `local_evidence_only_repos` gets a pull request with no attachments, and Deliver leaves text logs out of the body.
- **fix:** A task folder of any earlier day with the same slug now counts as taken, so the new task gets a new slug.
- **fix:** A second retro in the same week writes `<week>-2.md` and keeps the first retro.

## 0.3.0 - 2026-11-22

wStack keeps a service contract for each mapped service, and checks tasks against it.

- **feat:** A contract file in the vault for each mapped service, with `plan.md` and `decisions/` beside it.
- **feat:** A drift check, `contract-check.sh`. It compares `verified_commit` with `origin/<base_branch>` and makes no network call.
- **feat:** A SessionStart hook and a PostToolUse hook. If the contract is stale, they tell the agent. Otherwise they print nothing.
- **feat:** A contract gate for `code` and `ops` tasks, before the spec is written. It writes `contract-brief.md` and a gate patch in the task folder.
- **feat:** A write-back in Deliver. The contract changes after the pull request merges. A closed pull request drops its pending item.
- **feat:** A `contract` work type that sets up or rebuilds a contract. Deliver moves old vault files into `_archive/<task_id>/`.
- **feat:** Two agents: `contract-reader` and `contract-historian`. The reviewer reports a `contract-mismatch` finding.
- **change:** A repository with no service mapping gets no contract. A `contract` task stops and says to run `/wstack:init-service`.
- **change:** Every contract write takes the lock folder `<contract>.lock`. A busy lock stops the task.

## 0.2.0 - 2026-11-21

Four skills have new names. The handover commands of obsidian-kit 2.3.1 now live in wStack.

- **change:** `retro` is now `run-retro`. The command is `/wstack:run-retro`.
- **change:** `review-page` is now `build-review-page`.
- **change:** `evidence` is now `capture-evidence`.
- **change:** `deliver` is now `deliver-task`.
- **feat:** `/wstack:init-org` (was `/obsidian-kit:handover-init-org`).
- **feat:** `/wstack:init-service` (was `/obsidian-kit:handover-init-service`).
- **feat:** `/wstack:create-handover` (was `/obsidian-kit:handover-new`).
- **feat:** `/wstack:wrap-up-handovers` (was `/obsidian-kit:handover-wrap-up`).
- **change:** In wStack, the vault path comes from the wStack `vault_path` setting, not from `OBSIDIAN_KIT_VAULT`.
- **change:** In wStack, `init-service` writes `/handover` to the local git exclude file. It never edits `.gitignore`.
- **change:** In wStack, the resolvers work inside herdr worktrees and read block-list `github_orgs`.
- **change:** In wStack, the archive root is fixed at `04Archive`.

## 0.1.1 - 2026-11-20

- **fix:** A launched task session now gets the idea text, because `new-task-folder.sh` writes it under `## Goal` in `spec.md`.

## 0.1.0 - 2026-11-19

First version. wStack 0.1.0 does the following:

- **feat:** Runs one pipeline from `/wstack:start-task`: Confirmation, Execute, Verify, and Deliver, with fix loops back to Execute and to Confirmation.
- **feat:** Launches each task in its own herdr workspace and Claude session, in a task folder in your Obsidian vault.
- **feat:** Checks the base tools with `scripts/preflight.sh` and prints an install command for each missing tool.
- **feat:** Builds a review page that fits a 375 px screen, with a sticky navbar and an Excalidraw diagram.
- **feat:** Starts a reviewer agent during Verify. It writes findings into `review.md`.
- **feat:** Records evidence, compresses it, and uploads it to a private Cloudflare R2 bucket. It attaches copies to pull requests.
- **feat:** Delivers to the targets in the spec. A merge and every other step that you cannot undo wait for your approval.
- **feat:** Supports mobile mode, which also publishes pages as Claude artifacts.
- **feat:** Runs `/wstack:retro` once a week. A retro analyst agent reads the last 7 days of task folders and proposes improvements.
- **feat:** Guards merges, pushes to the default branch, force pushes, remote branch deletes, R2 deletes, and deploys. It asks you first.
