# session-learner 2.0 — design

- **Date:** 2026-06-28
- **Status:** Approved (design); pending implementation plan
- **Plugin:** `session-learner` (current v1.1.2 → **v2.0.0**, breaking)

## Goal

Replace session-learner's v1 surface (two commands + three hooks) with a focused
**three-skill reflection funnel** that turns a working session into atomic
Zettelkasten knowledge:

1. **`wrap-up`** — *diverge*: reflect on the session, surface pitfalls / things
   worth noticing, and list N candidate take-away topics.
2. **`pick-up`** — *deepen*: turn chosen topic number(s) into atomic Zettelkasten
   cards, each grounded in this session's real case plus ≤3 web sources.
3. **`recommend`** — *converge*: from the candidate topics, pick exactly one to
   keep, with reasoning.

"Below behavior only is enough" — v2.0.0 is a clean slate: the 3 skills are the
entire plugin. No hooks, no commands, no background persistence.

## Decisions (locked)

| Fork | Decision | Consequence |
|---|---|---|
| v1 surface | **Clean slate — skills only** | Remove `commands/`, `hooks/`, `lib/`. No cross-session memory or git-aware startup injection. Smallest surface. |
| Skill structure | **3 skill dirs; progressive disclosure in `pick-up`** | Each `SKILL.md` stays lean; `pick-up`'s heavy detail lives in `pick-up/references/card-format.md`. |
| Topic flow | **Stateless + index args** | No state file. Downstream skills read the last `wrap-up` output already in the conversation. |
| `pick-up` input | **Topic numbers only; `wrap-up` required first** | No ad-hoc free-text topics, no no-arg "all" mode. Funnel is enforced — `pick-up` cannot run standalone. |
| Web sources | **≤3 per topic, active search** | `/pick-up 1,3` ⇒ up to 3 × 2 = 6 total. Degrades gracefully offline. |
| Card grounding | **Vault-grounded + active web search** | Reuse v1 `/digest` convention via `CLAUDE_SESSION_LEARNER_ZK_PATH`. Both degrade gracefully. |
| Card size | **≤50 lines, one concept per card** | Hard rule. A topic with multiple concepts splits into multiple cards. |
| `pick-up` gate | **No confirmation gate** | Topics are already user-chosen; resolve numbers → cards directly. |
| README diagram | **Spec only; README gets prose** | README is generated and has no diagram slot; no generator changes. |

## Funnel

```
                    ┌──────────────────────────────────────┐
                    │  you develop / diagnose / debug /      │
                    │  root-cause / build a feature          │
                    └────────────────────┬───────────────────┘
                                         │
                                         ▼
                        /session-learner:wrap-up          ── DIVERGE
                    ┌──────────────────────────────────────┐
                    │  Watch-outs this session (pitfalls)    │
                    │  Candidate take-away topics  1 … N      │
                    └───────┬────────────────────────┬───────┘
              know which to │                         │ can't choose one?
                keep        │                         │
                            ▼                         ▼
                   /pick-up 1,3              /session-learner:recommend   ── CONVERGE
          ┌────────────────────────────┐   ┌──────────────────────────┐
          │  atomic Zettelkasten cards  │   │  exactly ONE topic         │
          │   • 1 concept per card      │   │  + why it's the one to keep│
          │   • ≤ 50 lines each         │   └─────────────┬──────────────┘
          │   • this session's case     │                 │ then deepen the winner
          │   • ≤ 3 web sources / topic  │◄────────────────┘
          │   • vault-grounded [[links]] │
          └────────────────────────────┘    ── DEEPEN
```

## Architecture & file layout

```
session-learner/  (v2.0.0)
├── .claude-plugin/plugin.json          # version 2.0.0, description rewritten
├── README.md                            # GENERATED — funnel described in prose
└── skills/
    ├── wrap-up/SKILL.md                  # reflect → watch-outs + N candidate topics + funnel hint
    ├── pick-up/
    │   ├── SKILL.md                      # topic number(s) → atomic cards (workflow)
    │   └── references/card-format.md     # card template, ≤50-line/atomic rules, vault grounding, web-search protocol
    └── recommend/SKILL.md                # the N topics → pick exactly ONE + reasoning

REMOVED: commands/, hooks/, lib/
```

Each skill is independently understandable: `wrap-up` reflects and lists,
`pick-up` deepens chosen topics into cards, `recommend` picks one. They
communicate only through the conversation transcript (no shared files).

## Skill: `wrap-up`

- **Purpose:** diverge — reflect on the session and list candidate topics.
- **Invocation:** `/session-learner:wrap-up` (also model-invocable). No args.
- **Inputs:** the live conversation; may `Read`/`Grep` referenced files to make
  watch-outs concrete. **Tools:** `Read`, `Grep`, `Glob`.
- **Output (terminal only):**

```
🧭 Session Wrap-Up

## Watch-outs this session
- <a pitfall hit, a footgun, a fragile assumption, or a non-obvious thing worth
  remembering — specific to what happened>
  (1–4 items; concrete, reference real moments; skip generic advice)

## Candidate take-away topics
1. <Topic title> — <one line: why it's worth keeping>
2. <Topic title> — …
   (2–6 atomic, reusable topics drawn from the session)

---
Next:
  /session-learner:pick-up <n[,n…]>   → turn topic(s) into atomic Zettelkasten cards
  /session-learner:recommend           → not sure which? I'll pick the single best one and tell you why
```

- **Rules:** topics are **numbered** (downstream skills reference them by index);
  watch-outs must trace to real session moments, not generic tips.
