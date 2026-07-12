# humanize Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a new `humanize` plugin with two skills — `distill` (writing samples → reusable tone preset) and `rewrite` (humanize existing text, meaning preserved) — for zh-TW and English, and wire it into the marketplace + generated docs.

**Architecture:** Two thin skills over three shared `references/` knowledge files and a `presets/` folder. A tone preset is just a markdown file; a personal voice is a distilled preset. `$HUMANIZE_TONE_DIR` overrides built-in presets by name. No from-scratch generation — `rewrite` only reshapes existing material.

**Tech Stack:** Claude Code plugin (markdown skills + references, JSON manifests), Bash conformance test, Node-based doc generator (`scripts/cicd.sh`).

Spec: `docs/superpowers/specs/2026-07-13-humanize-plugin-design.md`. Branch: `feat/humanize-plugin` (already created).

## Global Constraints

- **Version:** ship at `0.1.0`, identical in `.claude-plugin/marketplace.json` and `humanize/.claude-plugin/plugin.json`.
- **Bundled file refs:** skills reference their own bundled files via `${CLAUDE_PLUGIN_ROOT}` only. Never `find ~/.claude/plugins`. Never reference another plugin's files/agents/skills.
- **Generated docs:** `CATALOG.md`, `humanize/README.md`, `site/data/plugins.json` are generated. Never hand-edit — run `./scripts/cicd.sh GEN`. `Edit`/`Write` on those paths is mechanically denied.
- **Lockstep:** every `marketplace.json` plugin needs a matching `content/plugins.content.json` entry or GEN throws.
- **Rewrite invariants (baked into skill + tests):** never invent facts; preserve original meaning; English output contains **zero** em/en dashes (`—` `–` `--`); zh-TW is a separate ruleset from zh-CN (Simplified is never treated as native TW).

---

### Task 1: Scaffold the plugin

**Files:**
- Create: `humanize/.claude-plugin/plugin.json`
- Create (empty dirs via the files below): `humanize/skills/`, `humanize/references/`, `humanize/presets/`, `humanize/tests/fixtures/`

**Interfaces:**
- Produces: the `humanize/` plugin root with a valid `plugin.json` (name `humanize`, version `0.1.0`). Later tasks add skills/references/presets under it.

- [ ] **Step 1: Create `humanize/.claude-plugin/plugin.json`**

```json
{
  "name": "humanize",
  "description": "Distill your writing voice into reusable tone presets and rewrite existing text to sound human (not AI) in zh-TW or English — meaning always preserved.",
  "version": "0.1.0",
  "author": {
    "name": "William Hung"
  }
}
```

- [ ] **Step 2: Verify it is valid JSON**

Run: `jq . humanize/.claude-plugin/plugin.json`
Expected: pretty-printed JSON, exit 0.

- [ ] **Step 3: Commit**

```bash
git add humanize/.claude-plugin/plugin.json
git commit -m "feat(humanize): scaffold plugin manifest"
```

---

### Task 2: Shared reference — `safety-rails.md`

**Files:**
- Create: `humanize/references/safety-rails.md`

**Interfaces:**
- Produces: the arbitration order both skills cite. `rewrite` and `distill` `SKILL.md` will say "obey `${CLAUDE_PLUGIN_ROOT}/references/safety-rails.md`".

- [ ] **Step 1: Write `humanize/references/safety-rails.md`**

```markdown
# Safety rails (read before every rewrite or distill)

Apply these in order. A higher rule always wins a conflict with a lower one.

1. **Never invent facts.** Every number, name, quote, and claim in the output
   must trace to the source or the user. If a fact is missing, leave a
   `[needs author input: …]` marker — do not fabricate.
2. **Human-detection gate.** If the input already reads as genuinely
   human-written — self-corrections mid-sentence, dated slang / in-jokes,
   dialect markers, a specific personal anecdote, a recognizable individual
   voice — STOP. Only fix mechanical formatting (typos, punctuation). Do not
   rewrite the voice. Say why you stopped.
3. **Density, not presence.** One em-dash, one "however", one 排比 / rule-of-three
   is never a tell. Flag only clustered, context-free repetition (roughly 3+ of
   the same device in a short span with no logical need).
4. **Keep one rough edge.** The output must retain at least one subjective
   judgment or concrete specific — never sand text into something sterile and
   generic.
5. **Preserve meaning.** Tone, rhythm, and word choice may change; the meaning
   must not. If a proposed change alters meaning, drop it.

## Protected — never alter
Prices, numbers, dates, proper nouns, real names, quoted speech, URLs (but strip
`utm_source=chatgpt.com`-style tracking), and legal / refund clauses.
```

