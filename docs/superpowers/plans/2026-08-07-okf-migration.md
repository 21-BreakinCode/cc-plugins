# OKF Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate `code-reviewer` Code Review Principle bundles from role-major files (`01-07`) to OKF v0.2 concept-major bundles, gaining per-entry status/staleness/trust tiers, without losing the reviewer agent's priority-ordered consumption.

**Architecture:** Each mined entry becomes its own `.md` concept file with YAML frontmatter, grouped in role subdirs (`red-flags/`, `pitfalls/`, …). A rewritten `load-principle.sh` walks role dirs in priority order, skips `deprecated`, flags `[STALE]`, surfaces trust tier. A one-shot Python transform converts the 68 existing approved entries in the 14 live bundles. Docs + version bump complete the breaking change.

**Tech Stack:** Bash (reader + tests via `_assert.sh`), Python 3 (transform script), Markdown+YAML (concept format). No new dependencies.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-08-07-okf-migration-design.md` — authoritative.
- Plugin source root: `/Users/william.hung/Projects/PersonalPlugins/code-reviewer/`.
- Live data root: `$LIFEOS/01Project/Appier/CodeReviewPrinciple/<repo>/` where `LIFEOS=/Users/william.hung/Projects/LifeOS` (**must `export LIFEOS` — unset defaults to a nonexistent iCloud path**).
- Role → type → dir map (verbatim, used everywhere): `07-red-flags→RedFlag→red-flags/`, `02-pitfalls→Pitfall→pitfalls/`, `05-hotspots→Hotspot→hotspots/`, `04-domain-traps→DomainTrap→domain-traps/`, `03-review-patterns→ReviewPattern→review-patterns/`, `06-conventions→Convention→conventions/`, `01-overview→index.md`.
- Reader priority order (dir traversal): red-flags → pitfalls → hotspots → domain-traps → review-patterns → conventions → `index.md` (last).
- Migration constants (stamped on all transformed entries): `generated.at = 2026-08-07T00:00:00Z`, `generated.by = refresh-principles/opus-4-8`, `stale_after = 2027-02-07`, `verified = [{by: human:whung, at: 2026-08-07}]`, `status = stable`.
- Reserved OKF filenames: `index.md`, `log.md` (exempt from `type`/`sources` requirement).
- Precision rule: a concept with zero `sources[].resource` is invalid and must not be written.
- Version: `code-reviewer` 0.3.1 → **1.0.0** at `.claude-plugin/marketplace.json`.
- Test runner: `bash code-reviewer/tests/<name>.sh`; helper `code-reviewer/tests/_assert.sh` provides `assert "<label>" '<cond>'` and `finish`.
- Branch: `okf-migration` (already created). Commit per task.

---

### Task 1: OKF conformance format test + fixtures

**Files:**
- Create: `code-reviewer/tests/fixtures/golden-concept.md`
- Create: `code-reviewer/tests/fixtures/bad-no-type.md`
- Create: `code-reviewer/tests/fixtures/bad-no-sources.md`
- Rewrite: `code-reviewer/tests/test_principle_format.sh`
- Delete: `code-reviewer/tests/fixtures/golden-entry.md` (old role-file entry format)

**Interfaces:**
- Produces: a bash function `check_concept <file>` (exit 0 = conformant) reused conceptually by Task 3's test and Task 4's verification. Rule: frontmatter block present; `type:` non-empty; ≥1 `resource:` under `sources`.

- [ ] **Step 1: Write the golden concept fixture**

Create `code-reviewer/tests/fixtures/golden-concept.md`:

```markdown
---
type: Pitfall
title: ffprobe returns empty streams on 0-byte upload
status: stable
stale_after: 2027-02-07
sources:
  - resource: https://github.com/plaxieappier/video-center-2/pull/812
    title: PR #812
  - resource: a1b2c3d4e5f
generated: { by: refresh-principles/opus-4-8, at: 2026-08-07T00:00:00Z }
verified: [ { by: human:whung, at: 2026-08-07 } ]
---
**What:** ffprobe returns an empty streams array when handed a 0-byte upload.

**Why it matters:** downstream code indexes streams[0] and crashes.
```

- [ ] **Step 2: Write the two negative fixtures**

Create `code-reviewer/tests/fixtures/bad-no-type.md`:

```markdown
---
title: has no type field
sources:
  - resource: https://example.com/pr/1
---
**What:** missing the required type key.
```

Create `code-reviewer/tests/fixtures/bad-no-sources.md`:

```markdown
---
type: Pitfall
title: has type but no sources
---
**What:** violates the precision rule.
```

- [ ] **Step 3: Rewrite the test to check OKF conformance**

Replace the entire contents of `code-reviewer/tests/test_principle_format.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
FX="$DIR/fixtures"

