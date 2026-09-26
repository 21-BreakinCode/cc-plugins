"""Check notes against their note-type format.

Usage (from the vault root): python3 check_note.py <vault-relative path or folder>
Exit 0 = all pass, 2 = some notes fail, 1 = could not run.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common.note_text import read_property, split_frontmatter  # noqa: E402
from common.vault import VaultConfigError, find_vault_root, is_in_scope, load_config  # noqa: E402

ONE_SCREEN_LINES = 45
TAG_LINE = re.compile(r"^#[^\s#]")
TITLE_LINE = re.compile(r"^#{1,2} \S")
# The claim may sit in a quote or a callout: "> **x**", "> [!danger] **x**".
BOLD_CLAIM = re.compile(r"^(>\s*(\[![\w-]+\]\s*)?)?\*\*.+\*\*")
FENCED_BLOCK = re.compile(r"^```", re.MULTILINE)
LITERATURE_SOURCE = re.compile(r"^(> Link: https?://|> Source: \S|Sources?: \S)", re.MULTILINE)
SESSION_CALLOUT = "> [!example] From this session"
ONE_SCREEN_TYPES = {"concept", "takeaway"}
CLAIM_TYPES = {"map", "concept", "takeaway", "literature"}
RELATED_TYPES = {"concept", "takeaway"}


def check_note(note_type: str, file_name: str, text: str, keep_map_name: bool = False,
               in_mapped_series: bool = False) -> list[str]:
    frontmatter, body = split_frontmatter(text)
    body_lines = body.strip("\n").split("\n")
    failures = []
    if read_property(frontmatter, "note-type") is None:
        failures.append("missing note-type property")
    if not TAG_LINE.match(body_lines[0]):
        failures.append("line 1 is not a tag line")
    if not any(TITLE_LINE.match(line) for line in body_lines):
        failures.append("missing # or ## title")
    if note_type in CLAIM_TYPES and not any(BOLD_CLAIM.match(line) for line in body_lines):
        failures.append("missing bold one-sentence claim")
    if note_type in ONE_SCREEN_TYPES and len(body_lines) > ONE_SCREEN_LINES:
        failures.append(f"over one screen: {len(body_lines)} lines > {ONE_SCREEN_LINES}")
    if note_type in RELATED_TYPES:
        if "Related:" not in body:
            failures.append("missing Related:")
    if note_type == "takeaway":
        if SESSION_CALLOUT not in body:
            failures.append(f"missing {SESSION_CALLOUT}")
        if "[[00__map__" not in body:
            failures.append("missing link back to the map")
    if note_type == "map":
        if not keep_map_name and not file_name.startswith("00__map__"):
            failures.append("name must start with 00__map__")
        if not FENCED_BLOCK.search(body):
            failures.append("missing overview diagram")
        if "[[" not in body:
            failures.append("missing ordered [[links]]")
    # In a series, the 00__map__ note names the source for every note beside it.
    if note_type == "literature" and not in_mapped_series and not LITERATURE_SOURCE.search(body):
        failures.append("missing > Link: <url> or > Source: <name>")
    return failures


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    try:
        vault_root = find_vault_root(Path.cwd())
        config = load_config(vault_root)
    except VaultConfigError as config_error:
        print(config_error, file=sys.stderr)
        return 1
    target = vault_root / sys.argv[1]
    notes = sorted(target.rglob("*.md")) if target.is_dir() else [target]
    failing_count = 0
    for note in notes:
        relative_path = note.relative_to(vault_root).as_posix()
        if not is_in_scope(relative_path, config):
            continue
        text = note.read_text(encoding="utf-8")
        frontmatter = split_frontmatter(text)[0]
        if read_property(frontmatter, "excalidraw-plugin"):
            continue
        note_type = read_property(frontmatter, "note-type")
        if note_type is None:
            print(f"{relative_path}\tunset note-type (run /obsidian-kit:migrate-notes)")
            failing_count += 1
            continue
        is_type_folder = note.parent.relative_to(vault_root).as_posix() in config["typeFolders"]
        in_mapped_series = any(sibling.name.startswith("00__map__") for sibling in note.parent.glob("*.md"))
        failures = check_note(note_type, note.name, text, keep_map_name=is_type_folder,
                              in_mapped_series=in_mapped_series)
        if failures:
            failing_count += 1
            print(f"{relative_path}\t{note_type}\t" + "; ".join(failures))
    print(f"{failing_count} of {len(notes)} notes fail")
    return 2 if failing_count else 0


if __name__ == "__main__":
    sys.exit(main())
