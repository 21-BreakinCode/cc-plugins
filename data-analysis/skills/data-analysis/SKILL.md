---
name: data-analysis
description: "Analyze CSV, Parquet, and JSON datasets using DuckDB with Six Thinking Hats methodology and optional business-context playbooks."
---

# Data Analysis

Analyze datasets using DuckDB as the compute engine and Six Thinking Hats as the analysis framework. Every observation uses `<FACT>` and `<ASSUME>` tags to separate what the data shows from what it might mean.

## Prerequisites

- Python 3 with `duckdb` package
- If DuckDB is not installed, offer to install it (`pip install duckdb`) before proceeding

## Workflow

```
Wizard → Blue Hat (plan) → White Hat (profile) → Red Hat (impression)
       → Black Hat (quality) → Yellow Hat (findings) → Green Hat (creativity)
       → Summary
```

Each hat phase **pauses for user review** before proceeding to the next. This is not optional — the user is a co-pilot who may correct your assumptions at any step.

---

## Phase 0: Wizard Setup

Start an interactive setup. Ask **one question at a time**:

1. **Data file**: "What data file would you like to analyze? (CSV, Parquet, or JSON path)"
2. **Playbook**: Scan the plugin's `playbooks/` directory for available `.md` files. Present them: "Would you like to apply a business context playbook? Available: [list]. Or 'none' for generic analysis." If the user has their own playbook file elsewhere, accept that path too.
3. **Questions**: "What questions do you have about this data? Or type 'explore' for general profiling."
4. **Decision context**: "What business decision depends on this analysis? What do you suspect is the root cause of the pattern you're investigating?" (Skip if user said 'explore'.)
5. **Target metrics**: "Do you have target metrics or benchmarks in mind? (e.g., CPA < $40, ROAS > 3.0). If not, I'll help you define them from the data or playbook."

After collecting inputs, load the data into DuckDB:

```python
import duckdb
con = duckdb.connect()
con.execute("CREATE TABLE data AS SELECT * FROM 'path/to/file'")
row_count = con.execute("SELECT COUNT(*) FROM data").fetchone()[0]
columns = con.execute("DESCRIBE data").fetchall()
```

Confirm with the user: "Loaded [N] rows, [M] columns. Ready to begin analysis."

If loading fails (bad path, corrupt file, encoding issues), show the error clearly and help the user fix it before retrying.

The playbook is loaded once in Phase 0 and referenced by name in all subsequent phases — never re-loaded.

---

## Phase 1: Blue Hat — Analysis Plan

**Purpose**: Define what we will examine and why.
**Input:** User questions, data schema from Wizard, loaded playbook (if any).
**Output:** Ordered analysis plan with techniques, causal hypotheses, success criteria. Referenced by all subsequent phases.
**Constraint:** Plan only — no queries executed. User must confirm before proceeding.

Read the user's questions, the data schema, and the playbook context (if any). Based on data shape (column types, row count, cardinality), propose which analysis techniques to apply.

**Available techniques**:

| Technique | When to use |
|-----------|------------|
| Distribution analysis | Categorical or numeric columns — value counts, histograms, percentiles |
| Trend analysis | Date/time column present — patterns over time, seasonality |
| Correlation analysis | Multiple numeric columns — relationships, strength |
| Anomaly detection | Any column — outliers, unexpected nulls, distribution breaks |
| Group comparison | Category column present — segment-by-segment differences |
| Funnel analysis | Data represents sequential stages — drop-off or growth patterns |

**Output**:

```
## Blue Hat: Analysis Plan

<FACT>
- Dataset: [filename], [N] rows x [M] columns
- Column types: [list by type — numeric, categorical, datetime, text]
- User questions: [what they asked]
- Playbook applied: [name or 'none']
</FACT>

<ASSUME>
Based on the data shape and your questions, I recommend:
1. [Technique] — [why this fits]
2. [Technique] — [why this fits]
3. [Technique] — [why this fits]
</ASSUME>

**Causal hypothesis** (always include — if the user didn't state a hypothesis, propose one based on the data shape and playbook context):
```
Based on your stated hypothesis and playbook context, I propose testing:
- H1: [cause A — what data pattern would confirm it]
- H2: [cause B — what data pattern would confirm it]
Analysis will attempt to distinguish which hypothesis the data supports.
```

Correlation does not imply causation — each technique above tests a specific mechanism. Group comparison tests whether a relationship holds across segments. Trend analysis tests temporal causation.

**Narrative frame:** State the core question this analysis will answer in one sentence. Example: "We are investigating whether the CPA increase is supply-side (CPC pressure) or demand-side (conversion decline)." All phases will reference this frame.

**Simplicity principle:** I start with SQL aggregation and basic statistics (counts, averages, percentiles, IQR). I only escalate to advanced methods (regression, clustering, time-series decomposition) if the simple approach demonstrably fails to answer your question.

**Escalation gates** (start simple, escalate only if needed):
- Anomaly detection: IQR first. Z-score only if IQR flags don't match domain expectations.
- Correlation: Pairwise Pearson for <10 numeric columns. For more, select top columns by domain relevance.
- Trend: `date_trunc` + GROUP BY first. Seasonal decomposition only if periodicity obscures the trend.
- Group comparison: Descriptive stats (N, mean, median, STDDEV) first. Statistical tests only if the question is "is this difference real?" not "how large is it?"

**Success criteria:** Extract targets from the playbook Key Metrics, user input from Phase 0, or propose data-derived baselines (e.g., use last month's values as targets). Confirm with the user: "Your target for [metric] is [threshold]. Is this still your target?" These become the evaluation baseline for Yellow Hat.

Does this plan look right? Add, remove, or reorder anything?
```

**Wait for user confirmation.**

---

## Phase 2: White Hat — Data Profiling

**Purpose**: Neutral facts only. Zero interpretation.
**Input:** DuckDB table loaded in Wizard, playbook expected columns/ranges (if any).
**Output:** Column statistics table (FACT only). Stored as `profile_summary` for reuse by all subsequent phases.
**Constraint:** Zero interpretation — facts only. No ASSUME content except "None — just the facts."

All subsequent phases MUST reference `profile_summary` for column-level statistics rather than re-scanning data.

Run profiling via DuckDB:

```python
# Full summary
con.execute("SUMMARIZE data").fetchdf()

# For large datasets (>1M rows), sample first
con.execute("CREATE TABLE data_sample AS SELECT * FROM data USING SAMPLE 10 PERCENT")
```

**Sampling strategy**:
- Under 100K rows: profile full dataset
- 100K–1M rows: full for profiling, sample for expensive operations
- Over 1M rows: sample 10% for initial profile, note this in output

**Output**:

```
## White Hat: Data Profile

<FACT>
**Shape**: [N] rows x [M] columns

| Column | Type | Non-null | Distinct | Min | Max | Mean |
|--------|------|----------|----------|-----|-----|------|
| ...    | ...  | ...      | ...      | ... | ... | ...  |

**Notable**:
- [Column X]: [N]% null values
- [Column Y]: [N] distinct values out of [M] rows
- Date range: [min] to [max]
- [If sampled]: "Profiled on 10% sample ([N] rows)"
</FACT>

<ASSUME>
None — just the facts.
</ASSUME>

Anything surprising here? Should I dig deeper into any column?
```

**Efficiency notes**:
- After profiling, store the summary as a reusable reference: `CREATE TABLE profile_summary AS SELECT * FROM (SUMMARIZE data)`. Reference this in subsequent phases rather than re-scanning the full table.
- Batch related queries into single DuckDB calls where possible. Use CTEs for intermediate results referenced multiple times.

**Wait for user review.**

---

## Phase 3: Red Hat — Initial Impression

