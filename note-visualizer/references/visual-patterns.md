# Visual Patterns Reference

Rules for adding diagrams and callouts to markdown notes. A diagram replaces
re-reading. It makes the concept scannable at a glance.

## When to diagram

When a concept has **shape**, meaning nesting, layers, flow, comparison,
branching, or convergence, diagram it. Do not diagram flat lists, definitions,
or anything a numbered list already conveys.

## Concept-shape → diagram-type

| Concept shape | Diagram type | Example |
|---|---|---|
| Nesting / containment | box-in-box | node > pod > container > sidecar |
| Layers / privilege | stacked layers with separator | kernel-space / user-space |
| Side-by-side comparison | parallel columns | before/after, L4 vs L7 |
| Scale comparison | different-sized boxes | 1MB OS thread vs 2KB goroutine |
| Request / data flow | arrow diagram | syscall: user → kernel → response |
| Multi-actor interaction | UML-style sequence diagram (lifelines) | You → Local Repo → GitHub push/pull |
| Decision / branch | fork with labels | TryAcquire true/false paths |
| Timeline / sequence | vertical timeline | git history of commits |
| Fan-in / fan-out | converging/diverging arrows | N pods → 1 shared resource |
| Binding / mapping | entity relationship | G → P → M in GMP model |
| State machine | labeled transitions | goroutine park/wake cycle |

### Flow: arrow or sequence diagram

Default to the one-line arrow above for a single path with no persistent
participant.

When 3 or more participants trade several ordered messages, a real
back-and-forth and not one pipeline, switch to a UML-style sequence diagram:

```
┌─────┐          ┌────────────┐          ┌────────┐
│ You │          │ Local Repo │          │ GitHub │
└─────┘          └────────────┘          └────────┘
   │                    │                     │
   │   edit ~/.zshrc    │                     │
   ├────────────────────→                     │
   │                    │      git push       │
   │                    ├─────────────────────→
```

This style has its own budget: up to 4 participants, about 8 messages, and
about 25 lines. Width can exceed 60 chars. It uses the same box-drawing set
listed below.

## Diagram constraints

1. **Compact**: ≤15 lines (sequence diagrams: ≤25, see above). If it is
   bigger than that, you are diagramming too much.
2. **Fenced**: always in a triple-backtick code block (ASCII survives monospace).
3. **Labeled with real names**: use actual terms from the note, not abstract A/B.
4. **One per concept**: if a note has two spatial concepts, two small diagrams
   beat one large one.
5. **Placed before prose**: diagram first, then the tightened bullet-point
   explanation. The diagram is the overview. The prose adds nuance.
6. **No horizontal scroll**: stay under ~60 chars wide (sequence diagrams
   can exceed this limit, see above).

## One-screen budget

Zettelkasten permanent notes must fit on one screen (~40 lines). When adding
a diagram, **tighten the prose** to compensate:

- When the nesting diagram already shows X wrapping Y, drop redundant words
  like "X contains Y".
- Merge redundant bullets.
- If a dedicated note exists, move inlined definitions to wikilinks.

Never let a diagram push a note past one screen.

## Callout rules

| Block type | Callout | When to use |
|---|---|---|
| "From this session" | `> [!example] From this session` | Bridge from theory to real incident. Every Zettelkasten note that grew from a debugging session. |
| Warning / red flag | `> [!warning]` | A trap, anti-pattern, or common mistake. |
| Key insight / rule | `> [!tip]` | A distilled principle to remember. |

Only use callouts for blocks that **need to stand out**. A note with three
callouts has zero callouts. Nothing stands out. Prefer one per note.

## Box-drawing characters

Use simple ASCII that renders everywhere:

```
─ │ ┌ ┐ └ ┘ ├ ┤ ┬ ┴ ┼  (box drawing)
═ ║ ╔ ╗ ╚ ╝                (double-line for emphasis)
→ ← ↑ ↓ ▶ ⏸               (arrows and status)
✓ ✗                        (pass/fail markers)
```

Avoid Unicode art that breaks in narrow terminals.

## What NOT to do

- Do not diagram a flat definition (socket = one end of a network pipe).
- If the concept is linear, a numbered list is already the visual. Do not add
  a diagram just because a note lacks one.
- Do not use Mermaid for Zettelkasten notes. ASCII is more compact and does
  not need rendering.
- Do not add callouts to short scope or universality paragraphs at the end
  of notes.
- Do not wrap every bold term in a callout. Callouts are for blocks, not
  for words.
