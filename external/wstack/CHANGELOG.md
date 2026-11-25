# Changelog

## 0.9.0 - 2026-11-25

- **feat:** `/wstack:open-contract [<service>] [--note]` opens the HTML page of a service contract. With no service name, it opens the contract of the current repository. `--note` opens the vault note in Obsidian. It renders the view again first when the view is missing or older than the contract. If no contract matches, it lists the rendered contracts. A session can run it on its own when you ask to see a contract. The new script `scripts/contract-open.sh` does the work.
- **fix:** The vault note and the HTML page show no `Open questions` heading when the section has no items.
- **fix:** Deliver of a `contract` task makes the `decisions/` folder only when it copies a decision file. Before, it left an empty folder.

## 0.8.0 - 2026-11-24

- **feat:** The service contract is a YAML file, `<app_name>.contract.yaml`, with seven fixed sections. Scripts generate two views from it: a vault note, `<app_name>.md`, and an HTML page in `~/.wstack/pages/contracts/`. Every write through `contract-edit.sh` renders both views.
- **feat:** New scripts: `contract-validate.sh` checks the schema. `contract-refs.sh` proves that every ref exists at its commit. `contract-render.sh` writes the views. `contract-deliver.sh write|undo|rehearse` delivers a `contract` task, undoes it all or nothing, and rehearses both on copies. `contract-verify-draft.sh` runs the four draft checks.
- **feat:** `contract-check.sh --coverage` proves that the `sources` globs claim every tracked file. `--mapping-from <path>` lets a draft in a task folder find its dependencies.
- **feat:** Verify re-reviews an edit made after the last review. It uses the diff since that review.
- **feat:** Execute fetches another repository before it cites it.
- **feat:** Deliver's Finish gives a file tree, the repositories that did not change, and the open commands.
- **change:** Plan items live in the contract, in `planned`. The file `plan.md` is gone.
- **change:** Repository ADRs are a `team_docs` glob. A `contract` task no longer copies them into decision files.
- **change:** When a doc and the code disagree, the task writes the case to `disagreements.md`, and Deliver copies it into the report.
- **change:** The reader's patch is YAML with a `sections:` map. The task files are `contract.draft.yaml`, `contract.before.yaml`, `contract.gate-patch.yaml`, and `contract.patch.yaml`.
- **change:** `yq` version 4.22.1 or later (mikefarah) is a new required tool. `scripts/preflight.sh` checks it.
- **fix:** A rebuild keeps `<app_name>.facts.md` in place. Before, the archive step moved it into `_archive/`.
- **breaking:** Migration: rebuild each existing contract with a `contract` task. Deliver archives the old Markdown files in `_archive/<task_id>/`.

## 0.7.0 - 2026-11-23

- **feat:** `/wstack:init-service <repo-path> ...` sets up each repository you name, in order, from any folder. With no path, it sets up the current folder as before. A path that is not a git work tree is reported, and the other paths still run. The report has one block per repository.
- **feat:** `/wstack:init-service --check` checks every row of the org's service mapping table and changes nothing. For each row, it reports the repository, the `./handover` link, the ignore rule, the vault folder, and the contract state. It warns about an `app_name` that is not kebab-case, and it offers the setup for the rows that need it. The new script `scripts/handover/check-mapping.sh` does the check.
- **change:** `/wstack:init-service` asks you to approve each repository before any write, also a repository that is already mapped. The question shows the link path and the exclude file path.
- **fix:** The retro's `age_days` count is exact. `collect-week.sh` took the time of day from the clock for each date. When the clock passed a second between two dates, a task counted one day younger, and a test failed now and then.

## 0.6.1 - 2026-11-23

- **fix:** `check-page-width.sh` prints only the page width. Under bash 3.2, stopping its local server added a `Terminated: 15` job notice to the output, so a caller that read the width failed.

## 0.6.0 - 2026-11-23