**Purpose**: Quick gut reaction. Deliberately brief and subjective — like a 30-second first impression.
**Input:** `profile_summary` from White Hat, user's questions from Wizard.
**Output:** Working hypothesis (a testable prediction) and gut-feel assessment. Referenced in Yellow Hat for confirmation/refutation.
**Constraint:** Brief and subjective — no new queries. Interpretation only, based on White Hat facts.

```
## Red Hat: Initial Impression

<FACT>
[Reference 2-3 specific numbers from the profile that triggered the impression]
</FACT>

<ASSUME>
My quick read:
- [Data quality gut feel — does this look clean or messy?]
- [Any obvious patterns jumping out from the summary stats?]
- [Can this data actually answer the user's questions?]
- **My working hypothesis**: [One specific prediction about the root cause that we will test in Yellow Hat]
</ASSUME>

Does this match your intuition? If not, tell me what I'm reading wrong — this is where your domain knowledge matters most.
```

**Wait for user reaction.** This phase calibrates interpretation. If the user corrects you here — e.g., a pattern you flagged as anomalous is actually normal in their domain — that correction should inform all subsequent phases.

---

## Phase 4: Black Hat — Data Quality & Caveats

**Purpose**: Critical evaluation. What's wrong, missing, or risky?
**Input:** DuckDB table, `profile_summary`, Blue Hat plan (to assess technique feasibility), playbook expected patterns (if any).
**Output:** Quality issue inventory with risk impact per issue. Stored as caveats referenced in Yellow Hat and Summary.
**Constraint:** Diagnostic only — no cleaning unless user approves. Every issue must state downstream impact.

Run quality checks:

```python
# Null rates per column
con.execute("""
    SELECT column_name, null_percentage
    FROM (SUMMARIZE data)
    WHERE null_percentage > 0
    ORDER BY null_percentage DESC
""")

# Duplicate rows
con.execute("""
    SELECT COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM data)) as dupes
    FROM data
""")

# Outliers (IQR method — run per numeric column)
for col_name in numeric_columns:
    con.execute(f"""
        SELECT percentile_cont(0.25) WITHIN GROUP (ORDER BY "{col_name}") as q1,
               percentile_cont(0.75) WITHIN GROUP (ORDER BY "{col_name}") as q3
        FROM data
    """)
```

**Date gap check** (run if a date column is present):
```sql
-- Identify missing days in the date range
SELECT gs.day::DATE AS missing_day
FROM generate_series(
    (SELECT MIN(date_col) FROM data),
    (SELECT MAX(date_col) FROM data),
    INTERVAL '1 day'
) AS gs(day)
WHERE gs.day::DATE NOT IN (SELECT DISTINCT date_col FROM data)
```

**If a playbook is loaded**, check data against expected patterns:
- Does the shape match what the playbook says is normal?
- Are expected columns present?
- Do value ranges match business expectations?
- Are there patterns the playbook says are normal that you would otherwise flag?

**Output**:

```
## Black Hat: Data Quality & Caveats

<FACT>
**Nulls**:
| Column | Null count | Null % |
|--------|-----------|--------|
| ...    | ...       | ...    |

**Duplicates**: [N] duplicate rows
**Outliers**: [Column X] has [N] values beyond 1.5x IQR
[If playbook]: **Playbook check**: [which expected patterns match/don't match]
**Risk impact**: For each issue above, state which downstream analyses are affected. Example: "8% NULL in ad_format — creative-level segmentation covers only 92% of spend; flag in Yellow Hat."
**Blue Hat techniques affected**: [List which planned techniques from the Blue Hat plan are limited by these quality issues]
</FACT>

<ASSUME>
- [Are nulls random or systematic?]
- [Are duplicates expected (denormalized) or problematic?]
- [Are outliers real extremes or data errors?]
- [Playbook-specific interpretation of any issues]
</ASSUME>

<SUGGEST>
- [How to handle each issue, if needed]
- For each quality issue, explicitly state which downstream analyses are affected. Example: "15% NULL in ad_format means creative-level analysis covers only 85% of spend."
</SUGGEST>

How would you like to handle these? Proceed as-is, or apply cleaning?
```

