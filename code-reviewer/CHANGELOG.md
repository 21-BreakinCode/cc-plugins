# Changelog

## 2.0.0 — 2026-09-27

- **feat!:** five owned reviewer agents (correctness, test, security, ops, simplicity) replace the pr-review-toolkit agents and the orchestrator's inline perspectives. The pr-review-toolkit dependency is removed.
- **feat!:** the repo policy is found only through `CODE_REVIEWER_POLICY_DIR`. The env vars `CODE_REVIEWER_PRINCIPLE_DIR`, `CODE_REVIEWER_CONFIG_FILE`, and `CODE_REVIEWER_CACHE_FILE` are removed. The plugin no longer reads the files in `~/.claude/code-reviewer/`.
- **feat!:** the skill `refresh-principles` is renamed to `refresh-policy`. It keeps only repo-specific concepts.
- **feat:** the orchestrator passes the diff by file path, and reviewers read code at the PR head SHA.
- **feat:** policy severity is set by rule. The report adds Scrutiny, agent counts, and policy coverage lines.
- **refactor:** "principle" is renamed to "policy" in libs, agents, skill, and tests.
- **chore:** remove the one-time `migrate-to-okf.py` script and its test.

## 1.1.1 - 2026-09-19

- **fix:** rewrite prose across plugin files to clear the simple-english linter. No content or meaning changed, only sentence shape.

## 1.1.0 - 2026-08-09

- **feat:** QA fixture representativeness check. Flags synthetic test inputs asserting on diversity-sensitive behavior.
- **feat:** QA verdict → blast radius gate. Flags structural decisions lacking production-shaped test evidence.
- **feat:** mine-git-signals revert chain detection (misdiagnosis signal)
- **feat:** refresh-principles misdiagnosis sequence mining (Pitfall capture)

## 1.0.0 — 2026-08-07

- **feat:** migrate to OKF v0.2 concept format
- **feat:** reader walks OKF concept bundle, skips deprecated, flags stale
- **feat:** principle-reviewer cites OKF concept paths + trust/stale weighting
- **feat:** deterministic old→OKF bundle migration transform
- **docs:** refresh-principles writes OKF concepts, stamps verified on approval
- **fix:** seed OKF skeleton on bootstrap. Emit concept path in reader header.
- **fix:** compute caused_change from comment outdated-ness
- **fix:** exclude generated/vendored files from churn hotspots
- **fix:** quote YAML-hostile concept titles, capture wrapped What/Why lines
- **test:** OKF concept conformance check replaces evidence-line check

## 0.3.0 — 2026-08-07

- **feat:** add learn-state watermark lib + test harness
- **feat:** add git-signal miner (reverts/hotfixes/churn)
- **feat:** add PR-signal miner with comment→change correlation
- **feat:** add diff-coverage guard (coverage + finding validation)
- **feat:** add refresh-principles producer skill + format reference
- **feat:** wire deterministic coverage guards into orchestrator
- **fix:** handle omitted counts in learn-state write

## 0.2.0 — 2026-06-03

- **feat:** configurable principle-directory roots

## 0.1.0 — 2026-06-01

- **feat:** initial release. Principle-aware PR review plugin.
