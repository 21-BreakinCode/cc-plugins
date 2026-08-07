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

_SEED_SENT = "Evidence-anchored entries mined from merged git+PR history."

def preamble_before_blocks(body):  # prose before the first '### ' heading, or whole body if none
    if body.startswith("### "):
        return ""
    i = body.find("\n### ")
    return (body if i == -1 else body[:i]).strip()

def is_meaningful(text):  # True unless text is blank, headings-only, or pure seed boilerplate
    for ln in text.splitlines():
        s = ln.strip()
        if s and not s.startswith("#") and s != _SEED_SENT:
            return True
    return False

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

def field(block, label):  # extract '- **Label:** value', capturing wrapped continuation lines
    m = re.search(r"^-\s*\*\*%s:\*\*\s*(.*?)(?=\n-\s*\*\*|\n\s*\n|\Z)" % re.escape(label), block, re.MULTILINE | re.DOTALL)
    if not m: return ""
    return " ".join(ln.strip() for ln in m.group(1).splitlines()).strip()

_KNOWN_BULLETS = re.compile(
    r"(?ms)^-\s*\*\*(?:What|Evidence|Why it matters):\*\*.*?(?=\n-\s*\*\*|\n\s*\n|\Z)")

def block_notes(block):  # remaining bullets after What/Evidence/Why it matters are stripped
    leftover = _KNOWN_BULLETS.sub("", block)
    return "\n".join(ln for ln in leftover.splitlines() if ln.strip()).strip()

def yaml_str(s):  # quote only when the raw scalar would be YAML-hostile
    if re.search(r'''[:#\[\]{}&*!|>%@`"']''', s) or s.strip() != s:
        return '"%s"' % s.replace('\\', '\\\\').replace('"', '\\"')
    return s

def concept_md(ctype, title, sources, what, why, notes=""):
    src_yaml = "".join("  - resource: %s\n" % s for s in sources)
    what = what or "(migrated)"
    body = "**What:** %s\n" % what
    if why:
        body += "\n**Why it matters:** %s\n" % why
    if notes:
        body += "\n**Notes:**\n%s\n" % notes
    return (
        "---\n"
        "type: %s\n" % ctype +
        "title: %s\n" % yaml_str(title) +
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
        entries = split_entries(body)
        pre = preamble_before_blocks(body)
        if is_meaningful(pre):
            curated_notes.append("### (preamble from %s.md)\n%s" % (stem, pre))
        for title, block in entries:
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
            notes = block_notes(block)
            open(path, "w").write(concept_md(ctype, title, sources, what, why, notes))
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
