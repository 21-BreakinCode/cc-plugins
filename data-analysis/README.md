# Data Analysis Plugin

Structured data analysis for Claude Code using DuckDB and the Six Thinking Hats framework.

## Quick Start

1. Install DuckDB: `brew install duckdb`
2. Install the plugin in Claude Code: `/install-plugin /path/to/data-analysis`
3. Run: `/data-analysis` — the guided wizard will walk you through setup

## What It Does

This plugin analyzes CSV, Parquet, and JSON datasets through a structured six-phase
process. Each phase separates observable facts (`<FACT>`) from interpretations (`<ASSUME>`),
so you always know what the data actually shows vs. what it might mean.

### The Six Phases

| Phase | Hat                | Purpose                                             |
| ----- | ------------------ | --------------------------------------------------- |
| 1     | Blue (Plan)        | Propose which analysis techniques to apply          |
| 2     | White (Profile)    | Raw data facts — column stats, distributions, nulls |
| 3     | Red (Impression)   | Quick gut reaction — does anything look off?        |
| 4     | Black (Quality)    | Data quality issues, caveats, limitations           |
| 5     | Yellow (Findings)  | Key insights and business-relevant patterns         |
| 6     | Green (Creativity) | Alternative perspectives and unexplored angles      |

You review and approve each phase before the next one begins.

## Adding Your Business Logic (Playbooks)

Playbooks teach the plugin your domain vocabulary so it interprets findings correctly.
Without a playbook, the plugin uses generic analysis. With one, it understands what
"normal" looks like in your specific business.

### Why Playbooks Matter

Consider this: a data funnel where Stage A has fewer records than Stage B might look
like an anomaly. But if your business excludes certain data sources from Stage A, then
A < B is perfectly normal. A playbook tells the plugin this, preventing false alarms.

### Creating a Playbook

1. Copy the template:

   ```bash
   cp playbooks/_template.md playbooks/my-company.md
   ```

2. Edit `playbooks/my-company.md` and fill in the four sections. The template includes
   annotated examples for each:
   - **Context** (required) — What your data means, column definitions, business rules
   - **Expected Patterns** (required) — What should NOT be flagged as anomalies
   - **Key Metrics** (optional) — What to measure and what good/bad looks like
   - **Steps** (optional) — Override the default analysis plan

3. When you run `/data-analysis`, the wizard will offer your playbook as an option.

### Playbook Tips

- **Be specific about "normal"** — The Expected Patterns section is the most valuable
  part. Think about what a new analyst would wrongly flag as a problem.
- **Define your vocabulary** — Column names rarely tell the full story. Explain what
  values mean, what units are used, and any encoding conventions.
- **Include thresholds** — "Healthy churn is <5%" is more useful than "churn matters."
- **Keep it honest** — If you're not sure about a threshold, say so. The plugin
  uses playbook context as guidance, not gospel.

### Example Playbooks

See `playbooks/example-ecommerce.md` for a complete example covering an e-commerce
order dataset.

## Requirements

- Python 3.8+
- `duckdb` Python package (`pip install duckdb`)
- Claude Code with plugin support

## How It Works Under the Hood

1. Data is loaded into an in-memory DuckDB database (your files are never modified)
2. DuckDB runs all computations — profiling, aggregations, statistical analysis
3. Only summarized results enter the conversation (raw data stays in DuckDB)
4. For large datasets (>1M rows), the plugin automatically samples for initial
   profiling and uses targeted full scans for specific queries

## File Structure

```
data-analysis/
├── skills/data-analysis/SKILL.md  — Core analysis skill
├── playbooks/                     — Business context files
│   ├── _template.md               — Copy this to create your own
│   └── example-ecommerce.md       — Working example
└── .claude-plugin/plugin.json     — Plugin metadata
```
