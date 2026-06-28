# session-learner 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace session-learner's v1 commands+hooks with a three-skill reflection funnel (`wrap-up` → `pick-up` → `recommend`) and ship it as v2.0.0.

**Architecture:** Three independent skills under `session-learner/skills/`, each a single `SKILL.md`; `pick-up` carries its heavy detail in `references/card-format.md` (progressive disclosure). Skills are stateless and communicate only through the conversation transcript. `commands/`, `hooks/`, and `lib/` are deleted. The marketplace doc generator (`scripts/generate-docs.mjs`) auto-discovers skills and regenerates README/CATALOG/site on commit via the pre-commit hook.

**Tech Stack:** Markdown SKILL.md files with YAML frontmatter; JSON manifests (`plugin.json`, `marketplace.json`, `content/plugins.content.json`); Node-based doc generator invoked through `./scripts/cicd.sh`.

## Global Constraints

- Plugin version becomes exactly `2.0.0` in BOTH `session-learner/.claude-plugin/plugin.json` and the session-learner entry of `.claude-plugin/marketplace.json`.
- Skills NEVER write files — all output is terminal-only.
- Every Zettelkasten card `pick-up` emits is ≤50 lines and holds exactly one concept; multi-concept topics split into multiple cards.
- `pick-up` accepts topic NUMBERS only (no ad-hoc free text, no no-arg "all" mode) and requires a prior `wrap-up` in the conversation.
- Web sources are ≤3 PER TOPIC (so `/pick-up 1,3` ⇒ up to 6 total).
- Skill frontmatter is `name` + `description` only (match the sibling `autoresearch/skills/experiment-loop/SKILL.md` convention); description's first sentence ≤140 chars (the generator truncates with `firstSentence(desc, 140)`).
- NEVER hand-edit generated files (`session-learner/README.md`, `CATALOG.md`, `site/data/plugins.json`, `site/*.html`) — the pre-commit hook regenerates and stages them.
- Only `CLAUDE_SESSION_LEARNER_ZK_PATH` survives in config; `GIT_MODE` and `MAX_AGE_DAYS` are removed everywhere.
- Spec of record: `docs/superpowers/specs/2026-06-28-session-learner-2.0-design.md`.
- Work happens on branch `feat/session-learner-2.0` (already created).

---

### Task 1: `wrap-up` skill

**Files:**
- Create: `session-learner/skills/wrap-up/SKILL.md`

**Interfaces:**
- Consumes: nothing (entry point of the funnel).
- Produces: terminal output titled `🧭 Session Wrap-Up` with a `## Watch-outs this session` section and a NUMBERED `## Candidate take-away topics` list. The numbering is the contract `pick-up`/`recommend` rely on.

- [ ] **Step 1: Write the skill file**

Create `session-learner/skills/wrap-up/SKILL.md` with exactly this content:

````markdown
---
name: wrap-up
description: Use at the end of a working or debugging session to reflect on pitfalls worth noticing and list candidate take-away topics to keep.
---

# Session Wrap-Up

Reflect on the current session and *diverge*: surface what's worth noticing, then list candidate take-away topics. Use `Read`/`Grep`/`Glob` to inspect files referenced this session when it makes a watch-out concrete. Display everything in the terminal — DO NOT write any files.

## The funnel

- **wrap-up** (this skill) — reflect → watch-outs + numbered candidate topics
- **pick-up** — turn chosen topic number(s) into atomic Zettelkasten cards
- **recommend** — pick exactly one topic to keep, with reasoning

## Instructions

Review the full conversation in this session, then produce exactly the two sections below.

### Watch-outs this session

1–4 items. Each must be a pitfall hit, a footgun, a fragile assumption, or a non-obvious thing worth remembering — and must trace to a real moment in this session (a correction, a bug, a surprising constraint). Skip generic advice. If an item cannot be tied to something that actually happened, drop it.

### Candidate take-away topics

2–6 atomic, reusable topics drawn from the session. NUMBER them. Each is one line: a concise title plus why it is worth keeping. Favor knowledge that is reusable across projects and conceptual over one-off fixes.

## Output format

Display exactly this structure in the terminal:

