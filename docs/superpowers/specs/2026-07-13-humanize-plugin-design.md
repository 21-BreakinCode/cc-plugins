# humanize — plugin design

**Date:** 2026-07-13
**Status:** Approved (brainstorming), pending implementation plan
**Marketplace:** `21-breakincode` (`21-BreakinCode/cc-plugins`)

## Summary

A two-skill Claude Code plugin that helps write in a natural, human voice rather
than an obviously-AI one, in **Traditional Chinese (zh-TW)** and **English**:

- **`distill`** — capture a voice from writing samples/materials into a reusable
  tone preset file.
- **`rewrite`** — rewrite existing text to sound human (strip AI-tells, match a
  tone), **preserving the original meaning** and never inventing facts. Includes
  a flag-only audit mode.

Generation-from-scratch is explicitly **out of scope** — `rewrite` only reshapes
material the user already has.

The two skills form a loop the ecosystem tools lack: distill your voice once from
your real writing, then every rewrite targets *your* voice, not a generic
"sounds human" default.

## Goals

1. Remove machine-sounding "AI-tells" from existing text on demand.
2. Support zh-TW and English with **separate** rulesets (they are not
   interchangeable — see Language Handling).
3. Let the user encode their own voice as a preset and reuse it everywhere.
4. Be safe on already-human text (a colleague's PR comment, a personal note):
   detect it and leave the voice alone.

## Non-goals

- No from-scratch content generation (no "write me a blog post about X").
- No zh-CN (Simplified) rewriting. If Simplified input appears, warn and offer a
  TW-localization pass rather than pretending it is native TW.
- No detection/scoring as a standalone product — audit is a mode of `rewrite`.

## Research basis

Concrete rules are distilled from established tools (researched 2026-07-13):

- **`blader/humanizer`** (English, 7.2k★) — 33 numbered AI-tell patterns,
  explicit AI-vocabulary word lists (delve, crucial, pivotal, tapestry,
  testament, underscore, showcase, intricate, vibrant, landscape…), a **hard
  zero-em-dash constraint**, and a **false-positive guard** ("judge by clusters,
  not isolated tells").
- **`Raymondhou0917/speak-human-tw`** (zh-TW) — 38 AI-trace categories, a
  Mainland→Taiwan vocabulary swap table (視頻→影片, 質量→品質, 智能→智慧,
  網絡→網路, 屏幕→螢幕, 短視頻→短影音, 性價比→CP值…), full-width punctuation +
  「」quote rules, tone particles (喔/啦/欸/齁), the "立場真空 / stance-vacuum"
  tell, and a **mandatory numbered-list confirmation before editing files**.
- **`LifelongLazyLearner/qu-ai-wei`** (zh-CN) — confirms zh-TW needs its own
  ruleset (it refuses Traditional input); contributes the arbitration-hierarchy
  and "density, not presence" ideas.

## Architecture

```
humanize/
  .claude-plugin/
    plugin.json                 # name, description, version 0.1.0 (== marketplace.json)
  skills/
    distill/SKILL.md
    rewrite/SKILL.md
  references/
    ai-tells-en.md              # English patterns, word lists, zero-em-dash, FP guard
    ai-tells-zhtw.md            # TW vocab table, punctuation, tone particles, tells
    safety-rails.md             # shared arbitration order (all skills read this)
  presets/
    blog.md                     # default tone presets shipped with the plugin
    pr-candid.md
    social.md
  tests/
    fixtures/                   # golden before/after (1 EN, 1 zh-TW)
    test_*.sh                   # one conformance check
  README.md                     # GENERATED — do not hand-edit
```

The skills are thin wrappers over shared knowledge in `references/`; they are not
three separate engines. A preset is just a markdown file — a personal voice is a
distilled preset, not a separate learning subsystem.

### Skill: `distill`

**Purpose:** turn writing samples / referenced materials into a reusable tone
preset file.

- **Input:** one or more files, or a prompt naming specific materials (past
  posts, PRs, notes).
- **Process:** read the materials, extract voice attributes — diction, sentence
  rhythm, recurring quirks, do/don't, language notes (zh-TW vs en), and 1–2
  verbatim example lines that exemplify the voice.
- **Output:** a tone preset `.md` (schema below).
- **Where it writes:** `$HUMANIZE_TONE_DIR` if set; otherwise it prints the
  preset to the terminal and tells the user to set `HUMANIZE_TONE_DIR`. It never
  silently overwrites an existing preset of the same name — it confirms first.
- **Trigger phrasing (description frontmatter):** "distill my voice / tone",
  "make a tone preset from these posts", "capture the writing style of X".

### Skill: `rewrite`

**Purpose:** humanize existing text. This is where PR review comments, posts,
emails, and other-platform text go.

- **Input:** source text (pasted or a file path) + optional tone preset name +
  optional target language.
- **Two modes:**
  - default — transform: strip AI-tells, match the chosen tone, **preserve
    meaning**.
  - `--flag-only` — audit: list the AI-tells found + a /50 quality score, change
    nothing.
- **Language:** auto-detect (Traditional-CJK → zh-TW rules; Latin → en; mixed →
  both). Explicit target overrides. Simplified input → warn + offer TW pass.
- **File edits:** when the source is a file and transform mode is chosen, list
  numbered edits (original / why / suggested fix) and **wait for the user's OK**
  before writing (speak-human-tw pattern). Pasted text is rewritten inline in the
  terminal with no file write.
- **Trigger phrasing:** "humanize this", "make this sound less like AI /
  ChatGPT", "去AI味", "rewrite my PR comment to sound human", "check my draft for
  AI-tells" (→ flag-only).

### Shared: `references/`

- **`ai-tells-en.md`** — the 33-pattern English catalogue condensed to the
  highest-impact rules: zero em/en dashes in output; the AI-vocabulary word list;
  significance-inflation phrases; promotional language; rule-of-three and
  negative-parallel caps; copula-avoidance → plain is/are; attributive-only
  hyphenation; signposting/meta-commentary removal; fake-candor opener distrust;
  chatbot-residue stripping; **the false-positive guard** (isolated tells are not
  evidence — only clusters are).
- **`ai-tells-zhtw.md`** — Mainland→TW vocabulary swap table; full-width
  punctuation mandatory (，。：；！？「」); 「」/『』 quotes; ⋯⋯ ellipsis and 、
  for parallel items; tone particles by register; the stance-vacuum tell
  (各有優缺點/因人而異 → take a real position or delete); cap 不是A而是B /
  首先-其次-最後; strip literal AI-tool residue (utm_source=chatgpt.com, turn0…);
  measure-word correctness (一部影片, 一支手機, 一則貼文).
- **`safety-rails.md`** — the arbitration order every skill obeys, highest
  priority first:
  1. **Never invent facts** — every number/name/claim in output traces to the
     source.
  2. **Human-detection gate** — if the input is already clearly human-written
     (self-corrections, dialect markers, recognizable personal voice), STOP; only
     clean formatting, do not touch the voice.
  3. **Density, not presence** — a device (one however, one em-dash, one 排比) is
     never a tell; only clustered, context-free repetition is.
  4. **Keep one rough edge** — output must retain at least one subjective
     judgment / concrete feeling; it must not become sterile.
  5. **Preserve meaning** — tone changes, meaning does not.

### Shared: `presets/` and `$HUMANIZE_TONE_DIR`

- Ships `blog.md`, `pr-candid.md`, `social.md` as defaults inside the plugin.
- `$HUMANIZE_TONE_DIR` (a user folder, possibly scoped per project/persona) takes
  precedence: a preset there overrides a built-in of the same name, so distilled
  personal voices win.
- `distill` writes new presets into `$HUMANIZE_TONE_DIR` when set.

**Preset file schema** (lightweight markdown):

```markdown
---
name: pr-candid
language: en            # en | zh-TW | auto
---
# <preset name>
- **Voice:** one-line description of the persona/register.
- **Diction:** preferred words / banned words.
- **Rhythm:** sentence-length pattern, paragraph shape.
- **Quirks:** recurring habits to reproduce (or avoid).
- **Do / Don't:** short bullet lists.
- **Examples:** 1–2 verbatim lines that exemplify the voice.
```

## Language handling

zh-TW and English are separate rulesets and never share a catalogue. Default is
auto-detect by script; explicit `--lang` (or equivalent) overrides. Simplified
Chinese is not a supported *output* — on Simplified input, `rewrite` warns and
offers to run the TW-localization pass (vocabulary swap + punctuation), so it is
never silently treated as native zh-TW.

## Error handling & boundaries

- **Empty / missing source** → early return with a clear message; no silent
  no-op.
- **No preset match** → fall back to the built-in default for the detected
  language and say so; never fail hard on a missing preset name.
- **File write conflicts** (distill preset already exists; rewrite on a file) →
  confirm before overwriting; never overwrite without acknowledgement.
- **Plugin boundaries** — `humanize` references only its own bundled files via
  `${CLAUDE_PLUGIN_ROOT}`; it does not source or depend on any other plugin.

## Testing

Following `session-learner`'s minimal approach:

- **Fixtures:** one English before/after and one zh-TW before/after in
  `tests/fixtures/`.
- **One conformance check** (`tests/test_*.sh`) asserting the invariants that
  matter: the English "after" contains zero em/en dashes; the zh-TW "after"
  contains none of a small set of Mainland-vocab tells and uses full-width
  punctuation. One runnable check that fails if the core logic regresses — not a
  per-rule suite.

## Docs & wiring (generated)

- Add a plugin entry to `.claude-plugin/marketplace.json` (version 0.1.0) and a
  prose entry to `content/plugins.content.json`, kept in lockstep.
- **New category `content` ("Writing & Content")** — none of the existing
  categories (memory / improve / review / workflow / media) fit writing. Costs
  one entry in `plugins.content.json` `categories[]` and one `CAT_ICON` mapping
  in `site/assets/app.js`.
- Run `./scripts/cicd.sh GEN` to regenerate `README.md`, `CATALOG.md`, and
  `site/*`. Never hand-edit generated docs.

## Versioning

New plugin ships at **0.1.0**, equal in `marketplace.json` and
`humanize/.claude-plugin/plugin.json`.

## Open questions

None blocking. The `content` category vs. reusing `review` was defaulted to a new
`content` category during brainstorming.
