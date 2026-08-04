# Mode: decide — pressure-test a call before you commit

**Fires:** after an analysis, before acting on its conclusion. Sits *downstream* of
exploration — it does not redo the analysis, it pre-mortems the **conclusion**. (This is the
mode with no equivalent in a Six-Hats / explore workflow.)

**Essence-wish reframe:** surface "act on what the data says" → essence "is my read of the
data even *trustworthy*?" The true wish is a decision you will not have to walk back.

**Obstacle family (tell the hunter):** confounders that would make the conclusion wrong —
selection bias, attribution leakage, Simpson's paradox, a metric that moved for a reason
unrelated to the hypothesis, a sample too small or too short to trust. **What would have to
be true for this call to be a mistake?**

**Mini-example:**
- Wish: "cut spend on the low-CTR segment" → essence: "stop wasting spend without killing a
  segment that actually converts downstream."
- Obstacle: "CTR is measured pre-attribution; this segment converts late via view-through we
  are not counting."
- Plan: "If a segment is flagged low-CTR, then check its 7-day view-through CVR before any
  budget cut."
