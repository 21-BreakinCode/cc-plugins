# OKF Migration — code-reviewer Code Review Principles

**Status:** Approved design — 2026-08-07
**Consumer:** `code-reviewer` plugin only (single-tool; total control over format + reader + data)
**Supersedes on-disk format from:** `2026-08-07-code-reviewer-history-learner-design.md`

---

## 1. Problem

Code Review Principle bundles today are **append-only-forever role files** (`01-overview.md` … `07-red-flags.md`), each holding many `### ` entries. Consequences:

- **No lifecycle.** A pitfall mined from a PR months ago stays in the file and is cited as live even after the code was fixed/refactored. `write_principles.py:84-88` only ever appends + dedups; nothing retires.
- **No staleness horizon.** Nothing tells the reviewer agent an entry is old.
- **No trust signal.** No distinction between machine-mined and human-confirmed knowledge.

Migrate to **OKF v0.2** (Open Knowledge Format) to gain per-concept **status / staleness / trust tiers**, while preserving the reviewer agent's priority-ordered, char-capped consumption.

## 2. Goals

1. OKF v0.2-conformant bundles: **concept-major** (one entry = one `.md`), grouped in **subdirs by role**.
2. Per-entry **trust** (`verified` stamped on human approval), **staleness** (`stale_after`), and **deprecation** (`status`).
3. Reader preserves **priority ordering + 30K cap**, now additionally **skips `deprecated`** and **flags stale** entries.
4. **Deterministic in-place transform** of the existing 14 bundles — no re-mining.
5. Breaking change → `code-reviewer` **0.3.1 → 1.0.0**.

## 3. Non-goals

- **Auto-deprecation** — manual in v1 (auto-detecting that cited code was fixed is unreliable). YAGNI; revisit if manual proves annoying.
- **Footnote per-claim attribution** (`[^id]`) — each file is exactly one concept, so file-level `sources:` is exact; footnotes add nothing.
- **`Attested Computation`** concept type — N/A to review principles.
- **Sharing bundles with a second consumer** — portability is a free OKF side-benefit, not a driver.

## 4. Resolved decisions

| Fork | Decision |
|---|---|
| Granularity / layout | **Concept-major, subdirs by role** |
| Human `verified:` stamp | **Approval = verification** — Step-5 approval stamps `verified: human:whung` |
| Migrate existing 14 dirs | **Deterministic transform** (not re-mine) |
| Curated `01-overview` prose | **Fold into `index.md` body** |
| Stale entries in reader | **Keep + flag `[STALE]`**, do not drop |
| Deprecation | **Manual** in v1; reader skips `status: deprecated` |
| Version | **1.0.0** (breaking on-disk format + reader API) |

## 5. Bundle layout

```
CodeReviewPrinciple/<repo>/          ← one OKF bundle per repo
  index.md            # frontmatter: okf_version: "0.2"; body = grouped listing + curated/legacy prose
  log.md              # refresh history, newest-first
  .learn-state.json   # watermark — internal, NOT .md, exempt from OKF conformance; kept as-is
  red-flags/     <slug>.md   type: RedFlag
  pitfalls/      <slug>.md   type: Pitfall
  hotspots/      <slug>.md   type: Hotspot
  domain-traps/  <slug>.md   type: DomainTrap
  review-patterns/ <slug>.md type: ReviewPattern
  conventions/   <slug>.md   type: Convention
```

- **Filename** = kebab-slug of the entry title (`audio-stream-null-deref.md`).
- **Reader priority = fixed dir order** (red-flags → pitfalls → hotspots → domain-traps → review-patterns → conventions → `index.md` last). No `type`-parsing needed just to sort.
- **Role → type → dir map:**

  | Old file | `type` | Dir |
  |---|---|---|
  | 07-red-flags | `RedFlag` | `red-flags/` |
  | 02-pitfalls | `Pitfall` | `pitfalls/` |
  | 05-hotspots | `Hotspot` | `hotspots/` |
  | 04-domain-traps | `DomainTrap` | `domain-traps/` |
  | 03-review-patterns | `ReviewPattern` | `review-patterns/` |
  | 06-conventions | `Convention` | `conventions/` |
  | 01-overview | — | `index.md` body |

## 6. Concept frontmatter schema