- [ ] **Step 2: Verify the file exists and has the 5 rules**

Run: `grep -cE "^[0-9]\. \*\*" humanize/references/safety-rails.md`
Expected: `5`

- [ ] **Step 3: Commit**

```bash
git add humanize/references/safety-rails.md
git commit -m "feat(humanize): add safety-rails reference"
```

---

### Task 3: Shared reference — `ai-tells-en.md`

**Files:**
- Create: `humanize/references/ai-tells-en.md`

**Interfaces:**
- Produces: the English AI-tell catalogue. `rewrite` cites it for English input. The conformance test (Task 8) asserts the zero-em-dash rule stated here.

- [ ] **Step 1: Write `humanize/references/ai-tells-en.md`**

```markdown
# AI-tells — English

Source lineage: blader/humanizer (33-pattern catalogue). Apply with
`safety-rails.md` — flag clusters, not isolated hits.

## Hard constraint
- **Zero em/en dashes in output.** Remove every `—`, `–`, spaced ` — `, and
  double-hyphen `--`. Replacement priority: period > comma > colon > parentheses
  > restructure. Before delivering, scan the text for `—` and `–`; any hit means
  it is not done.

## Word / phrase tells (cut or replace with the concrete thing)
- **AI vocabulary:** delve, crucial, pivotal, tapestry, testament, underscore,
  showcase, intricate/intricacies, garner, fostering, vibrant, landscape
  (abstract), interplay, align with, key (as adjective), enduring, valuable.
- **Significance inflation:** "stands/serves as a testament", "marks a pivotal
  moment", "underscores/highlights the importance of", "plays a vital role",
  "evolving landscape", "leaves an indelible mark", "deeply rooted". → replace
  with the concrete fact (a number, date, name) or delete.
- **Promotional / brochure:** nestled, in the heart of, breathtaking, must-visit,
  boasts a, renowned, rich cultural heritage, groundbreaking, stunning.
- **Copula avoidance:** "serves as / stands as / represents a" → just "is / are".
- **Signposting:** "let's dive in", "here's what you need to know", "without
  further ado", "let's break this down". → just start.
- **Fake-candor openers** used as standalone theatrical pauses: "Honestly?",
  "Look,", "Here's the thing", "Let's be honest", "Real talk".
- **Chatbot residue:** "I hope this helps", "Of course!", "Would you like me
  to…", "Let me know if…", "Here is a…".
- **Knowledge-gap filler dressed as fact:** "it is believed that", "maintains a
  low profile". → say "not documented" or cut.
- **Filler → tighter:** "in order to" → "to"; "due to the fact that" → "because";
  "at this point in time" → "now"; "it is important to note that" → (delete).

## Structure tells
- **Rule of three** forced onto every idea. Let lists be 2 or 4 when logic says so.
- **Negative parallelism** ("not only X but Y", "it's not just X, it's Y") — legit
  once; cap at one per piece.
- **Hyphenation:** hyphenate only attributively. "a high-quality report" keeps the
  hyphen; "the report is high quality" drops it. AI hyphenates uniformly everywhere.
- **Even cadence:** vary sentence length deliberately — short punchy next to long.

## False-positive guard (do NOT flag these alone)
Perfect grammar; formal vocabulary alone; one isolated "however"/"moreover"; curly
quotes (editors auto-curl); one em-dash in an otherwise human piece; one short
emphatic sentence; an unsourced claim on its own. Only a *cluster* of tells is
evidence.

## Human signals to preserve
Hard-to-fabricate specifics; mixed / unresolved feelings ("I think this is mostly
good but something bugs me"); self-corrections and mid-thought parentheticals;
uneven sentence variety.
```

- [ ] **Step 2: Verify the hard constraint and word list are present**