# A conformant OKF concept: has a frontmatter block, a non-empty `type`,
# and at least one `resource:` under sources. Reserved files are exempt.
check_concept() {  # <file>
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{ok=1;exit} END{exit !ok}' "$1" || return 1
  local fm
  fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$1")"
  printf '%s\n' "$fm" | grep -qE '^type:[[:space:]]*[^[:space:]]' || return 1
  printf '%s\n' "$fm" | grep -qE 'resource:[[:space:]]*[^[:space:]]' || return 1
  return 0
}

echo "Test: golden concept is conformant"
assert "golden concept passes" 'check_concept "$FX/golden-concept.md"'

echo "Test: concept missing type is rejected"
assert "no-type concept fails" '! check_concept "$FX/bad-no-type.md"'

echo "Test: concept missing sources is rejected"
assert "no-sources concept fails" '! check_concept "$FX/bad-no-sources.md"'

finish
```

- [ ] **Step 4: Delete the obsolete fixture**

Run: `git rm code-reviewer/tests/fixtures/golden-entry.md`
Expected: file staged for deletion.

- [ ] **Step 5: Run the test — expect PASS**

Run: `bash code-reviewer/tests/test_principle_format.sh`
Expected:
```
  PASS  golden concept passes
  PASS  no-type concept fails
  PASS  no-sources concept fails

Passed: 3  Failed: 0
```

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/tests/test_principle_format.sh code-reviewer/tests/fixtures/
git commit -m "test: OKF concept conformance check replaces evidence-line check"
```

---

### Task 2: Rewrite the reader (`load-principle.sh`)

**Files:**
- Rewrite: `code-reviewer/lib/load-principle.sh`
- Create: `code-reviewer/tests/test_load_principle.sh`

**Interfaces:**
- Consumes: OKF bundle layout + frontmatter schema (Task 1 / spec §5–6).
- Produces: `load-principle.sh <bundle-dir> [cap-chars]` → stdout: per-concept blocks headed `=== <type>: <title>[ [STALE]] [<tier>] ===`, priority-ordered, plus `index.md` body last, plus a coverage footer. Skips `status: deprecated`. Default cap 30000.

- [ ] **Step 1: Write the failing reader test**

Create `code-reviewer/tests/test_load_principle.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
SUT="$DIR/../lib/load-principle.sh"

# Build a tiny bundle: one red-flag (stale, verified), one pitfall (fresh,
# machine-confirmed), one deprecated pitfall that must be skipped.
B="$(mktemp -d)"
mkdir -p "$B/red-flags" "$B/pitfalls"

cat > "$B/red-flags/old-blocker.md" <<'EOF'
---
type: RedFlag
title: old blocker
status: stable
stale_after: 2000-01-01
sources:
  - resource: https://example.com/pr/1
verified: [ { by: human:whung, at: 2026-08-07 } ]
---
**What:** an old red flag.
EOF

cat > "$B/pitfalls/fresh-pitfall.md" <<'EOF'
---
type: Pitfall
title: fresh pitfall
status: stable
stale_after: 2999-01-01
sources:
  - resource: https://example.com/pr/2
---
**What:** a fresh pitfall.
EOF

cat > "$B/pitfalls/gone.md" <<'EOF'
---
type: Pitfall
title: gone
status: deprecated
sources:
  - resource: https://example.com/pr/3
---
**What:** should be skipped.
EOF

cat > "$B/index.md" <<'EOF'
---
okf_version: "0.2"
---
# Overview — testrepo
Curated note lives here.
EOF

OUT="$(bash "$SUT" "$B")"

echo "Test: red-flag emitted before pitfall (priority order)"
assert "red-flag precedes pitfall" '[ "$(printf "%s" "$OUT" | grep -n "old blocker" | cut -d: -f1)" -lt "$(printf "%s" "$OUT" | grep -n "fresh pitfall" | cut -d: -f1)" ]'

echo "Test: stale entry flagged"
assert "old blocker marked STALE" 'printf "%s" "$OUT" | grep -q "old blocker \[STALE\]"'

echo "Test: trust tiers surfaced"
assert "red-flag human-reviewed" 'printf "%s" "$OUT" | grep -q "\[human-reviewed\]"'
assert "pitfall machine-confirmed" 'printf "%s" "$OUT" | grep -q "\[machine-confirmed\]"'

echo "Test: deprecated entry skipped"
assert "gone not emitted" '! printf "%s" "$OUT" | grep -q "should be skipped"'

echo "Test: index body emitted last"
assert "curated note present" 'printf "%s" "$OUT" | grep -q "Curated note lives here"'

echo "Test: footer reports skipped-deprecated"
assert "footer notes deprecated" 'printf "%s" "$OUT" | grep -qi "deprecated"'

rm -rf "$B"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash code-reviewer/tests/test_load_principle.sh`
Expected: FAIL — old script cats `07-red-flags.md` etc., emits nothing for the concept layout.

