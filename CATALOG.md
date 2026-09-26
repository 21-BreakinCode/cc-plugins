# Plugin Catalog

> Auto-generated from `.claude-plugin/marketplace.json` + `content/plugins.content.json`.
> Do not edit by hand — run `./scripts/cicd.sh GEN`.
>
> **21-breakincode** v2.1.0 · 6 plugins · [`21-BreakinCode/cc-plugins`](https://github.com/21-BreakinCode/cc-plugins)

## Install everything

```bash
claude plugin marketplace add 21-BreakinCode/cc-plugins && \
  claude plugin install autoresearch@21-breakincode && \
  claude plugin install code-reviewer@21-breakincode && \
  claude plugin install humanize@21-breakincode && \
  claude plugin install adhd-review@21-breakincode && \
  claude plugin install receipts@21-breakincode && \
  claude plugin install obsidian-kit@21-breakincode
```

## Update everything

Third-party marketplaces don't auto-update by default — refresh the catalog, then
update each installed plugin:

```bash
claude plugin marketplace update 21-breakincode && \
  claude plugin update autoresearch@21-breakincode && \
  claude plugin update code-reviewer@21-breakincode && \
  claude plugin update humanize@21-breakincode && \
  claude plugin update adhd-review@21-breakincode && \
  claude plugin update receipts@21-breakincode && \
  claude plugin update obsidian-kit@21-breakincode
```

## Measure & Improve

### [autoresearch](./autoresearch/README.md) · `v2.2.3`

*Eval-driven improvement, plus the harness to drive it*

Two parts form one loop. An edit → eval → keep/discard engine improves code, prompts, or docs. It scores each change with a shell command, an LLM judge, or both. It shows progress in a live Artifact dashboard. A harness builder measures project health in six categories. It creates feedback loops, evals, sensors, and context management advisories. It then fixes the top-ranked issue through the same loop.

**Install** · `claude plugin install autoresearch@21-breakincode`

**Commands** · `/autoresearch:harness-build` · `/autoresearch:harness-check` · `/autoresearch:harness-improvement` · `/autoresearch:improve`

## Review & Design

### [code-reviewer](./code-reviewer/README.md) · `v1.1.1`

*Principle-aware PR review*

Layers a repo-specific review-mindset agent on top of pr-review-toolkit's 4+6 perspectives, citing your repo's own distilled principles, hotspots, and red-flags. Degrades gracefully to the standard review when no principle directory exists. Includes `refresh-principles`, which learns the repo's own principle files from merged git + PR history.

**Install** · `claude plugin install code-reviewer@21-breakincode`

**Commands** · `/code-reviewer:review-pr`

### [receipts](./receipts/README.md) · `v0.4.0`

*No claim without a receipt*

A Stop hook that enforces provable claims. When the finished turn asserts a **FACT:** or a completion ('verified', 'tests pass', 'fixed', 'done'), a free deterministic prefilter checks it against that turn's real tool calls; only genuinely ambiguous claims escalate to a fresh-context Haiku judge. Unbacked claims are flagged with a ⚠ note (default `warn` mode) — or hard-gate the turn in `block` mode, where Claude must prove each with a real tool call or downgrade it to **ASSUME:** — bounded to one challenge per claim per session (ledger + stop_hook_active backstop). Enforces the fact-assume discipline (FACT = provable if challenged) that RLHF's confident 'done' quietly erodes. On by default and fail-open; set CLAUDE_RECEIPTS=0 to disable. /receipts prints the session's audit ledger and sets the mode.

**Install** · `claude plugin install receipts@21-breakincode`

**Commands** · `/receipts:receipts`

## Workflow & Handover

### [adhd-review](./adhd-review/README.md) · `v0.6.0`

*Action-first replies, blockers before FYI*

One ruleset, three layers. Layer 1 shapes every reply — lead with the action, number multi-step work with time estimates, cut preamble/recap/closers, state errors matter-of-factly. Layer 2 governs the final turn of substantial multi-step work with Review-Ready buckets — ✅ Done / ⚠️ Broken / 🙋 What I need from you / 🤖 What I'll do, blockers before FYI, each ask naming why it's yours. A Visual Layer draws non-linear flow-shaped concepts — branches, loops, state changes, hierarchies — as fenced ASCII diagrams instead of prose, while linear steps stay numbered lists. Applies to the human-facing thread only: a default-on SessionStart hook injects the rules into the main session, so subagent returns stay full-detail. On by default — installing the plugin shapes the main thread out of the box; set CLAUDE_ADHD_REVIEW=0 to silence a session. Toggle per session with /adhd-review-mode.

**Install** · `claude plugin install adhd-review@21-breakincode`

**Skills** · `adhd-review-mode`

## Writing & Content

### [humanize](./humanize/README.md) · `v0.1.1`

*Sound like a person, in zh-TW or English*

Two skills. distill captures your voice from writing samples into a reusable tone preset; rewrite strips AI-tells from existing text (PR comments, posts, emails) and matches a tone, preserving meaning and never inventing facts. Separate Traditional-Chinese and English rulesets, auto-detected, plus a flag-only audit mode.

**Install** · `claude plugin install humanize@21-breakincode`

**Skills** · `distill` · `rewrite`

### [obsidian-kit](./obsidian-kit/README.md) · `v2.0.0`

*One plugin for the vault: draw, format, tag*

create-excali and update-excali build Excalidraw drawings through ExcalidrawAutomate, lint the geometry, and review the real PNG render. format-note writes and checks notes by their note-type (map, concept, takeaway, literature, fleeting) and keeps the ASCII-diagram and callout rules of the old visualize skill. migrate-notes sets note-type across a vault and renames map notes, as one approved plan. audit-tags finds false, duplicate, typo, and off-taxonomy tags and applies one approved rename plan with backups. handover-new, handover-wrap-up, handover-init-org, and handover-init-service create and wrap up handover documents backed by the vault. session-wrap-up, session-pick-up, and session-recommend turn a working session into reflection take-aways and, after one approval, Zettelkasten cards in the vault. A dedicated skill writes and checks controlled Traditional Chinese inside the vault. A SessionStart hook primes Claude to treat the obsidian CLI as the source of truth. Vault opinions live in the vault file .obsidian-kit.json. No cross-plugin deps.

**Install** · `claude plugin install obsidian-kit@21-breakincode`

**Commands** · `/obsidian-kit:handover-init-org` · `/obsidian-kit:handover-init-service` · `/obsidian-kit:handover-new` · `/obsidian-kit:handover-wrap-up`
