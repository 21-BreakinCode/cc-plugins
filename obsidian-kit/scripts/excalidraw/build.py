"""Build an Excalidraw drawing from a layout script that uses the style kit.

Usage: python3 build.py <layout.js> <vault-relative drawing .md> [--overwrite]

The layout script runs with `ea` (ExcalidrawAutomate) and `kit` (style_kit.js) in scope,
may use `await`, and must not call ea.create itself. --overwrite moves an existing drawing
to the system trash first (recoverable), because the vault has no version control.
"""
import argparse
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from ea_bridge import ObsidianBridgeError, run_ea_script  # noqa: E402

DARK_THEME = 1
DRAWING_SUFFIX = ".md"
KIT_FILES = ("style_kit.js", "style_kit_diagrams.js")

CREATE_DRAWING_JS = """
const existing = app.vault.getAbstractFileByPath(args.drawingPath);
if (existing && !args.overwrite) throw new Error('drawing exists, pass --overwrite: ' + args.drawingPath);
if (existing) await app.vault.trash(existing, true);
ea.reset();
ea.setTheme(args.theme);
%(kit)s
await (async () => { %(layout)s })();
kit.placeLabels();
const created = await ea.create({filename: args.fileName, foldername: args.folder, onNewPane: false, silent: true});
return {path: typeof created === 'string' ? created : created.path, elements: ea.getElements().length};
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("layout_js")
    parser.add_argument("drawing_path")
    parser.add_argument("--overwrite", action="store_true")
    cli = parser.parse_args()

    if not cli.drawing_path.endswith(DRAWING_SUFFIX):
        print(f"drawing path must end with {DRAWING_SUFFIX}", file=sys.stderr)
        return 1
    layout_js = Path(cli.layout_js).read_text(encoding="utf-8")
    if "ea.create(" in layout_js:
        print("layout script must not call ea.create; build.py saves the drawing", file=sys.stderr)
        return 1

    drawing = Path(cli.drawing_path)
    kit_js = "\n".join((SCRIPT_DIR / name).read_text(encoding="utf-8") for name in KIT_FILES)
    js_body = CREATE_DRAWING_JS % {"kit": kit_js, "layout": layout_js}
    try:
        result = run_ea_script(js_body, {
            "drawingPath": cli.drawing_path, "overwrite": cli.overwrite, "theme": DARK_THEME,
            "folder": str(drawing.parent), "fileName": drawing.name,
        })
    except ObsidianBridgeError as bridge_error:
        print(f"build failed: {bridge_error}", file=sys.stderr)
        return 1
    print(f"built {result['path']} ({result['elements']} elements)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