```
🧭 Session Wrap-Up

## Watch-outs this session
- <watch-out 1>
- <watch-out 2>

## Candidate take-away topics
1. <Topic title> — <why it's worth keeping>
2. <Topic title> — <why it's worth keeping>
3. <Topic title> — <why it's worth keeping>

---
Next:
  /session-learner:pick-up <n[,n…]>   → turn topic(s) into atomic Zettelkasten cards
  /session-learner:recommend           → not sure which? I'll pick the single best one and tell you why
```

## Empty or trivial session

If nothing substantial happened (no real work, debugging, or decisions), output exactly this and stop — no watch-outs, no topic list:

```
Not much to wrap up yet — no substantial work this session.
```

## Constraints

- DO NOT write any files. Terminal output only.
- Topics MUST be numbered so pick-up and recommend can reference them by index.
- Watch-outs MUST reference real session moments, not generic best practices.
````

- [ ] **Step 2: Verify frontmatter parses and the generator picks the skill up**

Run: `node -e "import('./scripts/lib/frontmatter.mjs').then(m=>{const fs=require('fs');const fm=m.parseFrontmatter(fs.readFileSync('session-learner/skills/wrap-up/SKILL.md','utf8'));console.log(JSON.stringify({name:fm.name,len:fm.description.length}))})"`
Expected: prints `{"name":"wrap-up","len":<≤140>}` (no parse error; length ≤ 140).

- [ ] **Step 3: Regenerate docs and confirm the skill is listed**

Run: `./scripts/cicd.sh GEN && grep -n 'wrap-up' session-learner/README.md`
Expected: GEN prints `✓ wrote ... files`; grep shows a `## Skills` entry mentioning `wrap-up`.

- [ ] **Step 4: Commit**

```bash
git add session-learner/skills/wrap-up/SKILL.md
git commit -m "feat(session-learner): add wrap-up skill"
```
(The pre-commit hook regenerates and stages README/CATALOG/site automatically.)

---

### Task 2: `pick-up` skill + card-format reference

**Files:**
- Create: `session-learner/skills/pick-up/SKILL.md`
- Create: `session-learner/skills/pick-up/references/card-format.md`

**Interfaces:**
- Consumes: the numbered topics from the most recent `🧭 Session Wrap-Up` in the conversation; `$ARGUMENTS` = comma/space-separated topic numbers.
- Produces: terminal-only atomic Zettelkasten cards following `references/card-format.md`.

- [ ] **Step 1: Write the skill file**

Create `session-learner/skills/pick-up/SKILL.md` with exactly this content:

````markdown
---
name: pick-up
description: Use after wrap-up to turn chosen topic numbers into atomic Zettelkasten cards grounded in the session case and up to 3 web sources per topic.
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
````

- [ ] **Step 2: Write the card-format reference**

Create `session-learner/skills/pick-up/references/card-format.md` with exactly this content:

`````markdown
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
`````

- [ ] **Step 3: Verify frontmatter parses and the reference exists**

Run: `node -e "import('./scripts/lib/frontmatter.mjs').then(m=>{const fs=require('fs');const fm=m.parseFrontmatter(fs.readFileSync('session-learner/skills/pick-up/SKILL.md','utf8'));console.log(JSON.stringify({name:fm.name,len:fm.description.length}))})" && test -f session-learner/skills/pick-up/references/card-format.md && echo REFERENCE_OK`
Expected: prints `{"name":"pick-up","len":<≤140>}` then `REFERENCE_OK`.

- [ ] **Step 4: Regenerate docs and confirm the skill is listed**

Run: `./scripts/cicd.sh GEN && grep -n 'pick-up' session-learner/README.md`
Expected: grep shows a `## Skills` entry mentioning `pick-up`.

- [ ] **Step 5: Commit**

```bash
git add session-learner/skills/pick-up/SKILL.md session-learner/skills/pick-up/references/card-format.md
git commit -m "feat(session-learner): add pick-up skill + card-format reference"
```

---

### Task 3: `recommend` skill

**Files:**
- Create: `session-learner/skills/recommend/SKILL.md`

**Interfaces:**
- Consumes: the numbered topics from the most recent `🧭 Session Wrap-Up` in the conversation.
- Produces: terminal-only output titled `🎯 Recommended take-away` naming exactly one topic and ending with a `/session-learner:pick-up <n>` hint.

