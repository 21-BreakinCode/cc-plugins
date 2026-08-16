---
name: visualize
description: Use proactively after creating or editing notes under Zettelkasten/ — add compact ASCII diagrams for spatial concepts and Obsidian callouts for key blocks to make notes scannable. Also use when the user says 'visualize', 'add diagrams', '加圖', 'refine notes', 'make scannable', or points at a folder/file of markdown notes and asks for visual improvement.
---

# Visualize — make notes scannable

Add compact diagrams and callouts to markdown notes so spatial concepts are
**drawn, not described**. Two modes: inline (while writing) and batch (on
existing notes).

## 1. Load the visual-patterns reference

Read `${CLAUDE_PLUGIN_ROOT}/references/visual-patterns.md`. This is the
single source of truth for which concept shapes get which diagram types,
diagram constraints, callout rules, and the one-screen budget.

## 2. Determine mode

- **Inline mode** — you are currently writing or editing a note (e.g. via
  session-learner pick-up, daily-helper, or direct authoring). Apply the
  visual patterns as you write: place the diagram before the prose, tighten
  bullets to stay within budget.

- **Batch mode** — the user pointed at a folder, file glob, or file list.
  Scan each target note, identify concept shapes and callout candidates,
  and apply refinements. Report a summary table at the end.

## 3. For each note (both modes)

1. **Identify concept shapes.** Read the note. For each paragraph or bullet
   cluster, check: does this explain something with shape (nesting, layers,
   flow, comparison, branching, convergence, fan-in/out, timeline, binding)?
   If yes, it needs a diagram per the patterns reference.

2. **Draft the diagram.** Use the concept-shape → diagram-type table. Keep it
   ≤15 lines, ≤60 chars wide, in a fenced code block. Label with real names
   from the note.

3. **Place diagram before prose.** The diagram is the overview the eye lands
   on; the bullets add nuance the diagram can't show.

4. **Tighten prose.** Remove words the diagram now conveys. Merge redundant
   bullets. The note must still fit one screen (~40 lines) after adding the
   diagram.

5. **Add callouts.** Wrap "From this session" blocks in
   `> [!example] From this session`. Use `> [!warning]` for traps/anti-patterns.
   Prefer one callout per note — if everything stands out, nothing does.

6. **Skip if no shape.** Linear definitions and flat lists are already
   scannable. Don't force a diagram where a numbered list is the right form.

## 4. Batch-mode summary

After processing all notes, output a table:

```
| Note | Diagram added | Callout added | Lines before → after |
|---|---|---|---|
| 01__process_vs_thread | process isolation | — | 13 → 22 |
| ...
```

## Verify

- [ ] Every diagram is in a fenced code block (no unfenced ASCII)
- [ ] No note exceeds ~40 lines
- [ ] Diagrams use real names, not abstract labels
- [ ] No diagram for a flat/linear concept
- [ ] Callouts are used sparingly (≤1 per note preferred)
- [ ] Prose was tightened, not just added to
