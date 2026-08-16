# Visual Patterns Reference

Rules for adding diagrams and callouts to markdown notes. A diagram replaces
re-reading — it makes the concept scannable at a glance.

## When to diagram

Diagram when the concept has **shape** — nesting, layers, flow, comparison,
branching, or convergence. Do NOT diagram flat lists, definitions, or anything
a numbered list already conveys.

## Concept-shape → diagram-type

| Concept shape | Diagram type | Example |
|---|---|---|
| Nesting / containment | box-in-box | node > pod > container > sidecar |
| Layers / privilege | stacked layers with separator | kernel-space / user-space |
| Side-by-side comparison | parallel columns | before/after, L4 vs L7 |
| Scale comparison | different-sized boxes | 1MB OS thread vs 2KB goroutine |
| Request / data flow | arrow diagram | syscall: user → kernel → response |
| Decision / branch | fork with labels | TryAcquire true/false paths |
| Timeline / sequence | vertical timeline | git history of commits |
| Fan-in / fan-out | converging/diverging arrows | N pods → 1 shared resource |
| Binding / mapping | entity relationship | G → P → M in GMP model |
| State machine | labeled transitions | goroutine park/wake cycle |

## Diagram constraints

1. **Compact**: ≤15 lines. If it's bigger, you're diagramming too much.
2. **Fenced**: always in a triple-backtick code block (ASCII survives monospace).
3. **Labeled with real names**: use actual terms from the note, not abstract A/B.
4. **One per concept**: if a note has two spatial concepts, two small diagrams
   beat one large one.
5. **Placed before prose**: diagram first, then the tightened bullet-point
   explanation. The diagram is the overview; the prose adds nuance.
6. **No horizontal scroll**: stay under ~60 chars wide.

## One-screen budget

Zettelkasten permanent notes must fit on one screen (~40 lines). When adding
a diagram, **tighten the prose** to compensate:

- Remove words the diagram now shows (e.g. "X contains Y" when the nesting
  diagram already shows X wrapping Y).
- Merge redundant bullets.
- Move inlined definitions to wikilinks if a dedicated note exists.

Never let a diagram push a note past one screen.

## Callout rules

| Block type | Callout | When to use |
|---|---|---|
| "From this session" | `> [!example] From this session` | Bridge from theory to real incident. Every Zettelkasten note that grew from a debugging session. |
| Warning / red flag | `> [!warning]` | A trap, anti-pattern, or common mistake. |
| Key insight / rule | `> [!tip]` | A distilled principle the reader should remember. |

Only use callouts for blocks that **need to stand out**. A note with three
callouts has zero callouts — nothing stands out. Prefer one per note.

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

- Don't diagram a flat definition (socket = one end of a network pipe).
- Don't add a diagram just because a note lacks one — if the concept is linear,
  a numbered list IS the visual.
- Don't use Mermaid for Zettelkasten notes — ASCII is more compact and doesn't
  need rendering.
- Don't add callouts to short scope/universality paragraphs at the end of notes.
- Don't wrap every bold term in a callout — callouts are for blocks, not words.
