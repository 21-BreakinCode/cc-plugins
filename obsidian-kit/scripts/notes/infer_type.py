"""Infer a note's note-type from its name, its siblings, and the configured type folders."""
import re
from pathlib import PurePosixPath

MAP_PREFIX = "00__map__"
MAP_NAME = re.compile(r"^(00__map__.*|_index.*|.*__index|.*MOC.*|.*MoC.*)\.md$")
NUMBERED_NAME = re.compile(r"^\d{2}__.+\.md$")


def infer_type(path: str, sibling_names: set[str], type_folders: dict[str, str]) -> tuple[str | None, str]:
    file_name = PurePosixPath(path).name
    if MAP_NAME.match(file_name):
        return "map", "map-name"
    has_map_sibling = any(MAP_NAME.match(sibling) for sibling in sibling_names if sibling != file_name)
    if NUMBERED_NAME.match(file_name) and has_map_sibling:
        return "takeaway", "numbered-with-map"
    for folder, note_type in type_folders.items():
        if path.startswith(folder.rstrip("/") + "/"):
            return note_type, f"folder:{folder}"
    return None, "unmatched"