Run: `grep -qi "Zero em/en dashes" humanize/references/ai-tells-en.md && grep -qi "delve" humanize/references/ai-tells-en.md && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add humanize/references/ai-tells-en.md
git commit -m "feat(humanize): add English AI-tells reference"
```

---

### Task 4: Shared reference — `ai-tells-zhtw.md`

**Files:**
- Create: `humanize/references/ai-tells-zhtw.md`

**Interfaces:**
- Produces: the zh-TW AI-tell + localization catalogue. `rewrite` cites it for Traditional-Chinese input. The conformance test (Task 8) asserts the Mainland-vocab swap and full-width punctuation stated here.

- [ ] **Step 1: Write `humanize/references/ai-tells-zhtw.md`**

```markdown
# AI-tells — 繁體中文（台灣）

Source lineage: Raymondhou0917/speak-human-tw. Separate ruleset from Simplified
Chinese. Apply with `safety-rails.md` — 看密度，不看出現 (judge by density, not
presence).

## 大陸用語 → 台灣用語（對外文字零容忍）
視頻→影片、質量→品質、信息→資訊、網絡→網路、軟件/硬件→軟體/硬體、
服務器→伺服器、屏幕→螢幕、鼠標→滑鼠、打印→列印、智能→智慧、
短視頻→短影音、水平→水準、性價比→CP值、默認→預設、支持→支援、
兼容→相容、反饋→回饋、博主→創作者、立馬→馬上、靠譜→可靠。

無法直接換字、需整句改寫的（說出「誰能做到什麼」）：賦能、抓手、閉環、落地。
情境相依（有具體數據時可保留）：優化、文檔。

## 標點（繁中句子一律全形）
- 全形：，。：；！？「」『』（）。半形只用於英文詞、網址、程式碼；數字保持半形
  （4,800元、42%）。
- 引號：第一層「」、巢狀『』。不要簡體彎引號 " " 或半形 "。
- 刪節號用「⋯⋯」或「……」，不要「...」。並列項目用頓號「、」，不要逗號。

## 內容 / 語句 tells
- **立場真空**（最高優先）：各有優缺點、因人而異、取決於多方面的因素、見仁見智。
  → 給出真實判斷，否則整句刪掉。
- **否定平行**：不是A而是B、不僅⋯更⋯。合法但別重複，一篇最多一次。
- **假坦白鉤子**：說真的、老實說 當開場停頓 → 假人味，刪。
- **三段式對稱**：首先／其次／最後，「每點長度整齊得像切過的吐司」。結構跟邏輯走，
  可以 2 點或 4 點。
- **誇大意義**：標誌著、見證了、體現了⋯的重要性、奠定基礎、里程碑 → 換成具體事實或刪。
- **破折號密度**：每 300–500 字最多一個，同段不要出現兩次。

## AI 工具殘留（發佈前務必清掉）
`utm_source=chatgpt.com`、`turn0search0` 之類引用碼、「以下是清理後的版本，請複製使用」。

## 語氣與量詞
- 語助詞（喔、耶、啦、欸、齁）限社群語域；移除大陸腔「好噠、是滴」。
- 量詞要對：一部影片（非一個視頻）、一支手機、一則貼文。

## 保留的人味
允許立場隨時間改變（「我以前很討厭⋯後來發現我錯了」），允許不硬做結論
（不用每篇都「總的來說」）。單一次排比／成語是正常中文，不是 tell。
```

- [ ] **Step 2: Verify the vocab swap and punctuation rule are present**

Run: `grep -q "視頻→影片" humanize/references/ai-tells-zhtw.md && grep -q "立場真空" humanize/references/ai-tells-zhtw.md && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add humanize/references/ai-tells-zhtw.md
git commit -m "feat(humanize): add zh-TW AI-tells reference"
```

---

### Task 5: Built-in tone presets

**Files:**
- Create: `humanize/presets/blog.md`
- Create: `humanize/presets/pr-candid.md`
- Create: `humanize/presets/social.md`

**Interfaces:**
- Produces: three default presets. `rewrite`/`distill` resolve a preset by name: `$HUMANIZE_TONE_DIR/<name>.md` first, else `${CLAUDE_PLUGIN_ROOT}/presets/<name>.md`. The frontmatter schema (`name`, `language`) is what `distill` (Task 7) emits.

