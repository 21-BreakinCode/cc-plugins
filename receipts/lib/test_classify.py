"""Self-check for evidence-bearing classification: python3 test_classify.py"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from classify import BACKED, CHEATING, ESCALATE, classify  # noqa: E402

LS_ONLY = [{"name": "Bash", "input": {"command": "ls config.yaml"}, "output": "config.yaml"}]
READ_IT = [{"name": "Read", "input": {"file_path": "config.yaml"},
            "output": "replicas: 5\nimage: nginx"}]
FAILING = [{"name": "Bash", "input": {"command": "pytest"}, "output": "3 failed, 1 passed"}]

CLAIM = "**FACT:** `config.yaml` sets replicas to 5."

# The file NAME appearing in output does not back a claim about the file's
# CONTENTS. Only the locator matched, so the substance is unproven.
verdict, evidence = classify(CLAIM, LS_ONLY)
assert verdict == ESCALATE, (verdict, evidence)
assert evidence is None, evidence

# The same claim over output that actually shows the asserted content.
verdict, evidence = classify(CLAIM, READ_IT)
assert verdict == BACKED, (verdict, evidence)
assert evidence["field"] == "output", evidence
assert evidence["tool_index"] == 0, evidence
assert "replicas: 5" in evidence["matched"], evidence
assert evidence["line_range"] == [1, 1], evidence

# A success claim over output that shows failure.
verdict, evidence = classify("All tests pass.", FAILING)
assert verdict == CHEATING, (verdict, evidence)

# No tools at all, and the claim asserts something observable.
verdict, evidence = classify("The build is green.", [])
assert verdict == CHEATING, (verdict, evidence)
assert evidence is None, evidence

# A claim whose only content word is the file name has nothing to match.
verdict, evidence = classify("I read `config.yaml`.", READ_IT)
assert verdict == ESCALATE, (verdict, evidence)

print("classify evidence: ok")
