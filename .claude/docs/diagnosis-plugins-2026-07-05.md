# Harness Diagnosis — PersonalPlugins repo (2026-07-05)

Repo-specific edition of `~/.claude/playbooks/harness-diagnosis-2026-07-05.md`.
Measured live (Claude Code CLI 2.1.193, Fable-5 session). The 3 biggest
repo-specific sources of token waste / error, each with a fix a Sonnet-class
model (or William) can execute mechanically.

## Leak 1 — Doubled design-skill injection (biggest token waste)

FACTS (2026-07-05):
- 14 design skills (brandkit, design-taste-frontend, design-taste-frontend-v1,
  full-output-enforcement, gpt-taste, high-end-visual-design, image-to-code,
  imagegen-frontend-mobile, imagegen-frontend-web, industrial-brutalist-ui,
  minimalist-ui, motion-design, redesign-existing-projects, stitch-design-taste)
  are symlinked BOTH in `~/.claude/skills/` (created 2026-06-28 02:31) AND in
  this repo's `.claude/skills/` (created 2026-06-28 02:59, gitignored —
  .gitignore:11). The user-scope links resolve to `~/.agents/skills/<name>`;
  the repo links resolve to the repo-local `.agents/skills/<name>` (also
  gitignored — .gitignore:10). Two distinct copies of the same 14 skills.
- Claude Code merges user- and project-scope skills WITHOUT deduplication, so
  every session in this repo injects all 14 long descriptions twice.

FIX (William's call — removing 14 files trips judgment-rubrics R3.1):
```
rm /Users/williamhung/Projects/PersonalPlugins/.claude/skills/*
```
All 14 entries are symlinks; the skill content (repo-local `.agents/skills/`
and user-scope `~/.agents/skills/`) and the user-scope registration survive
untouched. Verify: a fresh session in this repo lists each design skill once.

## Leak 2 — Hand-editing generated docs (most likely error)

FACTS:
- Fully generated — overwritten by every `./scripts/cicd.sh GEN` run and by the
  pre-commit hook: `CATALOG.md`, `<plugin>/README.md`,
  `site/data/plugins.json` (scripts/generate-docs.mjs:67-73).
- HYBRID: `site/index.html` and `site/plugin.html` are hand-authored, but GEN
  re-stamps their `?v=` asset-cache versions and the plugin count in place
  (generate-docs.mjs:74-81). Hand edits to those stamped values silently revert.

FIX (mechanical, in force since 2026-07-05): `.claude/settings.json`
`permissions.deny` blocks Edit/Write on the three fully-generated targets
(verified live: a sentinel Edit on CATALOG.md was denied). To change their
content: edit `.claude-plugin/marketplace.json` or
`content/plugins.content.json`, then run `./scripts/cicd.sh GEN`.
Note: the deny gates Claude's Edit/Write tools only — GEN itself (node via
Bash) is unaffected; so is `sed` via Bash, so the rule is a guard, not a wall.

✅ change a tagline in content/plugins.content.json → `./scripts/cicd.sh GEN` → commit.
❌ "quick typo fix" directly in session-learner/README.md — denied, and GEN
   would revert it on the next commit anyway.

## Leak 3 — Silent version-lockstep misses (highest-consequence error)

FACTS:
- A plugin behavior change reaches installed users ONLY if its version is
  bumped in BOTH `.claude-plugin/marketplace.json` AND
  `<plugin>/.claude-plugin/plugin.json`, kept equal
  (.claude/rules/plugin-rules.md §4). An un-bumped change fails silently — no
  error anywhere, users just never get the update.

FIX (procedure — run on EVERY plugin behavior change):
1. Bump both version fields to the same value; prove equality:
   `grep -n "\"version\"" .claude-plugin/marketplace.json <plugin>/.claude-plugin/plugin.json`
2. Run `./scripts/cicd.sh VERIFY`; paste its actual output in your report
   (judgment-rubrics R2 — no "should work").
3. Walk the pre-commit checklist at the end of plugin-rules.md line by line.
NOT VERIFIED: whether VERIFY itself catches lockstep drift — treat the manual
grep as the guard until someone tests that; don't assume the tooling has your back.

## Worked delegation brief (prompt-templates.md template 2, filled for this repo)

```
GOAL: <THE CHANGE> in <plugin>/ (e.g. session-learner/).
WHY: <INTENT — 1 line>.
CONTEXT: read first: <plugin>/CLAUDE.md and the files you will touch.
  Conventions that bind you: .claude/rules/plugin-rules.md (CLAUDE_PLUGIN_ROOT
  sourcing; no cross-plugin references; no `find ~/.claude/plugins` anywhere).
CONSTRAINTS: touch ONLY <plugin>/** plus the two version fields below. NEVER
  edit CATALOG.md, */README.md, or site/data/plugins.json (generated;
  mechanically denied). Bump the version in .claude-plugin/marketplace.json
  AND <plugin>/.claude-plugin/plugin.json to the same new value.
ACCEPTANCE:
- ./scripts/cicd.sh VERIFY exits 0 — paste the output
- grep shows both version fields equal — paste the two lines
- no `find ~/.claude/plugins` introduced: grep -rn "find ~/.claude/plugins" <plugin>/ returns nothing
REPORT: files changed with line ranges; verification outputs; anything not
  done, with reason. Max 25 lines.
(+ the Definition of Done checklist from prompt-templates.md's header)
```

## Context-load facts for this repo (2026-07-05)

- Always-on load: 298 lines user rules + 71 lines plugin-rules.md + ~30 lines
  CLAUDE.md ≈ 399 of the 500-line cap (maintenance.md). Adding always-on lines
  here means deleting others.
- One-time review for William: `.claude/docs/plugin-sprawl-review-2026-07-05.md`
  (keep/disable/rescope table for the 22 enabled plugins).
- Global institutions: `~/.claude/rules/orchestration-core.md` (always-on) →
  playbooks in `~/.claude/playbooks/`.
