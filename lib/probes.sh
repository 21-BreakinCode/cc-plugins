#!/usr/bin/env bash
# Probe system for harness-check — lint, tests, runtime, architecture

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# ---------------------------------------------------------------------------
# ar_probe_detect_tooling
# Scans for config files and returns a JSON object describing detected tools.
# Output: {"lint": <str|null>, "tests": <str|null>, "runtime": <str|null>, "architecture": "static"}
# ---------------------------------------------------------------------------
ar_probe_detect_tooling() {
  python3 - <<'PYEOF'
import json
import os

cwd = os.getcwd()

def exists(*paths):
    return any(os.path.exists(os.path.join(cwd, p)) for p in paths)

def file_contains(path, text):
    full = os.path.join(cwd, path)
    if not os.path.exists(full):
        return False
    try:
        with open(full, 'r', errors='ignore') as f:
            return text in f.read()
    except Exception:
        return False

# --- Lint detection ---
lint = None
if exists('.eslintrc', '.eslintrc.js', '.eslintrc.cjs', '.eslintrc.json',
         '.eslintrc.yaml', '.eslintrc.yml', 'eslint.config.js',
         'eslint.config.mjs', 'eslint.config.cjs'):
    lint = 'eslint'
elif file_contains('pyproject.toml', '[tool.ruff]'):
    lint = 'ruff'
elif exists('.flake8', 'setup.cfg') and file_contains('setup.cfg', '[flake8]'):
    lint = 'flake8'
elif exists('Cargo.toml'):
    lint = 'clippy'
elif exists('.golangci.yml', '.golangci.yaml', '.golangci.json', '.golangci.toml'):
    lint = 'golangci-lint'

# --- Parse package.json once for test + runtime detection ---
pkg = None
pkg_path = os.path.join(cwd, 'package.json')
if os.path.exists(pkg_path):
    try:
        with open(pkg_path, 'r', errors='ignore') as f:
            pkg = json.load(f)
    except Exception:
        pass

# --- Test detection ---
tests = None
if pkg:
    scripts = pkg.get('scripts', {})
    devdeps = pkg.get('devDependencies', {})
    deps = pkg.get('dependencies', {})
    all_deps = {**devdeps, **deps}
    if 'vitest' in all_deps or 'vitest' in str(scripts):
        tests = 'vitest'
    elif 'jest' in all_deps or 'jest' in str(scripts):
        tests = 'jest'

if tests is None:
    if exists('pytest.ini', 'conftest.py') or file_contains('pyproject.toml', '[tool.pytest'):
        tests = 'pytest'
    elif exists('Cargo.toml'):
        tests = 'cargo-test'
    elif exists('go.mod'):
        tests = 'go-test'

# --- Runtime detection ---
runtime = None
if pkg:
    scripts = pkg.get('scripts', {})
    for name in ('dev', 'start', 'serve'):
        if name in scripts:
            runtime = f'npm:{name}'
            break

result = {
    'lint': lint,
    'tests': tests,
    'runtime': runtime,
    'architecture': 'static',
}
print(json.dumps(result))
PYEOF
}

# ---------------------------------------------------------------------------
# _ar_probe_skipped_json <category> <reason>
# Emits a skipped probe JSON object.
# ---------------------------------------------------------------------------
_ar_probe_skipped_json() {
  local category="$1"
  local reason="$2"
  python3 -c "
import json
print(json.dumps({
    'category': '${category}',
    'score': None,
    'max': 100,
    'skipped': True,
    'tool': None,
    'reason': '${reason}',
    'findings': [],
    'fix_targets': [],
    'estimated_iterations': 0,
}))
"
}

# ---------------------------------------------------------------------------
# ar_probe_lint <tool>
# Runs the detected linter, parses output, returns structured JSON.
# ---------------------------------------------------------------------------
ar_probe_lint() {
  local tool="${1:-}"

  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    _ar_probe_skipped_json "lint" "No linter detected"
    return 0
  fi

  local tmpfile
  tmpfile=$(mktemp)
  # Ensure cleanup on all exit paths
  trap "rm -f '${tmpfile}'" RETURN

  case "${tool}" in
    eslint)
      npx eslint --format json . >"${tmpfile}" 2>&1 || true
      ;;
    ruff)
      ruff check --output-format json . >"${tmpfile}" 2>&1 || true
      ;;
    flake8)
      flake8 . >"${tmpfile}" 2>&1 || true
      ;;
    clippy)
      cargo clippy --message-format json 2>&1 | grep '"reason":"compiler-message"' >"${tmpfile}" || true
      ;;
    golangci-lint)
      golangci-lint run --out-format json >"${tmpfile}" 2>&1 || true
      ;;
    *)
      _ar_probe_skipped_json "lint" "Unknown lint tool: ${tool}"
      return 0
      ;;
  esac

  python3 - "${tmpfile}" "${tool}" <<'PYEOF'