```yaml
---
type: Pitfall                        # REQUIRED (OKF conformance)
title: ffprobe returns empty streams on 0-byte upload   # recommended
status: stable                       # stable | deprecated  (default stable)
stale_after: 2027-02-07              # generated.at date + 6 months
sources:                             # ≥1 REQUIRED — replaces the old `- **Evidence:**` line
  - resource: https://github.com/plaxieappier/video-center-2/pull/812
    title: PR #812
  - resource: a1b2c3d4e5f            # commit SHA (7+ hex)
generated: { by: refresh-principles/opus-4-8, at: 2026-08-07T00:00:00Z }
verified: [ { by: human:whung, at: 2026-08-07 } ]   # stamped on Step-5 approval
---
**What:** one-line description of the pattern/pitfall/hotspot.

**Why it matters:** one line (impact / what breaks).
```

- **Precision rule (unchanged in spirit):** a concept with **zero `sources[].resource`** is invalid → dropped. This is the OKF-native form of the old "no citation, no entry."
- **Trust tier derivation** (OKF §Trust, done by reader/agent, not stored): no `verified` → *unverified*; agent-only actors → *machine-confirmed*; any `human:<id>` → *human-reviewed*.

### `index.md`

```markdown
---
okf_version: "0.2"
---
# Overview — <repo>

<curated prose folded from old 01-overview, if any>

# Red flags
* [audio stream null deref](red-flags/audio-stream-null-deref.md) — one-line desc

# Pitfalls
* [ffprobe empty streams](pitfalls/ffprobe-parse-empty.md) — one-line desc
...

# Curated notes (uncited, pre-OKF)
<any pre-existing non-cited curated content that has no sources to become a concept>
```

### `log.md`

```markdown
# Refresh log — <repo>

## 2026-08-07
* **Migration**: bundle converted to OKF v0.2 (68 entries across 14 repos).
* **Refresh**: mined 2026-02-07 → 2026-08-07, +N entries.
```

## 7. Reader rewrite — `lib/load-principle.sh`

**Contract unchanged:** `load-principle.sh <bundle-dir> [cap-chars]` → stdout concatenation + coverage footer. Same 30K default cap.

```
NEW behavior:
  for dir in red-flags pitfalls hotspots domain-traps review-patterns conventions:
    for concept in sorted(dir/*.md):
      parse YAML frontmatter
      if status == deprecated:            → skip (count skipped_deprecated)
      if sources empty:                   → skip (defensive; shouldn't happen)
      stale = (stale_after < today)
      tier  = has(verified) ? "human-reviewed" : "machine-confirmed"
      emit "=== <type>: <title> [STALE?] [<tier>] ===" + sources + body
      (respect cap: if next concept exceeds cap → truncate remainder)
  emit index.md body last (lowest priority), within cap
  footer: included / stale-flagged / truncated / skipped-deprecated + source dir
```

- The per-concept header **carries the trust tier + stale flag** so the agent (§8) can down-weight without re-parsing frontmatter.
- Frontmatter parsing in bash: minimal — grep the handful of keys (`status`, `stale_after`, `verified` presence, `sources` presence). No full YAML parser dependency. `stale_after` compared lexically (ISO dates sort correctly).
- **`today`** is read from the system clock in the script (`date +%F`).

## 8. Agent — `agents/principle-reviewer.md`

- Phase 1 load command unchanged (`load-principle.sh <dir>`).
- Citations change: `red-flags/<slug>.md` instead of `07-red-flags.md:L<n>`.
- **New instruction:** entries emitted with `[STALE]` or that are *machine-confirmed* (no `verified`) are **lower confidence** — surface as "verify still live," not blocking. Human-reviewed + non-stale red-flags remain blocking.
- Coverage line reports role-dir counts instead of "N/7 files."

## 9. Skill — `skills/refresh-principles/SKILL.md`

- **Step 4 (distill):** each high-signal item → **one concept file** in its role dir (was: append to role file). Slugify title for filename. Build `sources:` from PR#/SHA/comment URLs. Drop anything with no source.
- **Step 5 (approve):** on approval, **stamp `verified: [{by: human:whung, at: <today>}]`** and `generated: {by: refresh-principles/<model>, at: <ts>}` on each written concept.
- **Step 6 (write):** write concept files; **prepend a `log.md` entry**; regenerate `index.md` listing; **dedup by `sources[].resource`** (was: title+citation).
- **Step 7 (watermark):** `.learn-state.json` unchanged.
- Update `references/principle-file-format.md` to document the concept schema + role→type→dir map.

