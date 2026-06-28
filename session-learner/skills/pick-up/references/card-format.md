# Card Format

Rules and template for the atomic Zettelkasten cards `pick-up` produces.

## Hard rules

- **One concept per card.** If a topic holds two concepts, make two cards.
- **≤50 lines per card**, including the tag line and links. If a card would exceed 50 lines, split the concept or tighten the body — never ship a >50-line card.
- **Atomic & reusable.** Capture the idea, not the play-by-play. A card should still make sense months later, out of this session's context.

## Tags

- Slash-namespaced when fitting: `#domain/<area>`, `#lang/<lang>`.
- Prefer tags that match the user's existing vault taxonomy (from the `Glob` of vault filenames). Fall back to inferred namespaces when the vault is unavailable.

## Links

- At least 2 `[[wiki-links]]` per card.
- When a link target matches an existing vault card title, use that exact title.
- When no match exists, propose a plausible title (a future card).

## Sources

- Up to 3 web sources per topic, distributed across that topic's cards where relevant.
- Only sources you actually fetched and confirmed relevant. Omit the `Sources:` line if none.

## Session case

- Every card includes a `**From this session:**` line (1–2 lines) tying the concept to the concrete case that surfaced it here.

## Card template

```markdown
#domain/<area> #domain/<subarea>

## <Concise, specific, searchable title>

<body — the single concept, tight: bullets / one short code block / a small table>

**From this session:** <1–2 lines — the concrete case that surfaced this>

Related: [[Existing Vault Card]], [[Another Topic]]
Sources: <url1>, <url2>
```

## Output wrapper

Display all cards in the terminal like this:

```
🗂  Zettelkasten cards
Target: <vault-path>/Permanent/

═══════════════════════════════════════════════
Filename: <Card 1 Title>.md
═══════════════════════════════════════════════
<card 1 markdown>

═══════════════════════════════════════════════
Filename: <Card 2 Title>.md
═══════════════════════════════════════════════
<card 2 markdown>

— end (<N> cards) —

💡 Copy each block into a new .md file in Permanent/. Filename is shown above each block.
```