import json
import sys
import os

tmpfile = sys.argv[1]
tool = sys.argv[2]

try:
    with open(tmpfile, 'r', errors='ignore') as f:
        raw = f.read().strip()
except Exception as e:
    raw = ''

findings = []
fix_targets = []

try:
    if tool == 'eslint':
        data = json.loads(raw) if raw else []
        for file_result in data:
            filepath = file_result.get('filePath', '')
            for msg in file_result.get('messages', []):
                line = msg.get('line', 0)
                col = msg.get('column', 0)
                text = msg.get('message', '')
                rule = msg.get('ruleId', '')
                findings.append(f'{filepath}:{line}:{col} [{rule}] {text}')
                target = f'{filepath}:{line}'
                if target not in fix_targets:
                    fix_targets.append(target)

    elif tool == 'ruff':
        data = json.loads(raw) if raw else []
        for item in data:
            filepath = item.get('filename', '')
            loc = item.get('location', {})
            line = loc.get('row', 0)
            col = loc.get('column', 0)
            code = item.get('code', '')
            msg = item.get('message', '')
            findings.append(f'{filepath}:{line}:{col} [{code}] {msg}')
            target = f'{filepath}:{line}'
            if target not in fix_targets:
                fix_targets.append(target)

    elif tool == 'flake8':
        # flake8 default output: file:line:col: Ecode message
        for line in raw.splitlines():
            line = line.strip()
            if line:
                findings.append(line)
                parts = line.split(':')
                if len(parts) >= 2:
                    target = f'{parts[0]}:{parts[1]}'
                    if target not in fix_targets:
                        fix_targets.append(target)

    elif tool == 'clippy':
        for line in raw.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                msg_obj = json.loads(line)
                message = msg_obj.get('message', {})
                rendered = message.get('rendered', '')
                spans = message.get('spans', [])
                if rendered:
                    findings.append(rendered.splitlines()[0])
                for span in spans:
                    fname = span.get('file_name', '')
                    lnum = span.get('line_start', 0)
                    if fname:
                        target = f'{fname}:{lnum}'
                        if target not in fix_targets:
                            fix_targets.append(target)
            except json.JSONDecodeError:
                pass

    elif tool == 'golangci-lint':
        data = json.loads(raw) if raw else {}
        issues = data.get('Issues', []) or []
        for issue in issues:
            text = issue.get('Text', '')
            from_linter = issue.get('FromLinter', '')
            pos = issue.get('Pos', {})
            fname = pos.get('Filename', '')
            line = pos.get('Line', 0)
            findings.append(f'{fname}:{line} [{from_linter}] {text}')
            target = f'{fname}:{line}'
            if target not in fix_targets:
                fix_targets.append(target)

except Exception:
    pass

count = len(findings)
score = max(0, min(100, 100 - count * 5))
estimated_iterations = max(0, count // 5) if count > 0 else 0

result = {
    'category': 'lint',
    'score': score,
    'max': 100,
    'skipped': False,
    'tool': tool,
    'findings': findings[:50],  # cap to avoid huge output
    'fix_targets': fix_targets[:50],
    'estimated_iterations': estimated_iterations,
}
print(json.dumps(result))
PYEOF
}

# ---------------------------------------------------------------------------
# ar_probe_tests <tool>
# Runs detected test runner, parses coverage + failures, returns structured JSON.
# ---------------------------------------------------------------------------
ar_probe_tests() {
  local tool="${1:-}"

  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    _ar_probe_skipped_json "tests" "No test runner detected"
    return 0
  fi

  local tmpfile
  tmpfile=$(mktemp)
  trap "rm -f '${tmpfile}'" RETURN

  case "${tool}" in
    jest)
      npx jest --coverage --json >"${tmpfile}" 2>&1 || true
      ;;
    vitest)
      npx vitest run --coverage --reporter json >"${tmpfile}" 2>&1 || true
      ;;
    pytest)
      python3 -m pytest --tb=short -q --json-report --json-report-file="${tmpfile}" 2>&1 || true
      ;;
    cargo-test)
      cargo test 2>&1 >"${tmpfile}" || true
      ;;
    go-test)
      go test ./... -v 2>&1 >"${tmpfile}" || true
      ;;
    *)
      _ar_probe_skipped_json "tests" "Unknown test tool: ${tool}"
      return 0
      ;;
  esac

  python3 - "${tmpfile}" "${tool}" <<'PYEOF'
