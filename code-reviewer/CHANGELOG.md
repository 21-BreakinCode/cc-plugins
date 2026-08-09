# Changelog

## 1.1.0 — 2026-08-09

- **feat:** QA fixture representativeness check — flags synthetic test inputs asserting on diversity-sensitive behavior
- **feat:** QA verdict → blast radius gate — flags structural decisions lacking production-shaped test evidence
- **feat:** mine-git-signals revert chain detection (misdiagnosis signal)
- **feat:** refresh-principles misdiagnosis sequence mining (Pitfall capture)

## 1.0.0 — 2026-08-07

- **feat:** migrate to OKF v0.2 concept format
- **feat:** reader walks OKF concept bundle, skips deprecated, flags stale
- **feat:** principle-reviewer cites OKF concept paths + trust/stale weighting
- **feat:** deterministic old→OKF bundle migration transform
- **docs:** refresh-principles writes OKF concepts, stamps verified on approval
- **fix:** seed OKF skeleton on bootstrap; emit concept path in reader header
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

- **feat:** initial release — principle-aware PR review plugin
