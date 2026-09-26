"""Split a note into frontmatter and body, and read one frontmatter property."""
import re

FRONTMATTER_OPEN = "---\n"
FRONTMATTER_CLOSE = "\n---\n"


def split_frontmatter(text: str) -> tuple[str, str]:
    if text.startswith(FRONTMATTER_OPEN):
        close_at = text.find(FRONTMATTER_CLOSE, len(FRONTMATTER_OPEN) - 1)
        if close_at != -1:
            body_start = close_at + len(FRONTMATTER_CLOSE)
            return text[:body_start], text[body_start:]
    return "", text


def read_property(frontmatter: str, key: str) -> str | None:
    match = re.search(rf"^{re.escape(key)}:[ \t]*(.*)$", frontmatter, re.MULTILINE)
    return match.group(1).strip() if match else None