- [ ] **Step 1: Write the skill file**

Create `session-learner/skills/recommend/SKILL.md` with exactly this content:

````markdown
---
name: recommend
description: Use after wrap-up when unsure which take-away topic matters most — picks exactly one topic to keep, with reasoning.
---

# Recommend

From the candidate topics in the last `wrap-up`, *converge*: pick exactly ONE to keep and justify it. Display everything in the terminal — DO NOT write any files.

## Argument

None. Reads the numbered topics from the most recent `🧭 Session Wrap-Up` in the conversation.

## Phase 0 — Resolve topics

- **No wrap-up in the conversation** → output exactly this, then stop:
  ```
  Run /session-learner:wrap-up first so I have topics to choose from.
  ```
- **Only one candidate topic** → recommend it, noting it was the only one.

## Phase 1 — Rank and pick

Rank the candidate topics on:

- **Reusability** — applies across projects, not a one-off fix.
- **Cost of the lesson** — how much pain it caused here, or would prevent later.
- **Recurrence** — how often it will come up again.
- **Non-obviousness** — worth recording vs. already-common knowledge.

Pick the single strongest topic.

## Output format

```
🎯 Recommended take-away

Topic <n> — <title>

Why this one:
  • <strongest reason: leverage / reusability / cost-of-not-knowing>
  • <why it beats the runners-up, named briefly>

---
Deepen it →  /session-learner:pick-up <n>
```

## Constraints

- DO NOT write any files. Terminal output only.
- Pick exactly ONE topic. Do not produce cards — that is pick-up's job.
````

- [ ] **Step 2: Verify frontmatter parses**

Run: `node -e "import('./scripts/lib/frontmatter.mjs').then(m=>{const fs=require('fs');const fm=m.parseFrontmatter(fs.readFileSync('session-learner/skills/recommend/SKILL.md','utf8'));console.log(JSON.stringify({name:fm.name,len:fm.description.length}))})"`
Expected: prints `{"name":"recommend","len":<≤140>}`.

- [ ] **Step 3: Regenerate docs and confirm the skill is listed**

Run: `./scripts/cicd.sh GEN && grep -n 'recommend' session-learner/README.md`
Expected: grep shows a `## Skills` entry mentioning `recommend`.

- [ ] **Step 4: Commit**

```bash
git add session-learner/skills/recommend/SKILL.md
git commit -m "feat(session-learner): add recommend skill"
```

---

### Task 4: Clean slate + version 2.0.0 + metadata

**Files:**
- Delete: `session-learner/commands/` (digest.md, take-away.md)
- Delete: `session-learner/hooks/` (hooks.json, session-start.sh, session-end.sh, pre-compact.sh)
- Delete: `session-learner/lib/` (common.sh)
- Modify: `session-learner/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json` (session-learner entry only)
- Modify: `content/plugins.content.json` (session-learner entry only)

**Interfaces:**
- Consumes: the three skills from Tasks 1–3 (so the regenerated README shows a populated `## Skills` section and no `## Commands`).
- Produces: a coherent v2.0.0 release — skill-only plugin, trimmed config, funnel-prose metadata.

- [ ] **Step 1: Delete the v1 surface**

Run:
```bash
git rm -r session-learner/commands session-learner/hooks session-learner/lib
```
Expected: removes 2 commands, 4 hook files, and 1 lib file.

- [ ] **Step 2: Bump and re-describe `plugin.json`**

In `session-learner/.claude-plugin/plugin.json`, replace the `description` and `version`:
- `description`: `"Turn a working session into atomic Zettelkasten knowledge via a wrap-up → pick-up → recommend reflection funnel"`
- `version`: `"2.0.0"`

Resulting file:
```json
{
  "name": "session-learner",
  "description": "Turn a working session into atomic Zettelkasten knowledge via a wrap-up → pick-up → recommend reflection funnel",
  "version": "2.0.0",
  "author": {
    "name": "William Hung"
  }
}
```

- [ ] **Step 3: Update the `marketplace.json` session-learner entry**

In `.claude-plugin/marketplace.json`, replace ONLY the session-learner object's `description` and `version`:
```json
    {
      "name": "session-learner",
      "source": "./session-learner",
      "description": "Turn a working session into atomic Zettelkasten knowledge via a wrap-up → pick-up → recommend reflection funnel",
      "version": "2.0.0",
      "strict": true
    },
```

