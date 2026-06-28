# Plugin Catalog

> Auto-generated from `.claude-plugin/marketplace.json` + `content/plugins.content.json`.
> Do not edit by hand — run `./scripts/cicd.sh GEN`.
>
> **21-breakincode** v1.8.0 · 6 plugins · [`21-BreakinCode/cc-plugins`](https://github.com/21-BreakinCode/cc-plugins)

## Install everything

```bash
claude plugin marketplace add 21-BreakinCode/cc-plugins && \
  claude plugin install session-learner@21-breakincode && \
  claude plugin install autoresearch@21-breakincode && \
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
  claude plugin update remotion-maker@21-breakincode && \
  claude plugin update hh@21-breakincode && \
  claude plugin update code-reviewer@21-breakincode && \
  claude plugin update uiux-optimizer@21-breakincode
```

## Memory & Knowledge

### [session-learner](./session-learner/README.md) · `v2.0.0`

*Turn a session into atomic Zettelkasten knowledge*

A wrap-up → pick-up → recommend reflection funnel: wrap-up surfaces session pitfalls and candidate take-away topics, pick-up turns chosen topics into atomic Zettelkasten cards grounded in the real case and up to 3 web sources, and recommend picks the single topic most worth keeping.

**Install** · `claude plugin install session-learner@21-breakincode`

**Skills** · `pick-up` · `recommend` · `wrap-up`

## Measure & Improve

### [autoresearch](./autoresearch/README.md) · `v2.0.0`

*Eval-driven improvement, plus the harness to drive it*

Two halves of one loop. An edit → eval → keep/discard engine improves any artifact — code, prompts, or docs — scoring each change with a shell command, an LLM judge, or both, and showing progress on a live auto-refreshing dashboard. A harness builder scores project health across six categories, scaffolds the Tier-1 components a project is missing — feedback loops, evals, sensors, and context-mgmt advisories — and auto-fixes the top-ranked issue through the same loop.

**Install** · `claude plugin install autoresearch@21-breakincode`

**Commands** · `/autoresearch:harness-build` · `/autoresearch:harness-check` · `/autoresearch:harness-improvement` · `/autoresearch:improve`

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