- [ ] **Step 1: Create `humanize/presets/blog.md`**

```markdown
---
name: blog
language: auto
---
# blog
- **Voice:** a person thinking out loud, not a brand explaining itself.
- **Diction:** plain verbs; ban the AI-vocabulary list; contractions welcome.
- **Rhythm:** vary sentence length; let one paragraph run long, the next be two words.
- **Quirks:** a real opinion up front; allow a tangent; fine to end without a bow.
- **Do:** react to the facts, cite a specific. **Don't:** rule-of-three everything.
```

- [ ] **Step 2: Create `humanize/presets/pr-candid.md`**

```markdown
---
name: pr-candid
language: auto
---
# pr-candid
- **Voice:** a teammate giving honest, kind, direct code-review feedback.
- **Diction:** concrete ("this N+1 query" not "potential performance concerns");
  no hedging pile-ups ("it might possibly be worth perhaps").
- **Rhythm:** short. One point per comment. Lead with the ask.
- **Quirks:** say "I'd" and "you" — it's a conversation, not a verdict.
- **Do:** state the why. **Don't:** soften a real problem into a stance vacuum.
```

- [ ] **Step 3: Create `humanize/presets/social.md`**

```markdown
---
name: social
language: auto
---
# social
- **Voice:** casual, quick, a bit playful.
- **Diction:** fragments fine; tone particles fine in zh-TW (喔/啦/欸) — sparingly.
- **Rhythm:** front-load the point; cut the wind-up.
- **Quirks:** one idea per post; no "let's dive in"; no fake-candor opener.
- **Do:** sound like a text to a friend. **Don't:** thread three hashtagged clichés.
```

- [ ] **Step 4: Verify all three parse as having frontmatter**

Run: `for f in blog pr-candid social; do head -1 "humanize/presets/$f.md" | grep -q '^---$' && echo "$f OK"; done`
Expected: `blog OK`, `pr-candid OK`, `social OK`

- [ ] **Step 5: Commit**

```bash
git add humanize/presets/
git commit -m "feat(humanize): add built-in tone presets"
```

---

### Task 6: `rewrite` skill

**Files:**
- Create: `humanize/skills/rewrite/SKILL.md`

**Interfaces:**
- Consumes: `${CLAUDE_PLUGIN_ROOT}/references/{safety-rails,ai-tells-en,ai-tells-zhtw}.md`; presets resolved via `$HUMANIZE_TONE_DIR` then `${CLAUDE_PLUGIN_ROOT}/presets/`.
- Produces: the `humanize:rewrite` skill with two modes (transform, `--flag-only`).

- [ ] **Step 1: Write `humanize/skills/rewrite/SKILL.md`**

````markdown
---
name: rewrite
description: Use to humanize / de-AI existing text — PR review comments, posts, emails, docs — in Traditional Chinese (zh-TW) or English, preserving meaning. Triggers on "humanize this", "make this sound less like AI / ChatGPT", "去AI味", "rewrite my PR comment to sound human", or "check my draft for AI-tells" (flag-only).
---

# Rewrite (humanize existing text)

Reshape existing text so it reads like a person wrote it, without changing what
it says. This does NOT generate new content — it only rewrites material you give it.

## Before anything, obey the safety rails
Read `${CLAUDE_PLUGIN_ROOT}/references/safety-rails.md` and apply it in order.
If the human-detection gate trips (input is already genuinely human), STOP,
clean only formatting, and say why.

## 1. Detect language
- Traditional-CJK characters → use `${CLAUDE_PLUGIN_ROOT}/references/ai-tells-zhtw.md`.
- Latin script → use `${CLAUDE_PLUGIN_ROOT}/references/ai-tells-en.md`.
- Mixed → apply both to their respective spans.
- **Simplified Chinese detected** → warn: this ruleset targets Traditional
  Chinese (Taiwan); offer to run the TW-localization pass (vocab swap +
  punctuation) rather than treating it as native. Do not silently proceed.
- An explicit target language in the request overrides detection.

## 2. Resolve tone
Preset name given? Resolve `$HUMANIZE_TONE_DIR/<name>.md` first, else
`${CLAUDE_PLUGIN_ROOT}/presets/<name>.md`. No name, or no match → fall back to
the built-in default for the detected language and say which preset you used.