- [ ] **Step 4: Update `content/plugins.content.json` session-learner entry**

Replace the entire session-learner object (tagline, summary, trimmed config) with:
```json
    "session-learner": {
      "tagline": "Turn a session into atomic Zettelkasten knowledge",
      "summary": "A wrap-up → pick-up → recommend reflection funnel: wrap-up surfaces session pitfalls and candidate take-away topics, pick-up turns chosen topics into atomic Zettelkasten cards grounded in the real case and up to 3 web sources, and recommend picks the single topic most worth keeping.",
      "category": "memory",
      "dependsOn": [],
      "config": [
        { "name": "CLAUDE_SESSION_LEARNER_ZK_PATH", "default": "~/…/LifeOS/03-Resource/Zettelkasten/Permanent", "description": "Vault `Permanent/` dir used to ground `pick-up` card links and tags." }
      ]
    },
```

- [ ] **Step 5: Regenerate and verify the full gate**

Run: `./scripts/cicd.sh GEN && ./scripts/cicd.sh VERIFY`
Expected: GEN writes files; VERIFY runs the generator unit tests (all pass) and `--check` reports no drift (exit 0).

- [ ] **Step 6: Confirm the README reflects v2.0.0**

Run: `grep -nE 'wrap-up|pick-up|recommend|## Skills' session-learner/README.md && grep -c '## Commands' session-learner/README.md && grep -c 'CLAUDE_SESSION_LEARNER_GIT_MODE' session-learner/README.md`
Expected: all three skills + `## Skills` present; `## Commands` count is `0`; `CLAUDE_SESSION_LEARNER_GIT_MODE` count is `0`.

- [ ] **Step 7: Confirm no dangling references to removed env vars or commands**

Run: `grep -rnE 'GIT_MODE|MAX_AGE_DAYS|take-away|/digest' session-learner content/plugins.content.json .claude-plugin/marketplace.json || echo CLEAN`
Expected: `CLEAN` (no matches outside generated/spec files).

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat(session-learner)!: 2.0.0 — clean slate, skills-only reflection funnel"
```
(The `!` marks the breaking change: v1 commands and hooks removed.)

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-06-28-session-learner-2.0-design.md`):
- Clean slate (remove commands/hooks/lib) → Task 4 Step 1. ✓
- 3 skill dirs + progressive disclosure in pick-up → Tasks 1–3 (pick-up has `references/card-format.md`). ✓
- Stateless + index args; wrap-up required first → pick-up Phase 0, recommend Phase 0. ✓
- ≤3 sources per topic, active search, graceful degradation → pick-up Phase 1 + Graceful degradation. ✓
- Vault grounding via ZK_PATH, graceful → pick-up Phase 1 step 3 + degradation. ✓
- ≤50-line / one-concept cards → card-format.md Hard rules + pick-up constraints. ✓
- No confirmation gate → pick-up constraints. ✓
- recommend criteria + exactly one + pick-up hint → Task 3. ✓
- Version 2.0.0 in plugin.json + marketplace.json → Task 4 Steps 2–3. ✓
- content metadata + config trim (ZK_PATH only) → Task 4 Step 4. ✓
- Generated docs via cicd.sh, CHECK passes → Task 4 Steps 5–6. ✓
- README diagram: spec only, README prose → summary in Task 4 Step 4 carries the funnel prose; no generator change. ✓

**2. Placeholder scan:** All SKILL.md / reference contents are complete and inlined. The only `<...>` tokens are inside the skills' own output TEMPLATES (intended literal guidance for the model at runtime), not plan placeholders. ✓

**3. Type consistency:** Skill directory names match frontmatter `name` (`wrap-up`, `pick-up`, `recommend`). The output title `🧭 Session Wrap-Up` produced by Task 1 is the exact string Tasks 2 & 3 search for in their Phase 0. The `/session-learner:pick-up <n>` hint in `wrap-up` and `recommend` matches `pick-up`'s number-only argument contract. ✓

No gaps found.

## Execution Handoff

Plan complete. The user has already asked to implement, so execution follows immediately.
