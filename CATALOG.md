# Plugin Catalog

> Auto-generated from `.claude-plugin/marketplace.json` + `content/plugins.content.json`.
> Do not edit by hand — run `./scripts/cicd.sh GEN`.
>
> **21-breakincode** v1.11.0 · 10 plugins · [`21-BreakinCode/cc-plugins`](https://github.com/21-BreakinCode/cc-plugins)

## Install everything

```bash
claude plugin marketplace add 21-BreakinCode/cc-plugins && \
  claude plugin install session-learner@21-breakincode && \
  claude plugin install autoresearch@21-breakincode && \
  claude plugin install remotion-maker@21-breakincode && \
  claude plugin install hh@21-breakincode && \
  claude plugin install code-reviewer@21-breakincode && \
  claude plugin install uiux-optimizer@21-breakincode && \
  claude plugin install humanize@21-breakincode && \
  claude plugin install adhd-review@21-breakincode && \
  claude plugin install receipts@21-breakincode && \
  claude plugin install woop@21-breakincode
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
  claude plugin update uiux-optimizer@21-breakincode && \
  claude plugin update humanize@21-breakincode && \
  claude plugin update adhd-review@21-breakincode && \
  claude plugin update receipts@21-breakincode && \
  claude plugin update woop@21-breakincode
```

## Memory & Knowledge

### [session-learner](./session-learner/README.md) · `v2.1.0`

*Turn a session into atomic Zettelkasten knowledge*

A wrap-up → pick-up → recommend reflection funnel: wrap-up surfaces session pitfalls and candidate take-away topics, pick-up turns chosen topics into atomic Zettelkasten cards grounded in the real case and up to 3 web sources, and recommend picks the single topic most worth keeping.

**Install** · `claude plugin install session-learner@21-breakincode`

**Skills** · `pick-up` · `recommend` · `wrap-up`

## Measure & Improve

### [autoresearch](./autoresearch/README.md) · `v2.1.0`

*Eval-driven improvement, plus the harness to drive it*

Two halves of one loop. An edit → eval → keep/discard engine improves any artifact — code, prompts, or docs — scoring each change with a shell command, an LLM judge, or both, and showing progress on a live auto-refreshing dashboard. A harness builder scores project health across six categories, scaffolds the Tier-1 components a project is missing — feedback loops, evals, sensors, and context-mgmt advisories — and auto-fixes the top-ranked issue through the same loop.

**Install** · `claude plugin install autoresearch@21-breakincode`

**Commands** · `/autoresearch:harness-build` · `/autoresearch:harness-check` · `/autoresearch:harness-improvement` · `/autoresearch:improve`

## Review & Design

### [code-reviewer](./code-reviewer/README.md) · `v1.0.0`

*Principle-aware PR review*

Layers a repo-specific review-mindset agent on top of pr-review-toolkit's 4+6 perspectives, citing your repo's own distilled principles, hotspots, and red-flags. Degrades gracefully to the standard review when no principle directory exists. Includes `refresh-principles`, which learns the repo's own principle files from merged git + PR history.

**Install** · `claude plugin install code-reviewer@21-breakincode`

**Commands** · `/code-reviewer:review-pr`

### [uiux-optimizer](./uiux-optimizer/README.md) · `v1.3.0`

*Reference-driven UI/UX design advisor*

Orchestrates live design references (refero.design + the getdesign.md catalogue), anti-slop taste discipline, and motion choreography across audit / build / explore modes and a gated ship pipeline. Degrades gracefully when the optional taste and motion skills aren't installed.

**Install** · `claude plugin install uiux-optimizer@21-breakincode`

**Skills** · `uiux-optimizer`

### [receipts](./receipts/README.md) · `v0.2.0`

*No claim without a receipt*

A Stop hook that enforces provable claims. When the finished turn asserts a **FACT:** or a completion ('verified', 'tests pass', 'fixed', 'done'), a free deterministic prefilter checks it against that turn's real tool calls; only genuinely ambiguous claims escalate to a fresh-context Haiku judge. Unbacked claims are flagged with a ⚠ note (default `warn` mode) — or hard-gate the turn in `block` mode, where Claude must prove each with a real tool call or downgrade it to **ASSUME:** — bounded to one challenge per claim per session (ledger + stop_hook_active backstop). Enforces the fact-assume discipline (FACT = provable if challenged) that RLHF's confident 'done' quietly erodes. On by default and fail-open; set CLAUDE_RECEIPTS=0 to disable. /receipts prints the session's audit ledger and sets the mode.

**Install** · `claude plugin install receipts@21-breakincode`

**Commands** · `/receipts:receipts`

### [woop](./woop/README.md) · `v0.1.0`

*Turn a conclusion into an obstacle-aware if-then plan*

A WOOP (Wish·Outcome·Obstacle·Plan) commit-lens for critical thinking — it caps work you've already done and turns a conclusion into an obstacle-aware, if-then plan before you act, never redoing the analysis. One engine, four temporal modes: prevent (pre-mortem before you build), decide (pressure-test a conclusion before you commit), firefight (triage a live incident under hard constraints), and retro (convert a post-mortem into if-then commitments that stick). Every run reframes the surface wish into the essence-wish, then dispatches an adversarial read-only obstacle-hunter subagent that red-teams the plan and returns ranked obstacles with actionability plus if-then trigger seeds; only obstacles you can attach a trigger to become commitments, the rest stay visible flagged 'no if-then'. Output is a terminal WOOP INSIGHT (FACT/ASSUME/INSIGHT/SUGGEST) you check, with an optional ask-per-run record saved to docs/woop/ so if-then plans accumulate into a decision journal. Experimental. Self-contained — no hooks, no cross-plugin deps.

**Install** · `claude plugin install woop@21-breakincode`

**Commands** · `/woop:woop`

## Workflow & Handover

### [hh](./handover-handler/README.md) · `v0.1.5`

*Cross-context handover docs, LifeOS as the source of truth*

Bridges your Obsidian LifeOS vault and each repo through a ./handover symlink, so handover documents survive context switches and stay visible to editors, grep, Obsidian, and Claude alike. Includes a daily vault-wide wrap-up state machine.

**Install** · `claude plugin install hh@21-breakincode`

**Commands** · `/hh:init-org` · `/hh:init-service` · `/hh:new` · `/hh:wrap-up`

### [adhd-review](./adhd-review/README.md) · `v0.3.0`

*Action-first replies, blockers before FYI*

One output style, three layers. Layer 1 shapes every reply — lead with the action, number multi-step work with time estimates, cut preamble/recap/closers, state errors matter-of-factly. Layer 2 governs the final turn of substantial multi-step work with Review-Ready buckets — ✅ Done / ⚠️ Broken / 🙋 What I need from you / 🤖 What I'll do, blockers before FYI, each ask naming why it's yours. A Visual Layer draws non-linear flow-shaped concepts — branches, loops, state changes, hierarchies — as fenced ASCII diagrams instead of prose, while linear steps stay numbered lists. Applies to the human-facing thread only: the output-style mechanism and a default-on SessionStart hook both target the main session, so subagent returns stay full-detail. On by default — installing the plugin shapes the main thread out of the box; set CLAUDE_ADHD_REVIEW=0 to silence a session. Toggle per session with /adhd-review-mode or /output-style adhd-review.

**Install** · `claude plugin install adhd-review@21-breakincode`

**Skills** · `adhd-review-mode`

## Media

### [remotion-maker](./remotion-maker/README.md) · `v0.2.0`

*Generate styled Remotion videos, end to end*

A full pipeline for Remotion (React) videos: define a consistent style, generate scenes from your content, source free media, review preview frames, and verify against the style before rendering to MP4.

**Install** · `claude plugin install remotion-maker@21-breakincode`

**Commands** · `/remotion-maker:create` · `/remotion-maker:define-style` · `/remotion-maker:find-media` · `/remotion-maker:verify`

## Writing & Content

### [humanize](./humanize/README.md) · `v0.1.0`

*Sound like a person, in zh-TW or English*

Two skills. distill captures your voice from writing samples into a reusable tone preset; rewrite strips AI-tells from existing text (PR comments, posts, emails) and matches a tone, preserving meaning and never inventing facts. Separate Traditional-Chinese and English rulesets, auto-detected, plus a flag-only audit mode.

**Install** · `claude plugin install humanize@21-breakincode`

**Skills** · `distill` · `rewrite`
