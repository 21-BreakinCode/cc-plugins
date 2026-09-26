"""Rewrite inline tags in a note body: rename tags and wrap false tags in backticks.

Fenced code blocks, inline code, and %%...%% comments are never changed.
"""
import re

FENCE = re.compile(r"^\s*(```|~~~)")
SKIPPED_SPAN = re.compile(r"(`+[^`]*`+|%%[^%]*%%)")
TAG_STOP_CHARS = r"\s,.;:!?\"'()\[\]{}<>*|~=`"


def build_tag_pattern(tags: list[str]) -> re.Pattern:
    alternatives = "|".join(re.escape(tag) for tag in sorted(tags, key=len, reverse=True))
    return re.compile(rf"(?<![\w/#&])(?<!\[\[)(?<!\]\()(?<!:)(?<!: )"
                      rf"#(?P<tag>{alternatives})(?P<child>/[^{TAG_STOP_CHARS}]*)?(?=$|[{TAG_STOP_CHARS}])")


def rewrite_body(body: str, renames: dict[str, str], false_tags: set[str]) -> str:
    if not renames and not false_tags:
        return body
    tag_pattern = build_tag_pattern([*renames, *false_tags])

    def replace_tag(match: re.Match) -> str:
        tag, child = match["tag"], match["child"] or ""
        if tag in false_tags:
            return match[0] if child else f"`{match[0]}`"
        return f"#{renames[tag]}{child}"

    rewritten_lines = []
    inside_fence = False
    for line in body.split("\n"):
        if FENCE.match(line):
            inside_fence = not inside_fence
            rewritten_lines.append(line)
            continue
        if inside_fence:
            rewritten_lines.append(line)
            continue
        segments = SKIPPED_SPAN.split(line)
        rewritten_lines.append("".join(segment if index % 2 else tag_pattern.sub(replace_tag, segment)
                                       for index, segment in enumerate(segments)))
    return "\n".join(rewritten_lines)
