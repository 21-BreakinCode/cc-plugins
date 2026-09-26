"""Self-check for migrate.py: python3 test_migrate.py"""
import tempfile
from pathlib import Path

from migrate import build_rows, collect_notes

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

print("test_migrate: all passed")
