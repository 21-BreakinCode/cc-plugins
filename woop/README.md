# woop

> Turn a conclusion into an obstacle-aware if-then plan

A WOOP (Wish·Outcome·Obstacle·Plan) commit-lens for critical thinking — it caps work you've already done and turns a conclusion into an obstacle-aware, if-then plan before you act, never redoing the analysis. One engine, four temporal modes: prevent (pre-mortem before you build), decide (pressure-test a conclusion before you commit), firefight (triage a live incident under hard constraints), and retro (convert a post-mortem into if-then commitments that stick). Every run reframes the surface wish into the essence-wish, then dispatches an adversarial read-only obstacle-hunter subagent that red-teams the plan and returns ranked obstacles with actionability plus if-then trigger seeds; only obstacles you can attach a trigger to become commitments, the rest stay visible flagged 'no if-then'. Output is a terminal WOOP INSIGHT (FACT/ASSUME/INSIGHT/SUGGEST) you check, with an optional ask-per-run record saved to docs/woop/ so if-then plans accumulate into a decision journal. Experimental. Self-contained — no hooks, no cross-plugin deps.

## Install

```bash
claude plugin install woop@21-breakincode
```

## Commands

- **`/woop:woop`** — Pressure-test a decision with WOOP — pick a mode (prevent/decide/firefight/retro) or type one directly.

---

Part of the [21-breakincode](../README.md) marketplace. Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.
