"""Self-check for migrate.py: python3 test_migrate.py"""
import tempfile
from pathlib import Path

from migrate import build_rows, collect_notes, is_already_moved

TYPE_FOLDERS = {"Z/Literature": "literature"}

rows = {row["path"]: row for row in build_rows(
    ["Z/Literature/Go/_index.md", "Z/Literature/Go/01__a.md", "Z/Literature/Habits/原子習慣 MOC.md",
     "Z/Literature/Old/00__map__Old.md", "L/0796.__rotate.md"],
    existing_paths={"Z/Literature/Habits/00__map__Habits.md"}, type_folders=TYPE_FOLDERS)}
assert rows["Z/Literature/Go/_index.md"] == {
    "path": "Z/Literature/Go/_index.md", "note_type": "map", "rule": "map-name",
    "new_path": "Z/Literature/Go/00__map__Go.md"}
assert rows["Z/Literature/Go/01__a.md"]["note_type"] == "takeaway"
# The target exists, so no rename is proposed.
assert rows["Z/Literature/Habits/原子習慣 MOC.md"]["new_path"] == ""
assert rows["Z/Literature/Habits/原子習慣 MOC.md"]["rule"] == "map-name (rename target exists)"
# An already-correct map name is not renamed.
assert rows["Z/Literature/Old/00__map__Old.md"]["new_path"] == ""
assert rows["L/0796.__rotate.md"]["note_type"] == ""

# A map directly in a type folder (not a series folder) keeps its name.
type_root_rows = build_rows(["Z/Literature/connecting__index.md"], set(), TYPE_FOLDERS)
assert type_root_rows[0]["note_type"] == "map"
assert type_root_rows[0]["new_path"] == ""
assert type_root_rows[0]["rule"] == "map-name (type folder, no rename)"

# I4: two maps in the same folder must not both claim the same rename target.
same_folder_rows = build_rows(["Z/Series/_index.md", "Z/Series/Series MOC.md"], set(), {})
assert sum(1 for row in same_folder_rows if row["new_path"] == "Z/Series/00__map__Series.md") == 1

with tempfile.TemporaryDirectory() as temp:
    vault_root = Path(temp)
    for relative_path, text in {
        "Z/a.md": "#x\n## A\n",
        "Z/typed.md": "---\nnote-type: concept\n---\n#x\n",
        "Z/drawing.md": "---\nexcalidraw-plugin: parsed\n---\n",
        "Z/Credentials/secret.md": "never read",
        "Journal/2026-09-26.md": "#daily\n",
    }.items():
        (vault_root / relative_path).parent.mkdir(parents=True, exist_ok=True)
        (vault_root / relative_path).write_text(text, encoding="utf-8")
    (vault_root / "Z/Credentials/secret.md").chmod(0)  # reading it would raise PermissionError
    config = {"noteFormatFolders": ["Z"], "excludedPaths": ["Z/Credentials"], "typeFolders": {}}
    assert collect_notes(vault_root, config) == ["Z/a.md"]
    (vault_root / "Z/Credentials/secret.md").chmod(0o600)

# I5: a re-run after a partial failure treats an already-moved row as done.
with tempfile.TemporaryDirectory() as temp:
    vault_root = Path(temp)
    (vault_root / "Z").mkdir()
    (vault_root / "Z/00__map__Series.md").write_text("moved already", encoding="utf-8")
    moved_row = {"path": "Z/_index.md", "new_path": "Z/00__map__Series.md"}
    assert is_already_moved(vault_root, moved_row)
    (vault_root / "Z/_index.md").write_text("not moved yet", encoding="utf-8")
    assert not is_already_moved(vault_root, moved_row)
    assert not is_already_moved(vault_root, {"path": "Z/_index.md", "new_path": ""})

print("test_migrate: all passed")
