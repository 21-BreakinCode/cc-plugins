"""Self-check for session-primer.py: python3 test_session_primer.py"""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

PRIMER_SCRIPT = Path(__file__).resolve().parent / "session-primer.py"


def run_primer(cwd: Path) -> str:
    completed = subprocess.run([sys.executable, str(PRIMER_SCRIPT)], input=json.dumps({"cwd": str(cwd)}),
                               capture_output=True, text=True, check=True)
    return completed.stdout


with tempfile.TemporaryDirectory() as temp:
    project = Path(temp)
    assert run_primer(project) == ""
    (project / ".obsidian").mkdir()
    context = json.loads(run_primer(project))["hookSpecificOutput"]
    assert context["hookEventName"] == "SessionStart"
    assert "obsidian help <cmd>" in context["additionalContext"]
    assert "defuddle parse <url> --md" in context["additionalContext"]

print("test_session_primer: all passed")
