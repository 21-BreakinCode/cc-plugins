# Principle file format

Each of `01-overview` … `07-red-flags` is a Markdown file of **entries**. Every
entry MUST carry an `Evidence:` line citing at least one source — no citation,
no entry (precision-first).

## Entry template

### <short imperative title>
- **What:** one-line description of the pattern/pitfall/hotspot.
- **Evidence:** PR #<n> (<url>) · commit <sha> · comment <url> — <YYYY-MM-DD>
- **Why it matters:** one line (impact / what breaks).

## File roles

| File | Holds |
|---|---|
| 07-red-flags | patterns that caused reverts/hotfixes or blocked-then-fixed reviews |
| 02-pitfalls | bug clusters recurring across ≥N PRs |
| 05-hotspots | high-churn files (cite commit counts) |
| 04-domain-traps | domain gotchas raised in review that caused a change |
| 03-review-patterns | what reviewers repeatedly ask for |
| 06-conventions | recurring style/convention asks that caused a change |
| 01-overview | auto-generated manifest: repo, window, counts, watermark |

## Mechanical rule (test-checked)
Every `###` entry outside `01-overview` has a line beginning `- **Evidence:**`
with at least one of `PR #`, a 7+ hex SHA, or an `http` URL.