- **Empty/trivial session:** print `Not much to wrap up yet — no substantial work
  this session.` and stop (no topic list).

## Skill: `pick-up`

- **Purpose:** deepen — turn topic number(s) into atomic Zettelkasten cards.
- **Tools:** `Read`, `Glob`, `WebSearch`, `WebFetch`.
- **Invocation & topic resolution:**

| Invocation | Resolves to |
|---|---|
| `/pick-up 1,3` | topics 1 & 3 from the last `wrap-up` in the conversation |
| `/pick-up` (no indices) | **error** → `Provide topic numbers, e.g. /pick-up 1,3. Run /wrap-up first if you haven't.` |
| indices given but **no `wrap-up`** in context | ask → `Run /session-learner:wrap-up first so I have numbered topics.` |
| out-of-range index (`pick-up 9` of 5) | use valid ones, note the invalid |

No ad-hoc free-text topics. No no-arg "all" mode. `pick-up` is strictly
downstream of `wrap-up`.

- **Workflow (SKILL.md, short — detail in `references/card-format.md`):**
  1. Resolve topic number(s) per the table above.
  2. For each topic, pull the **concrete session case** — what actually happened
     here that surfaced it.
  3. **Web-search ≤3 supporting sources** for that topic; `WebFetch` to confirm
     relevance; keep the ≤3 most relevant. ≤3 **per topic** → up to 3 × N total.
  4. **Vault grounding** via `CLAUDE_SESSION_LEARNER_ZK_PATH` — `Glob`
     `Permanent/*.md` filenames (names only) to reuse existing titles for
     `[[links]]` and match the tag taxonomy.
  5. Emit atomic cards: **one concept per card, ≤50 lines each.** Split a
     multi-concept topic into multiple cards. A topic's ≤3 sources are shared
     across its cards.

- **Card template** (`references/card-format.md`):

```markdown
#domain/<area> #domain/<subarea>

## <Concise, specific, searchable title>

<body — the single concept, tight: bullets / one short code block / a small table>

**From this session:** <1–2 lines — the concrete case that surfaced this>

Related: [[Existing Vault Card]], [[Another Topic]]
Sources: <url1>, <url2>            ← ≤3; omit line if none found
```

- **Graceful degradation:**
  - No web results / no network → cards cite the session case only; append
    `⚠ No web sources found — cards cite the session case only.`
  - Vault missing → `[[links]]` are AI-proposed; append `⚠ Vault not found —
    links are proposed, not grounded.`
- **No file writes**, ever — terminal copy-paste only. No confirmation gate.

## Skill: `recommend`

- **Purpose:** converge — pick exactly one topic to keep, with reasoning.
- **Invocation:** `/session-learner:recommend` — no args; reads the topics from
  the last `wrap-up` in the conversation. **Tools:** `Read`, `Grep`, `Glob`.
- **Selection criteria** (ranks the candidate topics): **reusability** (applies
  across projects), **cost of the lesson** (pain caused / prevented),
  **recurrence** (how often it recurs), **non-obviousness** (worth recording).
- **Output (terminal only):**

```
🎯 Recommended take-away

Topic 3 — <title>

Why this one:
  • <strongest reason: leverage / reusability / cost-of-not-knowing>
  • <why it beats the runners-up, named briefly>

---
Deepen it →  /session-learner:pick-up 3
```

- **Edge cases:** no `wrap-up` in context → ask to run `/wrap-up` first and stop;
  only one candidate → recommend it, noting it was the only one.
- Does **not** generate cards (that stays `pick-up`'s single responsibility).

## Packaging, versioning & docs

**Hand-edited files:**
1. `session-learner/.claude-plugin/plugin.json` → `version: "2.0.0"`; description
   rewritten (drop hooks / git-aware injection / take-away; describe the funnel).
2. `.claude-plugin/marketplace.json` → session-learner entry: `version: "2.0.0"`
   + matching description.
3. `content/plugins.content.json` → session-learner: new `tagline` + `summary`
   (mentions the funnel in prose); **`config` trimmed to only
   `CLAUDE_SESSION_LEARNER_ZK_PATH`** (remove `GIT_MODE` + `MAX_AGE_DAYS`, now
   dead); `category` stays `memory`.
4. The 3 `SKILL.md` files — each with `name` + a first-sentence `description`
   (≤140 chars, written for good triggering, third person).

**Generated files (never hand-edited — produced by `./scripts/cicd.sh GEN`):**
`session-learner/README.md`, `CATALOG.md`, `site/data/plugins.json` + stamped
HTML. `generate-docs.mjs` already discovers `skills/<dir>/SKILL.md`.

**Verification:** `./scripts/cicd.sh CHECK` (CI + `.githooks/pre-commit`) must
pass — confirms generated docs are in sync with the new skills.

## Config surface (after v2.0.0)

| Variable | Default | Used by |
|---|---|---|
| `CLAUDE_SESSION_LEARNER_ZK_PATH` | `~/…/LifeOS/03-Resource/Zettelkasten/Permanent` | `pick-up` vault grounding |

`CLAUDE_SESSION_LEARNER_GIT_MODE` and `CLAUDE_SESSION_LEARNER_MAX_AGE_DAYS` are
removed (their only consumers were the deleted hooks).

## Out of scope

- Cross-session memory / persistence (removed with the hooks).
- File writing by any skill (all output is terminal copy-paste).
- Generator/template changes (README diagram stays in this spec only).
- Migrating v1 `/digest`'s file/URL ingestion — `pick-up` sources from the
  session, not arbitrary files.
```

