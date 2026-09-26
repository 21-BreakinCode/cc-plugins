"""Export an Excalidraw drawing to PNG so a model can look at the real render.

Usage: python3 render.py <vault-relative .excalidraw.md> <output.png> [--theme dark|light] [--scale 1]
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from ea_bridge import ObsidianBridgeError, run_ea_script  # noqa: E402

EXPORT_PNG_JS = """
const file = app.vault.getAbstractFileByPath(args.drawingPath);
if (!file) throw new Error('drawing not found: ' + args.drawingPath);
const dataUrl = await ea.createPNGBase64(file.path, args.scale,
  {withBackground: true, withTheme: true}, null, args.theme);
require('fs').writeFileSync(args.outputPath, Buffer.from(dataUrl.split(',')[1], 'base64'));
return args.outputPath;
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("drawing_path")
    parser.add_argument("output_png")
    parser.add_argument("--theme", default="dark", choices=["dark", "light"])
    parser.add_argument("--scale", type=float, default=1)
    cli = parser.parse_args()

    output_path = str(Path(cli.output_png).resolve())
    try:
        written = run_ea_script(EXPORT_PNG_JS, {
            "drawingPath": cli.drawing_path, "outputPath": output_path,
            "theme": cli.theme, "scale": cli.scale,
        })
    except ObsidianBridgeError as bridge_error:
        print(f"render failed: {bridge_error}", file=sys.stderr)
        return 1
    print(written)
    return 0


if __name__ == "__main__":
    sys.exit(main())