**Re-check after filtering**: If the user applies filtering or cleaning, re-run the null/duplicate/outlier checks on the filtered dataset and confirm the filtered data is representative (similar distribution shape, no systematic bias) before proceeding to Yellow Hat.

**Sample size note**: For any GROUP BY analysis in later phases, compute N per group and standard deviation per numeric metric. Flag groups with N < 30 as "suggestive only — insufficient sample" in all subsequent references. Note sample size disparities across groups. Bundle null, duplicate, and outlier checks into a single query where possible to reduce redundant table scans.

**Wait for user decision.**

---

## Phase 5: Yellow Hat — Key Findings

**Purpose**: What does the data reveal? What opportunities exist?
**Input:** Blue Hat plan (techniques + hypotheses + success criteria), `profile_summary`, Black Hat caveats, Red Hat hypothesis.
**Output:** Findings per technique with Metric vs. Target table, mandatory SUGGESTs for threshold violations, Follow-Up Queue.
**Constraint:** Every GROUP BY must include LIMIT. Every threshold violation must produce a SUGGEST. Reference `profile_summary` for aggregates.

Execute the techniques selected in the Blue Hat plan. This is the main analytical phase — run DuckDB queries for each technique and present results.

**Efficiency rules** (mandatory for all Yellow Hat queries):
1. Reference `profile_summary` for aggregate stats — do not re-scan the full table.
2. Every GROUP BY query MUST include LIMIT (20 for distributions, 50 max for comparisons).
3. Batch related queries using CTEs when possible.
4. For datasets >100K rows, sample for expensive operations.

For each technique, run the relevant queries using standard approaches:

- **Distribution**: `SELECT col, COUNT(*) FROM data GROUP BY col ORDER BY COUNT(*) DESC LIMIT 20`
- **Trend**: `SELECT date_trunc('month', date_col), COUNT(*) AS n, AVG(metric), STDDEV(metric) FROM data GROUP BY 1 ORDER BY 1`
- **Correlation**: compute pairwise correlations between numeric columns
- **Anomaly**: Z-score or IQR-based detection
- **Group comparison**: `SELECT category, COUNT(*) AS n, AVG(metric), STDDEV(metric), MEDIAN(metric) FROM data GROUP BY category LIMIT 20` — always include N and STDDEV per group
- **Funnel**: `SELECT stage, COUNT(*) AS n FROM data GROUP BY stage ORDER BY stage_order LIMIT 20`

Use CTEs to batch related queries: `WITH dist AS (...), trend AS (...) SELECT * FROM dist; SELECT * FROM trend;` — avoids redundant full-table scans. Reference the `profile_summary` table from White Hat rather than re-scanning the full table.

**Keep result sets under 50 rows** in conversation. Summarize larger results. For tables exceeding this, show top/bottom N and aggregate the middle.

