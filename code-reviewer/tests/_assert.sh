#!/usr/bin/env bash
# Shared assert helper for code-reviewer bash tests.
PASS=0; FAIL=0
assert() {  # <label> <condition-string>
  if eval "$2"; then echo "  PASS  $1"; PASS=$((PASS+1))
  else echo "  FAIL  $1 (cond: $2)"; FAIL=$((FAIL+1)); fi
}
finish() { echo ""; echo "Passed: $PASS  Failed: $FAIL"; [ "$FAIL" -eq 0 ]; }