- [ ] **Step 3: Rewrite `load-principle.sh`**

Replace the entire contents of `code-reviewer/lib/load-principle.sh`:

```bash
#!/usr/bin/env bash
# load-principle.sh <bundle-dir> [cap-chars]
#
# Walk an OKF v0.2 bundle in review-priority order and emit its concepts,
# most merge-blocking first, within a character budget. Skips deprecated
# concepts; flags stale ones; surfaces each concept's trust tier.
#
# Priority = role-dir order: red-flags, pitfalls, hotspots, domain-traps,
# review-patterns, conventions; then index.md body last.
set -euo pipefail

dir="${1:-}"
cap="${2:-30000}"
[[ -n "$dir" && -d "$dir" ]] || {
  echo "Usage: $(basename "$0") <bundle-dir> [cap-chars]" >&2
  exit 64
}

today="$(date +%F)"
role_dirs=(red-flags pitfalls hotspots domain-traps review-patterns conventions)

included=(); stale_list=(); truncated=(); skipped_dep=(); total=0

_fm() {  # extract frontmatter block of <file>
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f{print}' "$1"
}

_emit() {  # <file> ; returns 1 if skipped/truncated
  local f="$1" fm status stale title type tier flag="" chunk size
  fm="$(_fm "$f")"
  status="$(printf '%s\n' "$fm" | sed -n 's/^status:[[:space:]]*//p' | head -1)"
  status="${status:-stable}"
  [[ "$status" == "deprecated" ]] && { skipped_dep+=("$(basename "$f")"); return 1; }
  printf '%s\n' "$fm" | grep -qE 'resource:[[:space:]]*[^[:space:]]' || { skipped_dep+=("$(basename "$f")"); return 1; }
  stale="$(printf '%s\n' "$fm" | sed -n 's/^stale_after:[[:space:]]*//p' | head -1)"
  title="$(printf '%s\n' "$fm" | sed -n 's/^title:[[:space:]]*//p' | head -1)"
  type="$(printf '%s\n' "$fm" | sed -n 's/^type:[[:space:]]*//p' | head -1)"
  if printf '%s\n' "$fm" | grep -q '^verified:'; then tier="human-reviewed"; else tier="machine-confirmed"; fi
  if [[ -n "$stale" && "$stale" < "$today" ]]; then flag=" [STALE]"; stale_list+=("$(basename "$f")"); fi
  chunk="=== ${type}: ${title}${flag} [${tier}] ===
$(cat "$f")
"
  size=${#chunk}
  if (( total + size > cap )); then truncated+=("$(basename "$f")"); return 1; fi
  printf '%s\n' "$chunk"
  included+=("$(basename "$f")"); total=$((total + size))
}

for rd in "${role_dirs[@]}"; do
  [[ -d "$dir/$rd" ]] || continue
  for f in "$dir/$rd"/*.md; do
    [[ -e "$f" ]] || continue
    _emit "$f" || true
  done
done

# index.md body last (lowest priority), within cap
if [[ -f "$dir/index.md" ]]; then
  body="$(awk 'c>=2{print} /^---/{c++}' "$dir/index.md")"
  [[ "$(awk 'NR==1' "$dir/index.md")" == "---" ]] || body="$(cat "$dir/index.md")"
  chunk="=== index.md ===
${body}
"
  if (( total + ${#chunk} <= cap )); then
    printf '%s\n' "$chunk"; included+=("index.md"); total=$((total + ${#chunk}))
  else
    truncated+=("index.md")
  fi
fi

printf '=== Principle Coverage ===\n'
printf 'Source dir: %s\n' "$dir"
printf 'Included (%d): %s\n' "${#included[@]}" "${included[*]:-none}"
(( ${#stale_list[@]} > 0 )) && printf 'Stale-flagged (%d): %s\n' "${#stale_list[@]}" "${stale_list[*]}"
(( ${#skipped_dep[@]} > 0 )) && printf 'Skipped deprecated (%d): %s\n' "${#skipped_dep[@]}" "${skipped_dep[*]}"
(( ${#truncated[@]} > 0 )) && printf 'Truncated for context budget (%d): %s\n' "${#truncated[@]}" "${truncated[*]}"
printf 'Total chars: %d / cap %d\n' "$total" "$cap"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash code-reviewer/tests/test_load_principle.sh`
Expected: `Passed: 8  Failed: 0`

- [ ] **Step 5: Commit**

```bash
git add code-reviewer/lib/load-principle.sh code-reviewer/tests/test_load_principle.sh
git commit -m "feat!: reader walks OKF concept bundle, skips deprecated, flags stale"
```

---

### Task 3: Migration transform script

**Files:**
- Create: `code-reviewer/scripts/migrate-to-okf.py`
- Create: `code-reviewer/tests/test_migrate_to_okf.sh`