**Warning: Never report a global average without checking segments.** An aggregate metric can mask opposing segment trends (Simpson's paradox). Always verify segment consistency before drawing conclusions from aggregates.

**Multi-dimensional segmentation**: Default to at least 2 relevant dimensions before reporting any aggregate metric (e.g., campaign_type × device, audience_segment × placement). A single-dimension GROUP BY is a starting point, not a conclusion.

**Simpson's paradox check**: Compare per-segment trends against the blended aggregate. Flag if a segment-level trend contradicts the aggregate. Identify which segment(s) drive the aggregate change. Worked example: Overall CPA rose 20%. By campaign_type: Brand_Search -5%, Generic_Search +10%, Competitor_Search +45%. Conclusion: Competitor_Search drives the aggregate increase — this is a segment-specific problem, not a platform-wide issue.

**Derived metrics** (if a playbook is loaded): Compute playbook-recommended derived metrics alongside standard ones (e.g., LTV-adjusted ROAS = ROAS × repeat_rate, confidence-adjusted conversions for low-confidence segments).

**Metric vs. Target**: Compare each key metric against the success criteria established in Blue Hat (from playbook, user input, or data-derived baselines). Format: `[metric] = [actual] (target: [threshold], [variance %])`.

**Follow-Up Queue**: For each key finding, generate 1-3 follow-up questions prioritized by potential to change recommendations. Example: if CPA is rising, ask "Is this driven by CPC (auction pressure) or conversion rate (creative fatigue)?" Collect these questions — they will appear in the Summary's Open Questions. If a playbook is loaded, cross-check that all playbook Steps have been addressed. Add any unaddressed Steps to the Follow-Up Queue.

**Output**:

```
## Yellow Hat: Key Findings

<FACT>
**[Technique 1 name]**:
[Query results as markdown tables or bullet points. All GROUP BY result tables MUST include an `N` column showing the count per group and STDDEV for numeric metrics.]

**[Technique 2 name]**:
[Results]

**[Technique 3 name]**:
[Results]

**Metric vs. Target**:
| Metric | Actual | Target | Variance |
|--------|--------|--------|----------|
| ...    | ...    | ...    | ...      |
</FACT>

<ASSUME>
Key insights — use hedging language proportional to evidence: "likely" (N>100), "suggests" (30<N<100), "insufficient data to conclude" (N<30):
1. [What finding #1 might mean for the business — note if it aligns with or contradicts the Red Hat impression]
2. [What finding #2 suggests — reference any Black Hat caveats that affect this finding]
3. [Pattern or opportunity spotted]
[If playbook loaded: interpret through business context — use the playbook's definitions and thresholds]

**Confidence indicator**: For key findings comparing two groups, if the difference between them exceeds 2x the within-group standard deviation AND both groups have N>30, mark as "high confidence." Otherwise, mark as "directional only."

For each insight, state what the data CANNOT prove. Example: "The data shows CPA correlates with CTR decline, but cannot prove CTR caused CPA to rise — a shared external factor (seasonality, competitor activity) could explain both."
</ASSUME>

**Novelty checkpoint** (mandatory before concluding Yellow Hat):
1. Check if any "underperforming" segment is undervalued due to signal quality or attribution gaps.
2. Cross at least one unexpected dimension pair not in the original Blue Hat plan.
3. If a playbook is loaded, compare actual patterns against Expected Patterns — flag any violations as potential surprises.

<SUGGEST>
**Mandatory:** For EVERY metric that violates a success criteria threshold, generate a SUGGEST. No threshold violation may go without a recommended action. Each SUGGEST must include:
- Action type (bid change, budget shift, pause, test)
- Specific entity from the data
- Magnitude if quantifiable
- Expected outcome
- Effort estimate (low/medium/high)

Example SUGGEST: "Reduce Competitor_Search bid by 15% — CPC is $3.40 (35% above $2.50 playbook target). Expected: CPA reduction of ~$8-12 assuming CVR holds. Effort: low. Priority: high ($18k/month spend with above-target CPA)."
</SUGGEST>

## Follow-Up Queue

(Mandatory — display before asking user to drill deeper):

1. [P1] [Finding X]: [Specific follow-up question] — [what data/analysis would resolve it]
2. [P2] [Finding Y]: [Question] — [resolution path]
3. [P3] [Finding Z]: [Question] — [resolution path]

If a playbook is loaded, cross-check: have all playbook Steps been addressed? List any unaddressed Steps here.

Which findings matter most to you? Want to drill deeper into any of these?
```

**Wait for user feedback.** They may want to zoom into specific findings — if so, run additional queries and present in the same FACT/ASSUME format.

---

## Phase 6: Green Hat — Alternative Perspectives

**Purpose**: Creative angles. What haven't we tried? What might we be missing?
**Input:** All prior phase outputs — especially Yellow Hat findings to challenge and Black Hat caveats to probe.
**Output:** Contrarian tests, unexplored dimensions, alternative hypotheses. User decides which to pursue.
**Constraint:** Must reference specific Yellow Hat conclusions. At least two contrarian tests must be run (not just proposed).

```
## Green Hat: Alternative Perspectives

<FACT>
[What we've analyzed so far and what remains unexplored]
</FACT>

<ASSUME>
Before presenting Green Hat output, ask yourself: "What assumption about this data might be wrong? What would surprise the user?" State the answer explicitly.

**Mandatory contrarian tests** (run at least two before concluding):
1. Check if underperforming segments are undervalued due to signal quality (low N, missing data).
2. Compare segments that "shouldn't" differ — if they do, there may be a data or attribution issue.
3. Compute a derived metric not in the raw data that might reveal a hidden pattern.

**Mandatory discovery checks** — referencing specific Yellow Hat conclusions:
1. Based on Yellow Hat finding [X], we haven't explored [dimension]. Alternative: [specific analysis — e.g., "Yellow Hat found CPA increase is CPC-driven; what if it's actually a mix shift?"]
2. [A hypothesis that contradicts our Yellow Hat findings — state what evidence would confirm it]
3. [An unexpected derived metric worth computing]
4. [Cross-referencing suggestion — "what if we joined with X?"]
</ASSUME>

Want me to pursue any of these? Or are you satisfied with the analysis?
```

**Wait for user decision.** If they want more, loop back with additional DuckDB queries in FACT/ASSUME format. If satisfied, proceed to summary.

---

## Summary

After all phases complete (or user says they're satisfied):

```
## Analysis Complete

**Story** (follow these steps in order):
1. **Frame**: Restate the Blue Hat question in one sentence.
2. **Journey**: Trace how each phase contributed — White Hat revealed [X], Red Hat predicted [Y], Black Hat flagged [Z], Yellow Hat found [W].
3. **Twist**: Did the Red Hat hypothesis hold or was it overturned? Cite the specific Yellow Hat finding.
4. **Resolution**: How completely does the evidence answer the Blue Hat question? What Black Hat caveats limit confidence?

**Key facts discovered:**
- [Top 3-5 FACT highlights across all phases]

**Main interpretations:**
- [Top 3-5 ASSUME highlights]

[If Phase 0 hypothesis stated] **Hypothesis verdict:**
- H1 [cause A]: [supported / contradicted / inconclusive — cite the specific finding]
- H2 [cause B]: [supported / contradicted / inconclusive]

**Evaluation Against Criteria:**
| Metric | Actual | Target | Status |
|--------|--------|--------|--------|
| ...    | ...    | ...    | Met / Missed / N/A |

**Recommended Actions** (prioritized by spend x gap_from_target):
1. [Action] on [specific entity] — [expected outcome] — [effort: low/medium/high]
2. ...
Include effort estimate for each. Higher priority = larger spend AND larger gap from target.

**Open questions** (from Yellow Hat Follow-Up Queue):
- [Question]: [what additional data would resolve it]

**Data quality notes:**
- [Key caveats to keep in mind when acting on these findings]
```

---

## Important Rules

1. **Never modify source data** — all DuckDB operations are read-only
2. **Show your queries** — the user should see what SQL is being run (use code blocks)
3. **FACT before ASSUME** — always lead with observable evidence
4. **Pause between phases** — wait for user review at each hat transition, no exceptions
5. **Respect playbook context** — if a playbook says a pattern is normal, do not flag it as anomalous
6. **Sample large data** — never dump full large tables into conversation context
7. **One question at a time** — during wizard and phase reviews
8. **Correct course when told** — if the user says your assumption is wrong, update your mental model for all subsequent phases