## 3. Mode
- **Default (transform):** rewrite to remove the clustered AI-tells from the
  language reference and match the tone. Preserve meaning; keep one rough edge;
  English output must contain zero em/en dashes.
- **`--flag-only` (audit):** do NOT edit. List each tell found as
  `original / why it's a tell / suggested fix`, then give a /50 score across
  directness, rhythm, trust, authenticity, concision (<35 = rewrite, 45+ = ship).

## 4. Delivering
- **Pasted text** → output the rewrite inline in the terminal. No file write.
- **A file** (transform mode) → first list the numbered edits
  (`original / why / suggested`) and ASK "Which of these N do you want applied?".
  WAIT for the reply. Only then edit the file, applying only approved edits.

## Output (transform mode)
Show, in order: the rewrite; then a short "changed:" list (what you cut and why).
For English, confirm "0 em-dashes" in the changed list.
````

- [ ] **Step 2: Verify frontmatter and `${CLAUDE_PLUGIN_ROOT}` usage; no cross-plugin refs**

Run:
```bash
head -3 humanize/skills/rewrite/SKILL.md | grep -q '^name: rewrite$' \
 && grep -q '${CLAUDE_PLUGIN_ROOT}/references/safety-rails.md' humanize/skills/rewrite/SKILL.md \
 && ! grep -q 'find ~/.claude/plugins' humanize/skills/rewrite/SKILL.md \
 && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add humanize/skills/rewrite/SKILL.md
git commit -m "feat(humanize): add rewrite skill"
```

---

### Task 7: `distill` skill

**Files:**
- Create: `humanize/skills/distill/SKILL.md`

