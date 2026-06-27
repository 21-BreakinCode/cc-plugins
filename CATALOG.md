# Plugin Catalog

> Auto-generated from `.claude-plugin/marketplace.json` + `content/plugins.content.json`.
> Do not edit by hand — run `./scripts/cicd.sh GEN`.
>
> **21-breakincode** v1.7.4 · 7 plugins · [`21-BreakinCode/cc-plugins`](https://github.com/21-BreakinCode/cc-plugins)

## Install everything

```bash
claude plugin marketplace add 21-BreakinCode/cc-plugins && \
  claude plugin install session-learner@21-breakincode && \
  claude plugin install autoresearch@21-breakincode && \
  claude plugin install harness@21-breakincode && \
  claude plugin install remotion-maker@21-breakincode && \
  claude plugin install hh@21-breakincode && \
  claude plugin install code-reviewer@21-breakincode && \
  claude plugin install uiux-optimizer@21-breakincode
```

## Update everything

Third-party marketplaces don't auto-update by default — refresh the catalog, then
update each installed plugin:

```bash
claude plugin marketplace update 21-breakincode && \
  claude plugin update session-learner@21-breakincode && \
  claude plugin update autoresearch@21-breakincode && \
  claude plugin update harness@21-breakincode && \
  claude plugin update remotion-maker@21-breakincode && \
  claude plugin update hh@21-breakincode && \
  claude plugin update code-reviewer@21-breakincode && \
  claude plugin update uiux-optimizer@21-breakincode
```

## Memory & Knowledge

### [session-learner](./session-learner/README.md) · `v1.1.2`

*Give Claude a memory across sessions*

Persists each session's context to disk and injects git-aware context on startup, so a new session knows what changed in the repo and what you did last time. Harvests learnings into Zettelkasten notes via /take-away and /digest.

**Install** · `claude plugin install session-learner@21-breakincode`

**Commands** · `/session-learner:digest` · `/session-learner:take-away`

## Measure & Improve

### [autoresearch](./autoresearch/README.md) · `v1.2.2`

*Eval-driven, autonomous code improvement*

Runs an edit → eval → keep/discard loop on any artifact — code, prompts, or docs — scoring each change with a shell command, an LLM judge, or both. Keeps what passes, reverts what doesn't, and shows progress on a live auto-refreshing dashboard.

**Install** · `claude plugin install autoresearch@21-breakincode`

**Commands** · `/autoresearch:improve`

### [harness](./harness/README.md) · `v1.0.1`

*Build the feedback machinery around your agent*

Scores project health across six categories, then scaffolds the Tier-1 harness components a project is missing — feedback loops, evals, sensors, and context-mgmt advisories — and auto-fixes the top-ranked issue by delegating to autoresearch.

**Install** · `claude plugin install harness@21-breakincode`

**Commands** · `/harness:build` · `/harness:check` · `/harness:improvement`

## Review & Design

### [code-reviewer](./code-reviewer/README.md) · `v0.2.0`

*Principle-aware PR review*

Layers a repo-specific review-mindset agent on top of pr-review-toolkit's 4+6 perspectives, citing your repo's own distilled principles, hotspots, and red-flags. Degrades gracefully to the standard review when no principle directory exists.

**Install** · `claude plugin install code-reviewer@21-breakincode`

**Commands** · `/code-reviewer:review-pr`

### [uiux-optimizer](./uiux-optimizer/README.md) · `v1.2.2`

*Reference-driven UI/UX design advisor*

Orchestrates live design references (refero.design + the getdesign.md catalogue), anti-slop taste discipline, and motion choreography across audit / build / explore modes and a gated ship pipeline. Degrades gracefully when the optional taste and motion skills aren't installed.

**Install** · `claude plugin install uiux-optimizer@21-breakincode`

**Skills** · `uiux-optimizer`

## Workflow & Handover

### [hh](./handover-handler/README.md) · `v0.1.5`

*Cross-context handover docs, LifeOS as the source of truth*

Bridges your Obsidian LifeOS vault and each repo through a ./handover symlink, so handover documents survive context switches and stay visible to editors, grep, Obsidian, and Claude alike. Includes a daily vault-wide wrap-up state machine.

**Install** · `claude plugin install hh@21-breakincode`

**Commands** · `/hh:init-org` · `/hh:init-service` · `/hh:new` · `/hh:wrap-up`

## Media

### [remotion-maker](./remotion-maker/README.md) · `v0.1.0`

*Generate styled Remotion videos, end to end*

A full pipeline for Remotion (React) videos: define a consistent style, generate scenes from your content, source free media, review preview frames, and verify against the style before rendering to MP4.

**Install** · `claude plugin install remotion-maker@21-breakincode`

**Commands** · `/remotion-maker:create` · `/remotion-maker:define-style` · `/remotion-maker:find-media` · `/remotion-maker:verify`