import json
import sys
import re

tmpfile = sys.argv[1]
tool = sys.argv[2]

try:
    with open(tmpfile, 'r', errors='ignore') as f:
        raw = f.read().strip()
except Exception:
    raw = ''

failures = []
coverage_gaps = []
fix_targets = []

try:
    if tool == 'jest':
        data = json.loads(raw) if raw else {}
        test_results = data.get('testResults', [])
        for suite in test_results:
            for assertion in suite.get('testResults', []):
                if assertion.get('status') == 'failed':
                    name = assertion.get('fullName', assertion.get('title', ''))
                    failures.append(name)
                    fname = suite.get('testFilePath', '')
                    if fname and fname not in fix_targets:
                        fix_targets.append(fname)
        # coverage gaps: files below threshold
        coverage = data.get('coverageMap', {})
        for fpath, cov in coverage.items():
            stmts = cov.get('s', {})
            total = len(stmts)
            if total > 0:
                covered = sum(1 for v in stmts.values() if v > 0)
                pct = covered / total * 100
                if pct < 80:
                    coverage_gaps.append(f'{fpath}: {pct:.0f}% statement coverage')
                    if fpath not in fix_targets:
                        fix_targets.append(fpath)

    elif tool == 'vitest':
        # vitest JSON reporter varies; try to parse common fields
        data = json.loads(raw) if raw else {}
        test_results = data.get('testResults', data.get('results', []))
        for suite in test_results:
            for test in suite.get('assertionResults', suite.get('tests', [])):
                if test.get('status') in ('failed', 'fail'):
                    name = test.get('fullName', test.get('name', ''))
                    failures.append(name)
                    fname = suite.get('testFilePath', suite.get('filepath', ''))
                    if fname and fname not in fix_targets:
                        fix_targets.append(fname)

    elif tool == 'pytest':
        data = json.loads(raw) if raw else {}
        for test in data.get('tests', []):
            if test.get('outcome') in ('failed', 'error'):
                name = test.get('nodeid', '')
                failures.append(name)
                # nodeid format: path::test_name
                fpath = name.split('::')[0] if '::' in name else ''
                if fpath and fpath not in fix_targets:
                    fix_targets.append(fpath)

    elif tool in ('cargo-test', 'go-test'):
        # Parse plain text output for FAILED lines
        for line in raw.splitlines():
            if 'FAILED' in line or '--- FAIL' in line:
                failures.append(line.strip())

except Exception:
    pass

fail_count = len(failures)
gap_count = len(coverage_gaps)
score = max(0, min(100, 100 - fail_count * 15 - gap_count * 5))
estimated_iterations = fail_count + gap_count

findings = failures + coverage_gaps

result = {
    'category': 'tests',
    'score': score,
    'max': 100,
    'skipped': False,
    'tool': tool,
    'findings': findings[:50],
    'fix_targets': fix_targets[:50],
    'estimated_iterations': estimated_iterations,
}
print(json.dumps(result))
PYEOF
}