**Interfaces:**
- Consumes: an old-format bundle dir (`0X-*.md` role files).
- Produces: CLI `python3 migrate-to-okf.py <bundle-dir>` — rewrites the dir in place to OKF (concept files in role subdirs, `index.md`, `log.md`), deletes old `0X-*.md`, leaves `.learn-state.json` untouched. Only `### ` blocks with parseable citations become concepts; uncited blocks + old overview prose go to `index.md` body. Prints `<n concepts written>`.

- [ ] **Step 1: Write the failing transform test**

Create `code-reviewer/tests/test_migrate_to_okf.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_assert.sh"
SUT="$DIR/../scripts/migrate-to-okf.py"

B="$(mktemp -d)"
cat > "$B/07-red-flags.md" <<'EOF'
# Red flags

### Null deref on empty audio stream
- **What:** indexing streams[0] on a 0-byte upload crashes.
- **Evidence:** PR #812 (https://github.com/plaxieappier/video-center-2/pull/812) · commit a1b2c3d4e5f — 2026-03-01
- **Why it matters:** hard crash in the ingest path.
EOF
cat > "$B/02-pitfalls.md" <<'EOF'
# Pitfalls

### R1. Legacy checklist item without citation
- Some hand-written guidance with no evidence line.
EOF
cat > "$B/01-overview.md" <<'EOF'
---
repo: plaxieappier/testrepo
---
# Overview — testrepo
Hand-curated prose worth keeping.
EOF
touch "$B/.learn-state.json"

python3 "$SUT" "$B"

echo "Test: cited red-flag became a concept file"
assert "concept file exists" '[ -f "$B/red-flags/null-deref-on-empty-audio-stream.md" ]'

echo "Test: concept carries type + sources + verified"
assert "type present"     'grep -q "^type: RedFlag" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "pr source present" 'grep -q "pull/812" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "sha source present" 'grep -q "a1b2c3d4e5f" "$B/red-flags/null-deref-on-empty-audio-stream.md"'
assert "verified stamped"  'grep -q "human:whung" "$B/red-flags/null-deref-on-empty-audio-stream.md"'

echo "Test: uncited legacy block folded into index.md, not a concept"
assert "no pitfall concept" '[ -z "$(ls -A "$B/pitfalls" 2>/dev/null)" ] || ! ls "$B/pitfalls"/*.md >/dev/null 2>&1'
assert "legacy note in index" 'grep -q "Legacy checklist item" "$B/index.md"'
assert "curated prose in index" 'grep -q "Hand-curated prose worth keeping" "$B/index.md"'

echo "Test: reserved files + watermark present, old role files gone"
assert "index.md exists" '[ -f "$B/index.md" ]'
assert "log.md exists"   '[ -f "$B/log.md" ]'
assert "watermark kept"  '[ -f "$B/.learn-state.json" ]'
assert "old role file removed" '[ ! -f "$B/07-red-flags.md" ]'

rm -rf "$B"
finish
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash code-reviewer/tests/test_migrate_to_okf.sh`
Expected: FAIL — `migrate-to-okf.py` does not exist yet (`python3: can't open file`).

- [ ] **Step 3: Write the transform script**

Create `code-reviewer/scripts/migrate-to-okf.py`:

```python
#!/usr/bin/env python3
"""Transform an old role-file principle bundle into an OKF v0.2 bundle, in place.

Only '### ' blocks with a parseable citation (PR URL / commit SHA / http URL)
become concept files. Uncited blocks and the old 01-overview prose are folded
into index.md so nothing curated is lost. Deterministic — dates are fixed
migration constants.
"""
import os, re, sys

GEN_AT   = "2026-08-07T00:00:00Z"
GEN_BY   = "refresh-principles/opus-4-8"
STALE    = "2027-02-07"
VERIF_AT = "2026-08-07"

ROLE = {  # old-file stem -> (type, subdir)
    "02-pitfalls":       ("Pitfall",       "pitfalls"),
    "03-review-patterns":("ReviewPattern", "review-patterns"),
    "04-domain-traps":   ("DomainTrap",    "domain-traps"),
    "05-hotspots":       ("Hotspot",       "hotspots"),
    "06-conventions":    ("Convention",    "conventions"),
    "07-red-flags":      ("RedFlag",       "red-flags"),
}
SECTION_ORDER = ["red-flags", "pitfalls", "hotspots",
                 "domain-traps", "review-patterns", "conventions"]

def slug(title):
    s = re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    return (s[:60].rstrip("-")) or "untitled"

def strip_frontmatter(text):
    if text.startswith("---"):
        parts = text.split("---", 2)
        if len(parts) == 3:
            return parts[2].lstrip("\n")
    return text

def split_entries(body):  # -> list of (title, block_text)
    out, cur_title, cur = [], None, []
    for line in body.splitlines():
        if line.startswith("### "):
            if cur_title is not None:
                out.append((cur_title, "\n".join(cur)))
            cur_title, cur = line[4:].strip(), []
        elif cur_title is not None:
            cur.append(line)
    if cur_title is not None:
        out.append((cur_title, "\n".join(cur)))
    return out

def parse_sources(block):  # -> list of resource strings
    m = re.search(r"^-\s*\*\*Evidence:\*\*(.*)$", block, re.MULTILINE)
    if not m:
        return []
    ev = m.group(1)
    urls = re.findall(r"https?://[^\s)]+", ev)
    shas = re.findall(r"\bcommit\s+([0-9a-f]{7,40})\b", ev)
    # standalone hex not already inside a captured url
    joined = " ".join(urls)
    shas += [h for h in re.findall(r"\b([0-9a-f]{7,40})\b", ev) if h not in joined and h not in shas]
    res = []
    for u in urls: res.append(u)
    for h in shas:
        if h not in res: res.append(h)
    return res

def field(block, label):  # extract '- **Label:** value'
    m = re.search(r"^-\s*\*\*%s:\*\*\s*(.*)$" % re.escape(label), block, re.MULTILINE)
    return m.group(1).strip() if m else ""

def concept_md(ctype, title, sources, what, why):
    src_yaml = "".join("  - resource: %s\n" % s for s in sources)
    what = what or "(migrated)"
    body = "**What:** %s\n" % what
    if why:
        body += "\n**Why it matters:** %s\n" % why
    return (
        "---\n"
        "type: %s\n" % ctype +
        "title: %s\n" % title +
        "status: stable\n"
        "stale_after: %s\n" % STALE +
        "sources:\n" + src_yaml +
        "generated: { by: %s, at: %s }\n" % (GEN_BY, GEN_AT) +
        "verified: [ { by: human:whung, at: %s } ]\n" % VERIF_AT +
        "---\n" + body
    )

def main(bundle):
    repo = os.path.basename(bundle.rstrip("/"))
    concepts, curated_notes, overview_prose = {sd: [] for _, sd in ROLE.values()}, [], ""
    n = 0

    for stem, (ctype, subdir) in ROLE.items():
        p = os.path.join(bundle, stem + ".md")
        if not os.path.isfile(p):
            continue
        body = strip_frontmatter(open(p).read())
        for title, block in split_entries(body):
            title = re.sub(r"\s*\(\d+\s*lines?\)\s*$", "", title)  # drop hotspot "(216 lines)" suffix
            sources = parse_sources(block)
            if not sources:
                curated_notes.append("### %s\n%s" % (title, block.strip()))
                continue
            fn = slug(title)
            dst = os.path.join(bundle, subdir)
            os.makedirs(dst, exist_ok=True)
            path = os.path.join(dst, fn + ".md")
            i = 2
            while os.path.exists(path):
                path = os.path.join(dst, "%s-%d.md" % (fn, i)); i += 1
            what = field(block, "What")
            why  = field(block, "Why it matters")
            open(path, "w").write(concept_md(ctype, title, sources, what, why))
            concepts[subdir].append((title, os.path.basename(path)))
            n += 1

    ov = os.path.join(bundle, "01-overview.md")
    if os.path.isfile(ov):
        overview_prose = strip_frontmatter(open(ov).read()).strip()

    # index.md
    idx = ['---\nokf_version: "0.2"\n---\n', "# Overview — %s\n" % repo]
    if overview_prose:
        idx.append("\n" + overview_prose + "\n")
    heading = {"red-flags":"Red flags","pitfalls":"Pitfalls","hotspots":"Hotspots",
               "domain-traps":"Domain traps","review-patterns":"Review patterns","conventions":"Conventions"}
    for sd in SECTION_ORDER:
        items = concepts.get(sd) or []
        if not items: continue
        idx.append("\n# %s\n" % heading[sd])
        for title, fn in items:
            idx.append("* [%s](%s/%s)\n" % (title, sd, fn))
    if curated_notes:
        idx.append("\n# Curated notes (uncited, pre-OKF)\n\n" + "\n\n".join(curated_notes) + "\n")
    open(os.path.join(bundle, "index.md"), "w").write("".join(idx))

    # log.md
    open(os.path.join(bundle, "log.md"), "w").write(
        "# Refresh log — %s\n\n## %s\n* **Migration**: converted to OKF v0.2 (%d concepts).\n"
        % (repo, VERIF_AT, n))

    # remove old role files
    for stem in list(ROLE) + ["01-overview"]:
        p = os.path.join(bundle, stem + ".md")
        if os.path.isfile(p): os.remove(p)

    print("%d concepts written" % n)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("usage: migrate-to-okf.py <bundle-dir>", file=sys.stderr); sys.exit(64)
    main(sys.argv[1])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash code-reviewer/tests/test_migrate_to_okf.sh`
