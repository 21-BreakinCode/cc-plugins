---
name: session-pick-up
description: Use after wrap-up to turn chosen topic numbers into atomic Zettelkasten cards grounded in the session case and up to 3 web sources.
---

# Pick-Up

Turn chosen topic number(s) from the last `wrap-up` into atomic Zettelkasten cards. Ground each card in this session's real case, plus up to 3 web sources per topic. Use `Read`/`Glob` for the vault and `WebSearch`/`WebFetch` for sources. Display everything in the terminal, then offer to save.

`pick-up` is strictly downstream of `wrap-up`. It accepts topic numbers only, no free-text topics, no "all topics" default.

## Argument

`$ARGUMENTS`: comma- or space-separated topic numbers referencing the last `wrap-up` (for example, `1,3`).

## Phase 0 — Resolve topics

Find the most recent `🧭 Session Wrap-Up` output in the conversation and its numbered candidate topics.

- **No numbers given** → output exactly this, then stop:
  ```
  Provide topic numbers, e.g. /obsidian-kit:session-pick-up 1,3. Run /obsidian-kit:session-wrap-up first if you haven't.
  ```
- **Numbers given but no wrap-up in the conversation** → output exactly this, then stop:
  ```
  Run /obsidian-kit:session-wrap-up first so I have numbered topics.
  ```
- **Some numbers out of range** (for example, `9` with only 5 topics listed) → note the invalid ones, then proceed with the valid numbers.

## Phase 1 — Build each topic

No confirmation gate. Resolve the numbers and produce cards directly. Read `references/card-format.md` and follow it. For each resolved topic:

1. **Session case:** identify what actually happened in THIS session that surfaced the topic (the concrete example, bug, or decision).
2. **Web sources:** `WebSearch` for the topic, `WebFetch` candidates to confirm relevance, keep the ≤3 most relevant. ≤3 PER TOPIC.
3. **Vault grounding:** read `typeFolders` from `.obsidian-kit.json` at the vault
   root, the same source Phase 3 writes through, and `Glob` `*.md` filenames
   under the folders mapped to `concept` or `takeaway`. Never read vault file
   contents. Reuse existing titles for `[[links]]` and matching tags.
4. **Atomic cards:** one concept per card, ≤50 lines each. Split a multi-concept topic into multiple cards. That topic's ≤3 sources are shared across its cards.

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

## Phase 3 — Offer to keep the cards

After printing the cards, ask ONCE with `AskUserQuestion`:

- `header`: `Save cards`
- `question`: `Write these N cards into the vault?`
- `options`: `Write all` / `Let me pick` / `Terminal only`

On `Write all`, write each card through the `format-note` rules. When a card
states a reusable idea, it is a `concept`. When a card states a lesson from
this session's case, it is a `takeaway`. Read the destination from
`typeFolders` in `.obsidian-kit.json`. Never hardcode a vault path.

On `Let me pick`, ask a second `AskUserQuestion` listing the card titles with
`multiSelect: true`, then write only the selected ones.

On `Terminal only`, write nothing and stop.

The vault has no version control. Never write without this approval, and never
overwrite an existing note. If a filename exists, report the collision and stop.