# ---------------------------------------------------------------------------
# ar_probe_runtime <tool>
# Starts the dev server, waits up to 15s, curls common endpoints, scores.
# Tool format: "npm:scriptname"
# ---------------------------------------------------------------------------
ar_probe_runtime() {
  local tool="${1:-}"

  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    _ar_probe_skipped_json "runtime" "No runtime script detected"
    return 0
  fi

  # Parse tool format "npm:scriptname"
  local manager script_name
  manager="${tool%%:*}"
  script_name="${tool##*:}"

  if [ "${manager}" != "npm" ]; then
    _ar_probe_skipped_json "runtime" "Unsupported runtime manager: ${manager}"
    return 0
  fi

  ar_log "Starting dev server: ${manager} run ${script_name}"

  # Start the server in background, redirect output to a temp log
  local server_log server_pid
  server_log=$(mktemp)
  npm run "${script_name}" >"${server_log}" 2>&1 &
  server_pid=$!

  # Temp files tracked for cleanup
  local _runtime_tmpfiles="${server_log}"

  # Ensure server is killed and temp files removed on all exit paths
  _ar_probe_runtime_cleanup() {
    kill "${server_pid}" 2>/dev/null || true
    rm -f ${_runtime_tmpfiles}
  }
  trap "_ar_probe_runtime_cleanup" RETURN

  # Wait up to 15 seconds for the server to start
  local port=3000
  local waited=0
  local started=false
  while [ "${waited}" -lt 15 ]; do
    if curl -s --max-time 1 "http://localhost:${port}/" >/dev/null 2>&1; then
      started=true
      break
    fi
    sleep 1
    waited=$((waited + 1))
    # Check if process died early
    if ! kill -0 "${server_pid}" 2>/dev/null; then
      break
    fi
  done

  if [ "${started}" = "false" ]; then
    kill "${server_pid}" 2>/dev/null || true
    python3 -c "
import json
print(json.dumps({
    'category': 'runtime',
    'score': 20,
    'max': 100,
    'skipped': False,
    'tool': '${tool}',
    'findings': ['Server failed to start within 15 seconds'],
    'fix_targets': ['package.json'],
    'estimated_iterations': 2,
}))
"
    return 0
  fi

  ar_log "Server started, probing endpoints"

  # Probe common endpoints
  local endpoints="/ /health /api /api/health"
  local five_hundreds=0
  local findings=()
  local fix_targets=()

  for ep in ${endpoints}; do
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://localhost:${port}${ep}" 2>/dev/null || echo "000")
    if [ "${http_code}" = "500" ] || [ "${http_code}" = "502" ] || [ "${http_code}" = "503" ]; then
      five_hundreds=$((five_hundreds + 1))
      findings+=("Endpoint ${ep} returned ${http_code}")
      fix_targets+=("${ep}")
    fi
  done

  kill "${server_pid}" 2>/dev/null || true

  # Write findings to a temp file so Python can read them safely
  local findings_file
  findings_file=$(mktemp)
  _runtime_tmpfiles="${_runtime_tmpfiles} ${findings_file}"
  # Build a JSON array of findings and fix_targets via Python to avoid quoting hazards
  {
    printf '['
    local first=true
    for item in "${findings[@]+"${findings[@]}"}"; do
      [ "${first}" = "true" ] || printf ','
      python3 -c "import json,sys; print(json.dumps(sys.argv[1]), end='')" "${item}"
      first=false
    done
    printf ']'
  } > "${findings_file}"

  local fix_targets_file
  fix_targets_file=$(mktemp)
  _runtime_tmpfiles="${_runtime_tmpfiles} ${fix_targets_file}"
  {
    printf '['
    local first2=true
    for item in "${fix_targets[@]+"${fix_targets[@]}"}"; do
      [ "${first2}" = "true" ] || printf ','
      python3 -c "import json,sys; print(json.dumps(sys.argv[1]), end='')" "${item}"
      first2=false
    done
    printf ']'
  } > "${fix_targets_file}"

  local score
  score=$(python3 -c "print(max(0, min(100, 100 - ${five_hundreds} * 20)))")
  local estimated_iterations
  estimated_iterations=$((five_hundreds * 2))

  python3 - "${findings_file}" "${fix_targets_file}" "${score}" "${estimated_iterations}" "${tool}" <<'PYEOF'
import json
import sys

with open(sys.argv[1], 'r') as f:
    findings_list = json.load(f)
with open(sys.argv[2], 'r') as f:
    fix_targets_list = json.load(f)

score = int(sys.argv[3])
estimated_iterations = int(sys.argv[4])
tool = sys.argv[5]

print(json.dumps({
    'category': 'runtime',
    'score': score,
    'max': 100,
    'skipped': False,
    'tool': tool,
    'findings': findings_list,
    'fix_targets': fix_targets_list,
    'estimated_iterations': estimated_iterations,
}))
PYEOF

}

