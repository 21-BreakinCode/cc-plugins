# Changelog

## 0.6.0 - 2026-09-24

- **refactor:** ship the reply rules through the SessionStart hook only. The plugin no longer ships an output style, so you never set `outputStyle` for it. The rules moved from `output-styles/adhd-review.md` to `scripts/session-rules.md`. If your settings set `outputStyle` to `adhd-review:ADHD Review`, delete that line.
- **refactor:** remove the `outputStyle` check and the frontmatter strip from `scripts/session-start.sh`. With one delivery path, the rules cannot load twice.

## 0.5.6 - 2026-09-24

- **fix:** skip the SessionStart injection when `outputStyle` already selects ADHD Review. Claude Code loads that body natively, so the hook added a second copy (about 1,374 tokens) at every start, resume, clear, and compact.
- **fix:** set `keep-coding-instructions: true` on the output style. Without it, Claude Code removes its built-in software engineering instructions while the style is active.

## 0.5.5 - 2026-09-19

- **fix:** rewrite `skills/adhd-review-mode/SKILL.md` to clear the simple-english linter. No content or meaning changed, only sentence shape.

## 0.5.4 - 2026-09-19

- **fix:** rewrite the remaining prose (Scope guard, Layer 1, Visual Layer, Layer 2) to clear the simple-english linter. No content or meaning changed, only sentence shape.
- **feat:** add a hard rule to the Visual Layer. Diagrams in a reply are always ASCII. Never use mermaid, since a plain chat reply cannot render it as a picture.

## 0.5.3 - 2026-09-19

- **fix:** remove the Language Layer (the embedded ASD-STE100 Simple English rules). This plugin now covers reply shaping only. Install the simple-english plugin for language rules. That plugin already covers this job.

## 0.5.2 - 2026-09-13

- **fix:** strengthen diff instruction with anti-pattern catalog, positive example, and defense-in-depth reinforcement

## 0.5.1 - 2026-09-13

- **fix:** code-diff format picker rule now demands verbatim code lines, not intent summaries

## 0.5.0 - 2026-08-28

- **feat:** add Language Layer that enforces ASD-STE100 Simplified Technical English as mandatory on every reply (all 53 rules + 8 general recommendations)

## 0.4.0 - 2026-08-15

- **feat:** expand Visual Layer with technique vocabulary (pseudocode, call trees, component/file trees, mermaid, diffs, HTML artifacts)
- **feat:** add format picker for content-type to view mapping (sequence diagrams, diff view, flow diagrams, done/action view)

## 0.3.0 - 2026-07-29

- **feat:** add Visual Layer with fenced ASCII diagrams for flow-shaped concepts

## 0.2.0 - 2026-07-29

- **refactor:** default-on with per-session opt-out

## 0.1.0 - 2026-07-27

- **feat:** initial release of ADHD-friendly per-reply shaping + Review-Ready handoff summaries
