# Mode: prevent — pre-mortem before you build

**Fires:** before committing to a risky change, design, or launch. The Titanic "before it
sails" stance — everyone is admiring the unsinkable ship.

**Essence-wish reframe:** surface "ship X / hit the deadline / break the record" → essence
"the real safety property X must hold *even when something fails*." Ask: what must stay true
in the worst case?

**Obstacle family (tell the hunter):** hidden *systemic* failure modes — not the obvious
iceberg. Institutional blind spots, missing guardrails, capacity computed against the wrong
baseline, escape hatches sealed shut by an unrelated decision. **Assume it has already
failed; explain how.**

**Mini-example:**
- Wish: "ship the new pricing engine Friday" → essence: "no customer is ever double-charged,
  even mid-deploy."
- Obstacle: "the rollback path is untested; a bad migration leaves writes half-applied."
- Plan: "If the migration touches the billing table, then gate it behind a dry-run +
  reversible shadow write before cutover."