Expected: all assertions PASS, `Failed: 0`.

- [ ] **Step 5: Confirm migrated fixture is reader-consumable (integration)**

Run:
```bash
B="$(mktemp -d)"; cp code-reviewer/tests/fixtures/golden-concept.md "$B/" 2>/dev/null; \
mkdir -p "$B/red-flags"; cat > "$B/07-red-flags.md" <<'EOF'
### Null deref on empty audio stream
- **What:** crash.
- **Evidence:** PR #812 (https://github.com/plaxieappier/video-center-2/pull/812) · commit a1b2c3d4e5f
- **Why it matters:** ingest crash.
EOF
python3 code-reviewer/scripts/migrate-to-okf.py "$B" && bash code-reviewer/lib/load-principle.sh "$B" | head -20; rm -rf "$B"
```
Expected: reader prints `=== RedFlag: Null deref on empty audio stream [human-reviewed] ===` and a coverage footer.

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/scripts/migrate-to-okf.py code-reviewer/tests/test_migrate_to_okf.sh
git commit -m "feat: add deterministic old->OKF bundle migration transform"
```

---

### Task 4: Migrate the 14 live bundles (MUTATION — approval-gated)

**Files:**
- Modify (data): `$LIFEOS/01Project/Appier/CodeReviewPrinciple/<repo>/` × 14

**Interfaces:**
- Consumes: `migrate-to-okf.py` (Task 3), `load-principle.sh` (Task 2), `check_concept` rule (Task 1).

> ⚠️ **This task mutates live principle data under LifeOS. Per user rule, get explicit approval before running Step 3, and back up first.**

- [ ] **Step 1: Snapshot the current entry count (baseline)**

Run:
```bash
export LIFEOS=/Users/william.hung/Projects/LifeOS
ROOT="$LIFEOS/01Project/Appier/CodeReviewPrinciple"
grep -rc '^### ' "$ROOT"/*/0[2-7]-*.md 2>/dev/null | awk -F: '{s+=$2} END{print "baseline ### entries:", s}'
```
Expected: `baseline ### entries: 68` (record the exact number).

- [ ] **Step 2: Back up all 14 bundles**

Run:
```bash
cp -a "$ROOT" "$ROOT.bak-2026-08-07"
ls -d "$ROOT.bak-2026-08-07"/*/ | wc -l
```
Expected: `14` (backup exists; rollback = `rm -rf "$ROOT" && mv "$ROOT.bak-2026-08-07" "$ROOT"`).

- [ ] **Step 3: Run the transform on every bundle (AFTER approval)**

Run:
```bash
total=0
for d in "$ROOT"/*/; do
  [ -f "$d/01-overview.md" ] || [ -f "$d"/0*-*.md ] || continue
  out="$(python3 code-reviewer/scripts/migrate-to-okf.py "$d")"
  echo "$(basename "$d"): $out"
  total=$((total + ${out%% *}))
done
echo "TOTAL concepts written: $total"
```
Expected: per-repo lines summing to the baseline; `TOTAL concepts written: 68`.

- [ ] **Step 4: Verify conformance on all migrated concepts**

Run:
```bash
source code-reviewer/tests/_assert.sh 2>/dev/null || true
bad=0
while IFS= read -r f; do
  case "$(basename "$f")" in index.md|log.md) continue;; esac
  awk 'NR==1&&/^---/{f=1;next} f&&/^---/{ok=1;exit} END{exit !ok}' "$f" \
    && grep -qE '^type:[[:space:]]*[^[:space:]]' "$f" \
    && grep -qE 'resource:[[:space:]]*[^[:space:]]' "$f" || { echo "NONCONFORMANT: $f"; bad=$((bad+1)); }
done < <(find "$ROOT" -name '*.md')
echo "nonconformant: $bad"
```
Expected: `nonconformant: 0`.

- [ ] **Step 5: Spot-check one bundle through the reader**

Run: `bash code-reviewer/lib/load-principle.sh "$ROOT/video-center-2" | tail -15`
Expected: coverage footer lists included concepts (red-flags first), no errors.

- [ ] **Step 6: Confirm & clean up backup**

Only after Steps 3–5 pass and count == baseline, ask the user whether to delete `$ROOT.bak-2026-08-07`. Do not delete unprompted. No commit — this is data under LifeOS, not the git repo.

---

### Task 5: Update `principle-reviewer` agent

**Files:**
- Modify: `code-reviewer/agents/principle-reviewer.md`

**Interfaces:**
- Consumes: reader output format (Task 2 headers `[STALE]`/`[<tier>]`).

- [ ] **Step 1: Replace role-file citations with concept-path citations**

In `code-reviewer/agents/principle-reviewer.md`, change every principle-file citation from the `0X-name.md` form to the concept-dir form. Specifically:
- `07-red-flags.md` → `red-flags/<slug>.md`
- `02-pitfalls.md` → `pitfalls/<slug>.md`
- `05-hotspots.md` → `hotspots/<slug>.md`
- `04-domain-traps.md` → `domain-traps/<slug>.md`
- `06-conventions.md` → `conventions/<slug>.md`

- [ ] **Step 2: Add the trust/stale down-weighting instruction**

In Phase 2, after the classification bullets, add:

```markdown
**Confidence weighting.** The loader marks each concept with a trust tier and staleness:
- `[human-reviewed]` + not stale → full weight; a red-flag hit here is blocking.
- `[machine-confirmed]` (no human `verified`) or `[STALE]` → lower confidence. Surface as
  "verify still live" rather than blocking; note the staleness in your finding.
```

- [ ] **Step 3: Update the coverage line in Phase 3**

Change the `### Principle Coverage` template line from `(<N>/7 menu files present; …)` to:

```markdown
Reviewed against: <role dirs present and concept counts, from the loader footer>
Principle source: <abs path>
```

- [ ] **Step 4: Verify no stale references remain**

Run: `grep -nE '0[1-7]-(overview|pitfalls|review-patterns|domain-traps|hotspots|conventions|red-flags)' code-reviewer/agents/principle-reviewer.md`
Expected: no output (exit 1).
Run: `grep -q 'machine-confirmed' code-reviewer/agents/principle-reviewer.md && echo OK`
Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add code-reviewer/agents/principle-reviewer.md
git commit -m "feat!: principle-reviewer cites OKF concept paths + trust/stale weighting"
```

---

### Task 6: Update refresh skill + format reference

**Files:**
- Modify: `code-reviewer/skills/refresh-principles/SKILL.md`
- Rewrite: `code-reviewer/skills/refresh-principles/references/principle-file-format.md`

**Interfaces:**
- Consumes: concept schema + role→type→dir map (spec §5–6).

- [ ] **Step 1: Rewrite the format reference**

Replace the entire contents of `code-reviewer/skills/refresh-principles/references/principle-file-format.md`:

```markdown
# OKF concept format (v0.2)

A principle bundle is an OKF v0.2 directory tree. Each mined entry is ONE
concept `.md` file with YAML frontmatter, grouped in a role subdir. Reserved
files `index.md` (listing) and `log.md` (history) carry no `type`/`sources`.

## Concept schema

```yaml
---
type: Pitfall                 # REQUIRED. RedFlag|Pitfall|Hotspot|DomainTrap|ReviewPattern|Convention
title: <short imperative title>
status: stable                # stable | deprecated
stale_after: <YYYY-MM-DD>     # generated date + 6 months
sources:                      # >=1 REQUIRED. No source -> drop the entry.
  - resource: <PR url | commit sha | comment url>
    title: <optional label>
generated: { by: refresh-principles/<model>, at: <ISO-8601> }
verified: [ { by: human:<id>, at: <YYYY-MM-DD> } ]   # stamped on approval
---
**What:** one line.

**Why it matters:** one line.
```

## Role -> type -> directory

| Signal | type | directory |
|---|---|---|
| reverts/hotfixes/blocked-then-fixed | RedFlag | red-flags/ |
| bug clusters across >=2 PRs | Pitfall | pitfalls/ |
| high-churn files | Hotspot | hotspots/ |
| domain gotchas that caused change | DomainTrap | domain-traps/ |
| repeated reviewer asks | ReviewPattern | review-patterns/ |
| convention asks that caused change | Convention | conventions/ |

## Reader priority

`load-principle.sh` emits role dirs in this order (most merge-blocking first):
red-flags -> pitfalls -> hotspots -> domain-traps -> review-patterns ->
conventions -> index.md. It skips `status: deprecated`, flags entries past
`stale_after` as `[STALE]`, and marks each concept `[human-reviewed]` or
`[machine-confirmed]`.

## Conformance

Every non-reserved `.md`: parseable frontmatter + non-empty `type` +
>=1 `sources[].resource`. See `tests/test_principle_format.sh`.
```

- [ ] **Step 2: Update SKILL.md Step 4 (distill)**

Replace the Step 4 body so it routes each item to a concept file:

```markdown
## Step 4 — Distill (precision-first)

Read `references/principle-file-format.md`. Turn ONLY high-signal, corroborated
items into concepts; prefer comments that went **outdated** after being posted
(`caused_change:true`), plus reverts, hotfixes, and clusters recurring across
≥N PRs (N default 2). Each item becomes ONE concept `.md` in its role subdir
(role→type→dir map in the reference), filename = kebab-slug of the title, with
a `sources:` list built from the cited PR#/SHA/comment URLs. Drop anything you
cannot cite.
```

- [ ] **Step 3: Update SKILL.md Step 5 (approve stamps verified)**

Replace the Step 5 body:

```markdown
## Step 5 — Propose (approval gate)

Show a unified diff of the proposed concept files. Use AskUserQuestion:
Approve / Edit / Skip. On **Approve**, stamp each written concept with
`generated: { by: refresh-principles/<model>, at: <now> }` and
`verified: [ { by: human:<id>, at: <today> } ]` — approval doubles as human
sign-off (→ trust tier human-reviewed). Do not proceed without approval.
```

- [ ] **Step 4: Update SKILL.md Step 6 (write concepts + log.md)**

Replace the Step 6 body:

```markdown
## Step 6 — Write

On approval, write each concept `.md` into its role subdir; **dedupe by
`sources[].resource`** (never write a concept whose resource already appears in
the bundle). Regenerate `index.md` (okf_version + grouped listing, preserving
any curated prose). Prepend a dated entry to `log.md`. Writes are plain file
writes; do NOT `git commit` the principle dir.
```

- [ ] **Step 5: Verify**

Run: `grep -nE '0[1-7]-(overview|pitfalls|review-patterns|domain-traps|hotspots|conventions|red-flags)' code-reviewer/skills/refresh-principles/SKILL.md code-reviewer/skills/refresh-principles/references/principle-file-format.md`
Expected: no output.
Run: `grep -q 'okf_version' code-reviewer/skills/refresh-principles/references/principle-file-format.md && echo OK`
Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add code-reviewer/skills/refresh-principles/
git commit -m "docs!: refresh-principles writes OKF concepts, stamps verified on approval"
```

---

### Task 7: Housekeeping — learn-state test + version bump

**Files:**
- Modify: `code-reviewer/tests/test_learn_state.sh`
- Modify: `.claude-plugin/marketplace.json:45`

**Interfaces:** none (self-contained cleanup).

- [ ] **Step 1: Drop hardcoded `01-07` filename references from test_learn_state.sh**

Run: `grep -nE '0[1-7]-(overview|pitfalls|review-patterns|domain-traps|hotspots|conventions|red-flags)' code-reviewer/tests/test_learn_state.sh`
For each hit, replace any seeded old role file with an OKF concept path (e.g. create `red-flags/x.md` with valid frontmatter) or remove the reference if it only checked file presence. The watermark logic under test (`.learn-state.json`) is format-agnostic and must still pass.

- [ ] **Step 2: Run the learn-state test**

Run: `bash code-reviewer/tests/test_learn_state.sh`
Expected: `Failed: 0`.

- [ ] **Step 3: Bump the plugin version**

In `.claude-plugin/marketplace.json`, change the `code-reviewer` entry version:

```json
      "version": "1.0.0",
```
(was `"0.3.1"` at line 45).

- [ ] **Step 4: Verify + run the full suite**

Run:
```bash
grep -A3 '"code-reviewer"' .claude-plugin/marketplace.json | grep '"version": "1.0.0"'
for t in code-reviewer/tests/test_*.sh; do echo "== $t =="; bash "$t" || exit 1; done
```
Expected: version line matches; every test ends `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add code-reviewer/tests/test_learn_state.sh .claude-plugin/marketplace.json
git commit -m "chore!: bump code-reviewer to 1.0.0 (OKF format), fix learn-state test"
```

---

## Self-Review

**Spec coverage:**
- §5 layout → Task 3 (transform emits subdirs), Task 2 (reader traverses them). ✓
- §6 frontmatter schema → Task 1 (fixture+check), Task 3 (concept_md), Task 6 (reference doc). ✓
- §7 reader → Task 2. ✓
- §8 agent → Task 5. ✓
- §9 skill → Task 6. ✓
- §10 tests → Task 1. ✓
- §11 migration → Task 3 (script) + Task 4 (run on 14). ✓
- §12 blast radius → all 8 files covered across Tasks 1–7. ✓
- §13 success criteria → Task 4 Steps 3-5 (count+conformance+reader), Task 7 Step 4 (version+suite). ✓

**Placeholder scan:** No TBD/TODO. All code blocks complete. `<slug>`, `<model>`, `<id>` in docs are intentional template tokens the agent fills at runtime, not plan gaps.

**Type consistency:** `check_concept` rule (frontmatter + `type` + `resource`) identical in Task 1, Task 3 test, Task 4 Step 4. Reader header format `=== <type>: <title>[ [STALE]] [<tier>] ===` consistent between Task 2 impl and Task 2/Task 3/Task 5 consumers. Role→type→dir map identical in Global Constraints, Task 3 `ROLE`/`SECTION_ORDER`, Task 5, Task 6. Migration constants identical in Global Constraints, Task 1 fixture, Task 3 script.