# ---------------------------------------------------------------------------
# ar_probe_architecture <tool>
# Pure Python static analysis: oversized files + circular deps via madge.
# ---------------------------------------------------------------------------
ar_probe_architecture() {
  local tool="${1:-}"
  # tool is always "static" for architecture; we accept any value (or null)

  python3 - <<'PYEOF'
import json
import os
import subprocess
import sys

cwd = os.getcwd()

SRC_EXTENSIONS = {'.js', '.ts', '.jsx', '.tsx', '.mjs', '.cjs',
                  '.py', '.go', '.rs', '.java', '.rb', '.php',
                  '.c', '.cpp', '.h', '.hpp', '.cs', '.swift', '.kt'}
MAX_LINES = 800
PENALTY_OVERSIZED = 10
PENALTY_CIRCULAR = 15

findings = []
fix_targets = []
js_ts_present = False

JS_TS_EXTENSIONS = {'.js', '.ts', '.jsx', '.tsx', '.mjs', '.cjs'}

# --- Single walk: oversized files + JS/TS detection ---
for dirpath, dirnames, filenames in os.walk(cwd):
    dirnames[:] = [
        d for d in dirnames
        if not d.startswith('.')
        and d not in ('node_modules', '__pycache__', 'vendor', 'dist', 'build', '.git')
    ]
    for fname in filenames:
        ext = os.path.splitext(fname)[1].lower()
        if ext in JS_TS_EXTENSIONS:
            js_ts_present = True
        if ext not in SRC_EXTENSIONS:
            continue
        fpath = os.path.join(dirpath, fname)
        try:
            with open(fpath, 'r', errors='ignore') as f:
                lines = sum(1 for _ in f)
            if lines > MAX_LINES:
                rel = os.path.relpath(fpath, cwd)
                findings.append(f'{rel}: {lines} lines (>{MAX_LINES})')
                if rel not in fix_targets:
                    fix_targets.append(rel)
        except Exception:
            pass

oversized_count = len(findings)

# --- Circular dependency detection (JS/TS only) ---
circular_count = 0

if js_ts_present:
    try:
        result = subprocess.run(
            ['npx', 'madge', '--circular', '--json', '.'],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=cwd,
        )
        if result.returncode == 0 and result.stdout.strip():
            try:
                circles = json.loads(result.stdout.strip())
                for cycle in circles:
                    cycle_str = ' -> '.join(cycle)
                    findings.append(f'Circular dep: {cycle_str}')
                    for node in cycle:
                        if node not in fix_targets:
                            fix_targets.append(node)
                circular_count = len(circles)
            except json.JSONDecodeError:
                pass
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

score = max(0, min(100, 100 - oversized_count * PENALTY_OVERSIZED - circular_count * PENALTY_CIRCULAR))
estimated_iterations = oversized_count + circular_count * 3

result = {
    'category': 'architecture',
    'score': score,
    'max': 100,
    'skipped': False,
    'tool': 'static',
    'findings': findings[:50],
    'fix_targets': fix_targets[:50],
    'estimated_iterations': estimated_iterations,
}
print(json.dumps(result))
PYEOF
}

# ---------------------------------------------------------------------------
# ar_probe_run_all
# Orchestrates all probes and combines results into a single JSON object
# keyed by category.
# ---------------------------------------------------------------------------
ar_probe_run_all() {
  ar_log "Detecting tooling..."
  local tooling_json
  tooling_json=$(ar_probe_detect_tooling)

  # Extract all tool names in a single python3 call
  local tool_values
  tool_values=$(python3 -c "
import json
d = json.loads('''${tooling_json}''')
print(d.get('lint') or 'null')
print(d.get('tests') or 'null')
print(d.get('runtime') or 'null')
")
  local lint_tool tests_tool runtime_tool
  lint_tool=$(echo "${tool_values}" | sed -n '1p')
  tests_tool=$(echo "${tool_values}" | sed -n '2p')
  runtime_tool=$(echo "${tool_values}" | sed -n '3p')

  ar_log "Running lint probe (tool=${lint_tool})..."
  local lint_json
  lint_json=$(ar_probe_lint "${lint_tool}")

  ar_log "Running tests probe (tool=${tests_tool})..."
  local tests_json
  tests_json=$(ar_probe_tests "${tests_tool}")

  ar_log "Running runtime probe (tool=${runtime_tool})..."
  local runtime_json
  runtime_json=$(ar_probe_runtime "${runtime_tool}")

  ar_log "Running architecture probe..."
  local arch_json
  arch_json=$(ar_probe_architecture "static")

  ar_log "Combining probe results..."
  local combine_tmpfile
  combine_tmpfile=$(mktemp)
  printf '%s\n%s\n%s\n%s' "${lint_json}" "${tests_json}" "${runtime_json}" "${arch_json}" > "${combine_tmpfile}"

  python3 - "${combine_tmpfile}" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f:
    lines = f.read().strip().split('\n')

result = {}
for line in lines:
    try:
        data = json.loads(line)
        result[data["category"]] = data
    except (json.JSONDecodeError, KeyError):
        pass

print(json.dumps(result, indent=2))
PYEOF

  rm -f "${combine_tmpfile}"
}
