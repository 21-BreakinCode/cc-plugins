"""Classify vault tags into false, merged-back, typo, duplicate, singleton, and off-taxonomy."""
import re

HEX_WITH_DIGIT = re.compile(r"^(?=.*\d)[0-9a-f]{6,7}$", re.IGNORECASE)
CJK_PUNCTUATION = re.compile(r"[，。、：；！？（）「」『』]")
TYPO_MAX_DISTANCE = 2
TYPO_MIN_LENGTH = 5
DUPLICATE_MIN_LEAF = 2
PREFIX_MIN_COVERAGE = 0.5


def is_false_tag(tag: str) -> bool:
    return tag[:1].isdigit() or bool(HEX_WITH_DIGIT.match(tag)) or bool(CJK_PUNCTUATION.search(tag))


def is_allowed(tag: str, allowed: set[str]) -> bool:
    if tag in allowed:
        return True
    parts = tag.split("/")
    return any("/".join(parts[:depth]) + "/*" in allowed for depth in range(1, len(parts)))


def edit_distance(first: str, second: str) -> int:
    previous_row = list(range(len(second) + 1))
    for row_index, first_char in enumerate(first, 1):
        current_row = [row_index]
        for column_index, second_char in enumerate(second, 1):
            current_row.append(min(previous_row[column_index] + 1, current_row[column_index - 1] + 1,
                                   previous_row[column_index - 1] + (first_char != second_char)))
        previous_row = current_row
    return previous_row[-1]


def find_typo_target(tag: str, candidates: list[str]) -> str | None:
    # Compare leaves under the same parent: "domain/db" vs "domain/os" differ by 2 but are not typos.
    parent, _, leaf = tag.rpartition("/")
    if len(leaf) < TYPO_MIN_LENGTH:
        return None
    for candidate in candidates:
        candidate_parent, _, candidate_leaf = candidate.rpartition("/")
        if candidate != tag and candidate_parent == parent and len(candidate_leaf) >= TYPO_MIN_LENGTH \
                and edit_distance(leaf, candidate_leaf) <= TYPO_MAX_DISTANCE:
            return candidate
    return None


def is_prefix_duplicate(first_leaf: str, second_leaf: str) -> bool:
    # "cli" is a prefix of "clickhouse" but covers too little of it to mean the same thing.
    shorter, longer = sorted((first_leaf, second_leaf), key=len)
    return longer.startswith(shorter) and len(shorter) >= len(longer) * PREFIX_MIN_COVERAGE


def find_duplicate_target(tag: str, counts: dict[str, int]) -> str | None:
    parent, _, leaf = tag.rpartition("/")
    for other in sorted(counts):
        other_parent, _, other_leaf = other.rpartition("/")
        if other == tag or other_parent != parent or min(len(leaf), len(other_leaf)) < DUPLICATE_MIN_LEAF:
            continue
        if is_prefix_duplicate(leaf, other_leaf) and counts[other] > counts[tag]:
            return other
    return None


def finding(tag: str, kind: str, action: str, new: str = "") -> dict:
    return {"tag": tag, "kind": kind, "action": action, "new": new}


def classify(counts: dict[str, int], allowed: set[str], merged: dict[str, str]) -> list[dict]:
    plain_allowed = sorted(entry for entry in allowed if not entry.endswith("/*"))
    findings = []
    for tag in sorted(counts):
        if is_false_tag(tag):
            findings.append(finding(tag, "false", "code"))
            continue
        if tag in merged:
            findings.append(finding(tag, "merged-back", "rename", merged[tag]))
            continue
        if is_allowed(tag, allowed):
            continue
        more_used = [other for other in sorted(counts) if counts[other] > counts[tag] and not is_false_tag(other)]
        typo_target = find_typo_target(tag, plain_allowed + more_used)
        if typo_target:
            findings.append(finding(tag, "typo", "rename", typo_target))
            continue
        duplicate_target = find_duplicate_target(tag, counts)
        if duplicate_target:
            findings.append(finding(tag, "duplicate", "rename", duplicate_target))
            continue
        findings.append(finding(tag, "singleton" if counts[tag] == 1 else "off-taxonomy", "keep"))
    return findings
