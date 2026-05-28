---
description: "Digest a markdown note, file, or URL — break it down into atomic Zettelkasten cards"
allowed-tools: ["Read", "Glob", "WebFetch"]
argument-hint: "<path-or-url>"
---

# Session Learner — Digest

Read a single source (local file or URL), extract its themes, gate on user confirmation, then produce atomic Zettelkasten cards formatted to match the user's Obsidian vault. Display everything in the terminal — DO NOT write any files.

## Argument

`$ARGUMENTS` — the user-supplied path or URL.

## Phase 0 — Validate the argument

1. **No argument** → output exactly:
   ```
   Usage: /session-learner:digest <path-or-url>
   Example: /session-learner:digest ~/notes/k8s-scheduling.md
   ```
   Then stop.

2. **Looks like a URL** (starts with `http://` or `https://`):
   - Note: source-type is URL.
   - Fall through to Phase 1, loading via `WebFetch`.

3. **Otherwise** (treat as path):
   - Resolve relative paths against the user's current working directory.
   - If the file does not exist → output:
     ```
     Source not found: <resolved path>
     ```
     If an obvious near-match exists (e.g. same basename in a sibling directory found via `Glob`), suggest it. Then stop.

## Phase 1 — Load the content

- **URL** → call `WebFetch` on the URL. If the call fails, surface the error message + status to the user, suggest checking the URL or network, and stop. Do NOT retry automatically.
- **Local non-PDF** → call `Read` on the resolved path. If it errors (binary, encoding, permission), surface the error to the user and stop.
- **Local PDF** → call `Read` without `pages` first ONLY for short PDFs. If you know or detect the PDF has more than 10 pages, ask the user:
  ```
  PDF has N pages. Digest pages 1-10, or specify a range (e.g. "5-15")?
  ```
  Then read with the chosen `pages` value.

## Phase 1b — Vault grounding (parallel with Phase 1 when possible)

Look up the user's Zettelkasten vault to ground tag and link suggestions:

- Read env var `CLAUDE_SESSION_LEARNER_ZK_PATH`. If unset, default to:
  `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/LifeOS/03-Resource/Zettelkasten/Permanent`
- `Glob` `<vault-path>/*.md` for filenames only — do NOT read file contents.
- From the filenames, collect:
  - **Existing card titles** (filename without `.md`) — candidates for `[[wiki-links]]`
  - **Observed tag taxonomy** — if visible from any side-channel; otherwise infer common slash-namespaces (`#domain/*`, `#lang/*`) from sampled tag conventions

If the vault directory does not exist or contains no `.md` files, set a flag `vault_unavailable = true` and continue — Phase 2 will note this.

## Phase 1c — Content sanity checks

Before extracting themes:

- **Empty or trivial** (<200 chars stripped, or content is only YAML frontmatter) → ask:
  ```
  Source is very short (<200 chars of content). Proceed anyway? (yes/cancel)
  ```
- **Source resolves inside the vault path** (already a Zettelkasten card) → ask:
  ```
  This looks like an existing Zettelkasten card. Did you mean to re-process it? (yes/cancel)
  ```
- **Very large source** (>50k tokens of content) → ask:
  ```
  Source is large; themes may be lossy. Proceed? (yes/cancel)
  ```

If the user says `cancel`, stop. If `yes`, continue.

## Phase 2 — Extract & display themes (verification gate)

Display exactly this structure in the terminal:

```
📖 Digesting: <path-or-url>

## Themes
- <Theme 1 — one sentence>
- <Theme 2 — one sentence>
- <Theme 3 — one sentence>
(2-5 themes total)

## Key concepts
<5-10 short phrases — bullet list or comma-separated>

## Estimated breakdown
~<N>-<M> atomic cards, target stage: Permanent/

## Proposed tags
#domain/<area>, #lang/<lang>, ... (prefer tags grounded in the vault taxonomy)
```

If `vault_unavailable`, append:
```
⚠ Vault not found — link suggestions will be AI-proposed, not grounded in existing cards.
```

End the Phase 2 message with:
```
---
Proceed? Reply `yes` / `refine: <guidance>` / `cancel`
```

Then STOP and wait for the user's reply.

## Phase 2 — Reply handling

- `yes` → proceed to Phase 3.
- `refine: <guidance>` → re-extract themes with the guidance applied (e.g., "focus on error handling", "drop the architecture parts"). Re-display Phase 2 output and wait again. No fixed cap on refinement rounds.
- `refine` with no guidance → ask once: "What should I focus on or drop?" If the next reply is still `refine` with no detail, broaden scope and re-extract.
- `cancel` → stop. Output: `Cancelled. No cards produced.`
- Anything else → re-show the Phase 2 prompt with a one-line nudge: `Please reply yes / refine: <guidance> / cancel`. Do not error.

## Phase 3 — Produce atomic cards

Generate 2-10 atomic Zettelkasten cards from the source, driven by content density. For each card, apply these rules:

- **Title = filename** — concise, searchable, specific (e.g., "Claude Hooks", "NodeSelector vs NodeAffinity vs Compute Class"). NOT generic ("Hooks overview", "Notes part 1").
- **Tags** — slash-namespaced when fitting (`#domain/<area>`, `#lang/<lang>`). Prefer tags that match the user's existing taxonomy collected in Phase 1b.
- **Body** — H2 sub-sections allowed when content warrants; use bullets, fenced code blocks, blockquotes, or tables when appropriate to the material.
- **Links** — include at least 2 `[[wiki-links]]` per card. When a link target matches an existing vault card title from Phase 1b, use that exact title. When no good match exists, propose a plausible card title (which becomes a future card).
- **Atomic** — one idea per card. If two candidate cards overlap heavily, merge them.

Display exactly this structure:

`````
🗂  Zettelkasten cards from <source>
Target: <vault-path>/Permanent/

═══════════════════════════════════════════════
Filename: <Card 1 Title>.md
═══════════════════════════════════════════════
```markdown
#domain/<area> #domain/<subarea>

## <Card 1 Title>

> <optional reference, source URL, or pull-quote from the source>

<body — bullets, code blocks, tables, etc.>

Related: [[Other Card Title]], [[Another Card Title]]
```

═══════════════════════════════════════════════
Filename: <Card 2 Title>.md
═══════════════════════════════════════════════
```markdown
...
```

(repeat for all cards)

— end (<N> cards) —

💡 Copy each block into a new `.md` file in `Permanent/`. Filename is shown above each block.
`````

## Constraints

- DO NOT write any files. All output is terminal-only.
- DO NOT skip Phase 2 (the verification gate) even if the source seems obvious.
- DO NOT auto-retry `WebFetch` failures.
- DO NOT read files inside the vault — only `Glob` filenames in Phase 1b.
- DO NOT exceed 10 cards. If content suggests more, merge the closest pair.
