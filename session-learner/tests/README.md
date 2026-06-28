# session-learner tests

Regression check for the per-card Zettelkasten contract that `pick-up` must
satisfy (`skills/pick-up/references/card-format.md`).

## What `score_cards.sh` checks

It reads a directory of one-card-per-file markdown and scores the **mechanical**
rules:

| Rule | Requirement |
|---|---|
| R1 | card ≤ 50 lines (hard) |
| R2 | ≥ 1 `#domain/...` tag line |
| R3 | ≥ 2 `[[wiki-links]]` |
| R4 | a `**From this session:**` line |
| R5 | `Sources:` lists ≤ 3 URLs |
| R6 | `Sources:` lists ≥ 1 URL |

It prints `objective_score` (0–10), `hard_violations`, `num_cards`, a per-rule
tally, and a per-card breakdown. The two qualitative rules — **one concept per
card** and **atomic/reusable** — are not mechanically checkable and need an LLM
judge (see below).

## Run the deterministic check

```bash
bash session-learner/tests/test_card_conformance.sh
```

Scores the committed golden cards in `fixtures/golden-cards/` and asserts
`objective_score 10.0`, `hard_violations 0`, `num_cards 3`. This guards both the
scorer logic and that the reference cards still satisfy the contract.

Score an arbitrary card directory directly:

```bash
bash session-learner/tests/score_cards.sh /path/to/cards
```

## Full regression after editing the skills

The skills are prompts, so a complete check regenerates cards from the fixed
fixture and re-scores. This step needs an agent/LLM, not plain CI:

1. Have an agent act as `/session-learner:pick-up 1,2,3` using the CURRENT
   `skills/pick-up/SKILL.md` + `references/card-format.md`, the fixed
   `fixtures/session.md`, and the numbered topics in `fixtures/wrapup.md`.
   Require live web sources. Write one card per file to a temp dir.
2. Score: `bash session-learner/tests/score_cards.sh <tmpdir>` → expect
   `objective_score 10.0`, `hard_violations 0`.
3. LLM-judge each card: `one_concept` ∈ {0,1}, `atomic` ∈ [1,10]; confirm the
   `Sources:` URLs are real and actually support the card.

## Fixtures

- `fixtures/session.md` — fixed real-case session (input to `wrap-up`).
- `fixtures/wrapup.md` — the `wrap-up` output with numbered topics (fixed input
  to `pick-up`).
- `fixtures/golden-cards/*.md` — reference conforming cards produced by the
  workflow above (baseline `card_conformance` 9.87/10). Regenerate these only
  when the card contract intentionally changes.