**Interfaces:**
- Consumes: user-supplied materials; writes to `$HUMANIZE_TONE_DIR`.
- Produces: the `humanize:distill` skill emitting a preset in the Task-5 schema (`name`, `language` frontmatter + Voice/Diction/Rhythm/Quirks/Do-Don't/Examples).

- [ ] **Step 1: Write `humanize/skills/distill/SKILL.md`**

````markdown
---
name: distill
description: Use to capture a writing voice into a reusable tone preset from samples or referenced materials. Triggers on "distill my voice / tone", "make a tone preset from these posts", or "capture the writing style of X". The preset it produces is consumed by humanize:rewrite.
---

# Distill (materials → tone preset)

Turn writing samples into a reusable tone preset file. This reads existing
material and describes its voice — it never invents a persona the samples don't show.

## 1. Gather materials
Accept file paths or a prompt naming specific materials (past posts, PRs, notes).
Read them with `Read`/`Glob`. If given nothing concrete, ask for at least one sample.

## 2. Extract the voice
Identify, grounded in the samples (quote where you can):
- **Voice** — the persona/register in one line.
- **Diction** — preferred words, banned words.
- **Rhythm** — sentence-length pattern, paragraph shape.
- **Quirks** — recurring habits to reproduce (or avoid).
- **Do / Don't** — short bullets.
- **Examples** — 1–2 verbatim lines from the samples that exemplify the voice.
- **Language** — `en`, `zh-TW`, or `auto` based on the samples.

## 3. Emit the preset
Format (must match what humanize:rewrite consumes):

```markdown
---
name: <kebab-name>
language: <en|zh-TW|auto>
---
# <name>
- **Voice:** …
- **Diction:** …
- **Rhythm:** …
- **Quirks:** …
- **Do / Don't:** …
- **Examples:** …
```

## 4. Write it
- `$HUMANIZE_TONE_DIR` set → write `$HUMANIZE_TONE_DIR/<name>.md`. If that file
  already exists, show the diff and ASK before overwriting.
- `$HUMANIZE_TONE_DIR` unset → print the preset to the terminal and tell the user
  to set `HUMANIZE_TONE_DIR` (a folder of their tone presets) then re-run, or save
  it manually. Do not guess a location.
````

- [ ] **Step 2: Verify frontmatter, env-var handling, no cross-plugin refs**

Run:
```bash
head -3 humanize/skills/distill/SKILL.md | grep -q '^name: distill$' \
 && grep -q 'HUMANIZE_TONE_DIR' humanize/skills/distill/SKILL.md \
 && ! grep -q 'find ~/.claude/plugins' humanize/skills/distill/SKILL.md \
 && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add humanize/skills/distill/SKILL.md
git commit -m "feat(humanize): add distill skill"
```

---

### Task 8: Golden fixtures + conformance test

**Files:**
- Create: `humanize/tests/fixtures/en-after.md`
- Create: `humanize/tests/fixtures/zhtw-after.md`
- Create: `humanize/tests/test_humanize_conformance.sh`

**Interfaces:**
- Consumes: the invariants stated in `ai-tells-en.md` (zero em-dash) and `ai-tells-zhtw.md` (no Mainland vocab, full-width punctuation).
- Produces: one runnable regression check. (Note: `./scripts/cicd.sh` runs only the generator's own tests, so this script is run directly.)

- [ ] **Step 1: Create the English "after" fixture `humanize/tests/fixtures/en-after.md`**

A short humanized English sample that MUST contain zero em/en dashes and none of
the banned AI-vocabulary words:

```markdown
I rewrote the auth handler last night. It works now, but I'm not thrilled with it.

The retry logic is fine. The error messages still lump three failure modes into one
500, so on-call has to guess. I'll split those next.
```

- [ ] **Step 2: Create the zh-TW "after" fixture `humanize/tests/fixtures/zhtw-after.md`**

A short humanized Traditional-Chinese sample using Taiwan vocabulary and full-width
punctuation, containing none of the Mainland tells:

```markdown
昨晚把登入的程式改完了，能動，可是我不太滿意。

重試那段沒問題。錯誤訊息還是把三種失敗擠成同一個 500，值班的人只能用猜的。下一步先把它們拆開。
```

- [ ] **Step 3: Write `humanize/tests/test_humanize_conformance.sh`**

```bash
#!/usr/bin/env bash
# Regression check for humanize's core output invariants:
#   - English output contains zero em/en dashes.
#   - zh-TW output uses no Mainland-vocab tells and no half-width sentence commas.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
EN="${DIR}/fixtures/en-after.md"
ZH="${DIR}/fixtures/zhtw-after.md"

PASS=0; FAIL=0
assert() {
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}

# English: no em-dash (—), en-dash (–), or double-hyphen (--)
assert "en-after has no em/en dash"      "! grep -qE '—|–|--' '${EN}'"

# zh-TW: none of a small set of Mainland-vocab tells
assert "zhtw-after has no Mainland vocab" "! grep -qE '視頻|質量|信息|網絡|屏幕|智能|默認' '${ZH}'"

# zh-TW: uses full-width comma somewhere (sanity that punctuation is Chinese-style)
assert "zhtw-after uses full-width comma" "grep -q '，' '${ZH}'"

echo ""
echo "Passed: ${PASS}  Failed: ${FAIL}"
[ "${FAIL}" -eq 0 ]
```

- [ ] **Step 4: Make it executable and run it**

Run:
```bash
chmod +x humanize/tests/test_humanize_conformance.sh
bash humanize/tests/test_humanize_conformance.sh
```
Expected: three `PASS` lines, `Passed: 3  Failed: 0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add humanize/tests/
git commit -m "test(humanize): add conformance fixtures and check"
```

---

### Task 9: Wire into marketplace + generated docs

**Files:**
- Modify: `.claude-plugin/marketplace.json` (add `humanize` to `plugins[]`)
- Modify: `content/plugins.content.json` (add `content` category + `humanize` entry)
- Modify: `site/assets/app.js` (add `content` to `CAT_COLOR` and `CAT_ICON`)
- Modify: `site/assets/styles.css:49` area (add `--cat-content`)
- Generated (do NOT hand-edit; produced by GEN): `CATALOG.md`, `humanize/README.md`, `site/data/plugins.json`

**Interfaces:**
- Consumes: the plugin built in Tasks 1–8.
- Produces: a fully-registered, GEN-clean plugin. `./scripts/cicd.sh VERIFY` passes.

- [ ] **Step 1: Add the plugin to `.claude-plugin/marketplace.json`**

Append this object to the `plugins` array (after the `uiux-optimizer` entry):

```json
    {
      "name": "humanize",
      "source": "./humanize",
      "description": "Distill your writing voice into reusable tone presets and rewrite existing text to sound human (not AI) in zh-TW or English — meaning always preserved.",
      "version": "0.1.0",
      "strict": true
    }
```

- [ ] **Step 2: Add the category and plugin entry to `content/plugins.content.json`**

In `categories`, append:

```json
    { "id": "content", "label": "Writing & Content" }
```

In `plugins`, append:

```json
    "humanize": {
      "tagline": "Sound like a person, in zh-TW or English",
      "summary": "Two skills. distill captures your voice from writing samples into a reusable tone preset; rewrite strips AI-tells from existing text (PR comments, posts, emails) and matches a tone, preserving meaning and never inventing facts. Separate Traditional-Chinese and English rulesets, auto-detected, plus a flag-only audit mode.",
      "category": "content",
      "dependsOn": [],
      "config": [
        { "name": "HUMANIZE_TONE_DIR", "default": "—", "description": "Folder of your own tone preset .md files. Overrides the built-in presets by name, and is where `distill` writes new presets." }
      ]
    }
```

- [ ] **Step 3: Add the `content` category color + icon in `site/assets/app.js`**

In `CAT_COLOR` (after the `media` line), add:

```js
  content: "var(--cat-content)",
```

In `CAT_ICON` (after the `media` glyph), add a 1.5px-stroke pen glyph:

```js
  content: `<svg viewBox="0 0 16 16"><path d="M10.5 2.5l3 3-7.5 7.5-3.5 1 1-3.5z"/><line x1="8.5" y1="4.5" x2="11.5" y2="7.5"/></svg>`,
```

- [ ] **Step 4: Add the `--cat-content` CSS variable in `site/assets/styles.css`**

After the `--cat-media:` line (around line 49), add a distinct hue (green/teal, unlike the existing blue/pink set):

```css
  --cat-content: #4fbf9a;
```

- [ ] **Step 5: Regenerate docs**

Run: `./scripts/cicd.sh GEN`
Expected: exit 0; `CATALOG.md`, `humanize/README.md`, and `site/data/plugins.json` now include humanize. (If GEN throws a lockstep error, a name in marketplace.json and content/plugins.content.json disagree — fix and re-run.)

- [ ] **Step 6: Run the full CI gate**

Run: `./scripts/cicd.sh VERIFY`
Expected: generator unit tests pass and the `--check` doc-sync check passes (exit 0).

- [ ] **Step 7: Run the plugin conformance check once more**

Run: `bash humanize/tests/test_humanize_conformance.sh`
Expected: `Passed: 3  Failed: 0`.

- [ ] **Step 8: Commit (including regenerated docs)**

```bash
git add .claude-plugin/marketplace.json content/plugins.content.json \
        site/assets/app.js site/assets/styles.css \
        CATALOG.md humanize/README.md site/data/plugins.json
git commit -m "feat(humanize): register plugin and regenerate docs"
```

---

## Self-Review

**Spec coverage:**
- Two skills distill + rewrite → Tasks 6, 7. ✓
- rewrite meaning-preserving + flag-only audit → Task 6 modes. ✓
- distill → preset file, `$HUMANIZE_TONE_DIR`, no silent overwrite → Task 7. ✓
- Shared references (en, zh-TW, safety-rails) → Tasks 2, 3, 4. ✓
- Presets + env-var override → Task 5 + resolution in Tasks 6/7. ✓
- zh-TW ≠ zh-CN, auto-detect, Simplified warning → Task 6 step 1. ✓
- Safety rails (never-invent → human-gate → density → rough-edge → meaning) → Task 2. ✓
- Zero-em-dash + FP guard → Task 3 + Task 8 test. ✓
- Tests (1 EN + 1 zh-TW fixture, one conformance check) → Task 8. ✓
- Docs wiring + new `content` category (json + app.js + styles.css) → Task 9. ✓
- Version 0.1.0 in both manifests → Task 1 + Task 9 step 1. ✓

**Placeholder scan:** every file's full content is inline; no TBD/TODO. ✓

**Type/name consistency:** preset schema (`name`, `language` frontmatter) identical in Task 5, Task 7 emit, and Task 6 resolution. Reference paths use `${CLAUDE_PLUGIN_ROOT}/references/<name>.md` consistently. Category id `content` identical across content json, app.js, styles.css. ✓

No gaps found.
