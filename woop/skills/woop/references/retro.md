# Mode: retro — turn a post-mortem into if-then commitments

**Fires:** after the event. A backward-looking retro *feeds* a forward-looking WOOP — it
converts "lessons learned" into commitments that actually change behavior.

**Essence-wish reframe:** surface "write down what went wrong" → essence "what recurring
pattern must we *stop*, and how do we make the fix automatic?" A lesson with no trigger is a
lesson you will relearn.

**Obstacle family (tell the hunter):** why the lesson will not stick — the fix depends on
someone remembering, the action item has no owner or trigger, the incentive that caused it is
still in place, the guardrail is advisory instead of enforced. **What makes this recur
despite everyone "knowing better"?**

**Mini-example:**
- Wish: "document the outage" → essence: "make this class of outage impossible to repeat
  without a signal firing."
- Obstacle: "the fix is 'be more careful with migrations' — no trigger, so it decays in a
  week."
- Plan: "If a PR touches a migration file, then a CI check requires a linked rollback plan
  before merge."