- **feat:** The retro reads every finished task once, whatever its start date. It marks each task it read with `retro_read` in `spec.md`, so a long task is no longer missed.
- **feat:** After the user agrees in the retro, read tasks move to `Tasks/_archive/<week>/<task_id>/`. The move uses `obsidian move`, so Obsidian rewrites the links to the moved notes. A failed move puts the files back, and the retro tries again next week.
- **feat:** Each project with a contract keeps a facts file, `<app_name>.facts.md`, next to its contract. The retro proposes fact candidates from the exit notes and from repeated corrections. The user accepts or rejects each one, and every later task session of the project reads the accepted facts at `Confirmation`.
- **feat:** `/wstack:board` shows the size of each task's changes, for example `2 files +4 -1`, and the live monitor shows it too.
- **feat:** `/wstack:board` shows a `stalled` group: a task session in the `executing` or `verifying` stage while herdr reports it idle or done.
- **feat:** In `Verify`, a test run that reports skipped cases fails its step. A skip that the spec names with a reason is allowed. `Verify` also lists each place that still names a renamed or moved path, and the reviewer judges each one.
- **change:** `spec.html` and `review.html` live in `~/.wstack/pages/<task_id>/`, outside the vault. `build-review-page.sh` takes a required `--page <path>`.
- **change:** A code task started outside herdr puts its worktree under the herdr worktree root, at `<root>/<repo>/<branch-slug>`, not at `~/.wstack/tasks/<task_id>`.
- **change:** The spec template has a new section, `## Moves and renames`.
- **docs:** The README, the spec, and the design describe the archive, the facts file, the task pages, the board changes, and the guards.

## 0.5.0 - 2026-11-23

- **feat:** `/wstack:board` lists every open task session (RD) in groups: needs you, stopped, working, paused, finished, and other. It also writes a Notion-style snapshot page, `Board/board.html`. It offers to close the workspaces of finished tasks, and it skips a worktree that has changes.
- **feat:** `/wstack:board --watch` opens a live monitor in a herdr pane. Every 3 seconds it shows the stage of each RD, its last tool call, and the subagents that run now with their last tool call. A Bash call shows only its description, never its command text.
- **feat:** Each task records the id of every Claude session that worked on it, in `session_ids` in `spec.md`. A restart resumes the last session by its id.
- **feat:** Deliver counts tokens by session id. The new `subagent_tokens` field holds the tokens of the subagents, and `tokens_used` keeps its old meaning.
- **feat:** At Deliver, and at a cancel after the retry limit, the RD writes `retro-note.md`. The note lists slow steps, steps to turn into scripts, gaps in the spec, tool and guard friction, and surprises.
- **feat:** `/wstack:run-retro` reads the exit notes and the transcript stats of each task: tool calls, errors, repeated commands, and compactions. A repeated command keeps only its command name and the subcommand of a tool such as git. No quoted text or secret reaches the retro files. If the evidence raises a question about one task, the retro asks a read-only fork of that RD's session. It records the answer under `## RD answers`.
- **change:** An RD that opens a herdr pane opens it in its own workspace and closes it before Deliver.
- **change:** `render-page.sh` takes an optional `--theme-file <path>`.
- **docs:** The README, the spec, and CLAUDE.md describe the board, the monitor, the exit note, and the retro reopen.

## 0.4.1 - 2026-11-23

- **fix:** The contract scripts reject a block-style YAML list for `ignore` or `pending`. Before, such a list read as empty, and the check reported `fresh`. Now `contract-check.sh` and `contract-edit.sh` exit 2 and name the key. A blank line or a comment line before the first item does not hide the list.
- **fix:** `contract-check.sh` exits 2 on a missing or empty argument. Before, it exited 1, which means stale.
- **fix:** The guard no longer asks for a command that only reads a file that names a guarded command, such as `cat scripts/evidence-delete.sh`. Every part of the command must be a read-only tool. The tools are `cat`, `head`, `tail`, `grep`, `wc`, `ls`, `file`, `stat`, `diff`, and `nl`. The git commands are `diff`, `show`, `log`, `blame`, and `status`. The tool must be called by name and not by path. A git option before the subcommand other than `-C`, `--no-pager`, `-P`, or `--no-optional-locks` gets the normal check. So does a command that runs other commands, for example with `bash`, `eval`, `xargs`, or `-exec`. A backtick or a `$` expansion other than a plain `$name` also gets the normal check. A redirect with `>` also gets the normal check.
- **fix:** The guard also asks before `yarn npm publish`.
- **fix:** The Deliver contract undo also removes the empty `decisions/` and `_archive/` folders.
- **fix:** The contract tag uses the same kebab rule as `create-handover`, so the org `BreakinCode` gives `project/breakin-code/<service>`.
- **docs:** The text in `start-task/references/confirmation.md` says where the gate changes the contract (step G4 and step 9). The `contract-edit.sh` comment no longer claims it is the only writer.

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
