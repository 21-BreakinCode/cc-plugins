"""Self-check for tag rules: python3 test_tags.py"""
from classify import classify, is_allowed, is_false_tag
from rewrite import rewrite_body
from taxonomy import add_rows, has_sections, parse_taxonomy

# False tags from the LifeOS scan: hex color, commit hash, Jira number, list marker.
for false_tag in ("0c8599", "4f67687", "13，我卻把", "1-", "3：IAInvLev", "124/126"):
    assert is_false_tag(false_tag), false_tag
for real_tag in ("facade", "decade", "domain/db", "中文/閱讀", "lang/go"):
    assert not is_false_tag(real_tag), real_tag

assert is_allowed("lc/topic/DP", {"lc/*"})
assert not is_allowed("lcx", {"lc/*"})

findings = {finding["tag"]: finding for finding in classify(
    {"0c8599": 1, "domain/db": 30, "domain/database": 32, "system-deisgn": 2, "system-design": 10,
     "old/tag": 3, "domain/llm": 25, "one-off": 1, "lc/topic/DP": 26, "domain/os": 13},
    allowed={"domain/llm", "lc/*", "domain/os"}, merged={"old/tag": "new/tag"})}
assert findings["0c8599"] == {"tag": "0c8599", "kind": "false", "action": "code", "new": ""}
assert findings["old/tag"] == {"tag": "old/tag", "kind": "merged-back", "action": "rename", "new": "new/tag"}
assert findings["domain/db"]["kind"] == "off-taxonomy"
assert findings["domain/database"]["kind"] == "off-taxonomy"
assert findings["system-deisgn"] == {"tag": "system-deisgn", "kind": "typo", "action": "rename", "new": "system-design"}
assert findings["one-off"]["kind"] == "singleton" and findings["one-off"]["action"] == "keep"
assert "domain/llm" not in findings and "lc/topic/DP" not in findings
# Short tags are never typo candidates: db vs os is distance 2 but not a typo.
assert "domain/os" not in findings and findings["domain/db"]["kind"] != "typo"

# Duplicate = same parent and one leaf is a prefix covering at least half of the other.
# Checked against the real LifeOS inventory: abbreviation matching only produced false merges.
real_domain = {finding["tag"]: finding for finding in classify(
    {"domain/network": 10, "domain/networking": 35, "domain/clickhouse": 10, "domain/cli": 12,
     "domain/sre": 1, "domain/serverless": 3, "ci": 1, "containers": 4, "domain/db": 30,
     "domain/database": 32, "domain/llm": 25, "domain/llms": 2}, allowed=set(), merged={})}
assert real_domain["domain/network"]["new"] == "domain/networking"
assert real_domain["domain/llms"]["new"] == "domain/llm"
for unrelated in ("domain/clickhouse", "domain/sre", "ci", "domain/db"):
    assert real_domain[unrelated]["kind"] != "duplicate", unrelated

body = "\n".join([
    "#domain/db #domain/db/query #domain/dbx",
    "color `#0c8599` and #0c8599, see https://x.com/a#0c8599",
    "```",
    "#domain/db stays in code",
    "```",
    "ticket #13，我卻把 done",
])
assert rewrite_body(body, {"domain/db": "domain/database"}, {"0c8599", "13，我卻把"}) == "\n".join([
    "#domain/database #domain/database/query #domain/dbx",
    "color `#0c8599` and `#0c8599`, see https://x.com/a#0c8599",
    "```",
    "#domain/db stays in code",
    "```",
    "ticket `#13，我卻把` done",
])
assert rewrite_body(body, {}, set()) == body
# A false tag glued to the next "#" (PR ranges like "#1/#3") still ends at that "#".
assert rewrite_body("PR #1/#3 and #100/#101, see #1-#10", {}, {"1/", "100/", "1-"}) == \
    "PR `#1/`#3 and `#100/`#101, see `#1-`#10"

# I2: heading links, anchor links, Obsidian comments, and HTML attribute colors are left alone.
for unchanged in ("[[#python]]", "[x](#python)", "%% #python %%"):
    assert rewrite_body(unchanged, {"python": "py"}, set()) == unchanged, unchanged
for unchanged in ('style="color: #0c8599"', "color:#0c8599"):
    assert rewrite_body(unchanged, {}, {"0c8599"}) == unchanged, unchanged

# I3: TAG_STOP_CHARS covers "*", "|", "~", "=", and the backtick.
assert rewrite_body("**#python**", {"python": "py"}, set()) == "**#py**"

TAXONOMY = "# Tag taxonomy\n\n## Allowed\n\n| tag | meaning |\n|---|---|\n| `lc/*` | Leetcode |\n| `domain/llm` | LLMs |\n\n## Merged\n\n| old | new | date |\n|---|---|---|\n| `domain/db` | `domain/database` | 2026-09-26 |\n"
allowed, merged = parse_taxonomy(TAXONOMY)
assert allowed == {"lc/*": "Leetcode", "domain/llm": "LLMs"}
assert merged == {"domain/db": "domain/database"}
updated = add_rows(TAXONOMY, "Allowed", [["`domain/os`", ""]])
assert parse_taxonomy(updated)[0]["domain/os"] == ""
assert updated.index("`domain/os`") < updated.index("## Merged")

# I6: has_sections requires both ## Allowed and ## Merged, case-insensitively.
assert has_sections(TAXONOMY) is True
assert has_sections(TAXONOMY[:TAXONOMY.index("## Merged")]) is False

print("test_tags: all passed")