## 10. Tests — `tests/test_principle_format.sh`

Replace the awk Evidence-line check with an **OKF conformance check** over a bundle:

1. Every non-reserved `.md` has a parseable `---`…`---` frontmatter block.
2. Frontmatter has a **non-empty `type`**.
3. Frontmatter has **≥1 `sources[].resource`** (precision rule).
4. Reserved names (`index.md`, `log.md`) exempt from #2/#3; `index.md` frontmatter may carry only `okf_version`.

Add a golden concept fixture (`fixtures/golden-concept.md`) + a negative fixture (missing `type`, missing `sources`). Keep `test_learn_state.sh` (watermark unaffected) but update any hardcoded `01-07` filename references.

## 11. Migration transform (existing 14 bundles)

**One-shot deterministic script** (`scripts/migrate-to-okf.py`, throwaway — lives in scratchpad or plugin `scripts/`, not shipped in the plugin runtime path).

Per bundle `<repo>/`:

1. For each old role file `0X-*.md`, split on `### ` headings.
2. For each `### ` entry that has an Evidence line (the 68 cited entries):
   - `title` ← heading text; filename ← slug.
   - `type` + dir ← role→type map (§5).
   - `sources` ← parse the `- **Evidence:**` line into `{resource}` items (PR URL, `commit <sha>`, comment URL).
   - body `What` / `Why it matters` ← existing body lines.
   - `generated.at` ← `2026-08-07`; `stale_after` ← `2027-02-07` (+6mo); `verified` ← `[{by: human:whung, at: 2026-08-07}]` (these 68 were approved last turn).
   - `status: stable`.
   - Write `<repo>/<dir>/<slug>.md`.
3. **Pre-existing non-cited curated content** (older `### R1.` checklists, tables, prose with no Evidence line) → append verbatim into `index.md` body under **"Curated notes (uncited, pre-OKF)"** (never dropped, never forced into a citation).
4. Old curated `01-overview` prose → `index.md` body top section.
5. Delete the old `0X-*.md` files after successful write.
6. Write `log.md` with a `## 2026-08-07 — Migration` entry.
7. Leave `.learn-state.json` untouched.

**Idempotency & safety:** operate on a copy first; assert **entry count preserved** (68 cited concepts across all 14 bundles) before deleting old files. Bootstrap bundle `creative-services-ai-tools` (no curated overview) gets a fresh `index.md`.

## 12. Blast radius (files touched)

Plugin source at `/Users/william.hung/Projects/PersonalPlugins/code-reviewer/`:

- `lib/load-principle.sh` — rewrite (§7)
- `agents/principle-reviewer.md` — edit (§8)
- `skills/refresh-principles/SKILL.md` — edit (§9)
- `skills/refresh-principles/references/principle-file-format.md` — rewrite (§6)
- `tests/test_principle_format.sh` — rewrite (§10) + new fixtures
- `tests/test_learn_state.sh` — minor: drop hardcoded `01-07` names
- `scripts/migrate-to-okf.py` — new, one-shot (§11)
- `.claude-plugin/marketplace.json` — version 0.3.1 → 1.0.0

Data at `$LIFEOS/01Project/Appier/CodeReviewPrinciple/<repo>/` — 14 bundles regenerated by the transform.

## 13. Success criteria / verification

1. `tests/test_principle_format.sh` passes on golden + negative fixtures.
2. Conformance check passes on **all 14 migrated bundles**: every `.md` has frontmatter + `type` + (for non-reserved) ≥1 source.
3. **Entry count preserved:** 68 cited concepts total, matching the pre-migration `### ` count per repo.
4. `load-principle.sh <bundle>` emits priority-ordered output (red-flags first), flags a synthetically-staled entry `[STALE]`, and omits a synthetically-`deprecated` entry — verified on one real bundle.
5. `principle-reviewer` dispatched on a sample diff cites `red-flags/<slug>.md` paths.
6. `code-reviewer` version reads `1.0.0`.
