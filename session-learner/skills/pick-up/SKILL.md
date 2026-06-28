---
name: pick-up
description: Use after wrap-up to turn chosen topic numbers into atomic Zettelkasten cards grounded in the session case and up to 3 web sources.
---

# Pick-Up

Turn chosen topic number(s) from the last `wrap-up` into atomic Zettelkasten cards, each grounded in this session's real case plus up to 3 web sources per topic. Use `Read`/`Glob` for the vault and `WebSearch`/`WebFetch` for sources. Display everything in the terminal — DO NOT write any files.

`pick-up` is strictly downstream of `wrap-up`. It accepts topic numbers only.

## Argument

`$ARGUMENTS` — comma- or space-separated topic numbers referencing the last `wrap-up` (e.g. `1,3`).

## Phase 0 — Resolve topics

Find the most recent `🧭 Session Wrap-Up` output in the conversation and its numbered candidate topics.

- **No numbers given** → output exactly this, then stop:
  ```
  Provide topic numbers, e.g. /session-learner:pick-up 1,3. Run /session-learner:wrap-up first if you haven't.
  ```
- **Numbers given but no wrap-up in the conversation** → output exactly this, then stop:
  ```
  Run /session-learner:wrap-up first so I have numbered topics.
  ```
- **Some numbers out of range** (e.g. `9` when wrap-up listed 5) → note the invalid ones in the output and proceed with the valid numbers.

## Phase 1 — Build each topic

Read `references/card-format.md` and follow it. For each resolved topic:

1. **Session case** — identify what actually happened in THIS session that surfaced the topic (the concrete example, bug, or decision).
2. **Web sources** — `WebSearch` for the topic, `WebFetch` candidates to confirm relevance, keep the ≤3 most relevant. ≤3 PER TOPIC.
3. **Vault grounding** — read `CLAUDE_SESSION_LEARNER_ZK_PATH` (default below), `Glob` `*.md` filenames ONLY, and reuse existing titles for `[[links]]` and matching tags.
4. **Atomic cards** — one concept per card, ≤50 lines each. Split a multi-concept topic into multiple cards; a topic's ≤3 sources are shared across its cards.

Default vault path if the env var is unset:
`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/03-Resource/Zettelkasten/Permanent`

## Phase 2 — Output

Display the cards using the template and output wrapper in `references/card-format.md`.

## Graceful degradation

- **No web results or no network** → emit cards with the session case only and append:
  ```
  ⚠ No web sources found — cards cite the session case only.
  ```
- **Vault missing or empty** → `[[links]]` become AI-proposed and append:
  ```
  ⚠ Vault not found — links are proposed, not grounded.
  ```

## Constraints

- DO NOT write any files. Terminal copy-paste only.
- Topic numbers only — no ad-hoc free-text topics, no "all topics" default.
- No confirmation gate — resolve numbers and produce cards directly.
- Every card ≤50 lines, exactly one concept. Split when bigger.
- DO NOT read vault file contents — `Glob` filenames only.
