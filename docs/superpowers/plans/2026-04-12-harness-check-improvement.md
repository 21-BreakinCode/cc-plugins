# Harness Check & Harness Improvement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new slash commands (`/autoresearch:harness-check` and `/autoresearch:harness-improvement`) that auto-discover project health metrics via probes and execute improvement loops without manual configuration.

**Architecture:** Probe-based discovery in `lib/probes.sh` + scoring/ranking in `lib/harness.sh`. `harness-check` runs probes and writes `.autoresearch/harness.json`. `harness-improvement` reads that file, auto-generates `program.md`, and spawns the existing experimenter agent.

**Tech Stack:** Bash (shell libraries), Python3 (JSON manipulation, scoring), existing autoresearch experimenter agent + dashboard

**Spec:** `docs/superpowers/specs/2026-04-12-harness-check-improvement-design.md`

---

## File Map

```
autoresearch/
├── lib/
│   ├── common.sh               # MODIFY — add AR_HARNESS_FILE constant
│   ├── probes.sh               # CREATE — probe detection + execution functions
│   └── harness.sh              # CREATE — harness.json management + scoring + scorecard
├── commands/
│   ├── harness-check.md        # CREATE — /autoresearch:harness-check command
│   └── harness-improvement.md  # CREATE — /autoresearch:harness-improvement command
└── skills/
    └── harness-probes/
        └── SKILL.md            # CREATE — probe authoring guide for adding custom probes
```

---

### Task 1: Add AR_HARNESS_FILE constant to common.sh

**Files:**
- Modify: `autoresearch/lib/common.sh:7-10`

- [ ] **Step 1: Add the constant**

Add `AR_HARNESS_FILE` after the existing constants on line 10:

```bash
AR_HARNESS_FILE="${AR_AUTORESEARCH_DIR}/harness.json"
```

This goes right after `AR_PROGRAM_FILE` (line 10), before the plugin root section.

- [ ] **Step 2: Verify the file sources correctly**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/common.sh && echo "AR_HARNESS_FILE=${AR_HARNESS_FILE}"
```

Expected: `AR_HARNESS_FILE=.autoresearch/harness.json`

- [ ] **Step 3: Commit**

```bash
git add autoresearch/lib/common.sh
git commit -m "feat: add AR_HARNESS_FILE constant to common.sh"
```

---

### Task 2: Create lib/probes.sh — tooling detection

**Files:**
- Create: `autoresearch/lib/probes.sh`
- Test: manual verification via sourcing

- [ ] **Step 1: Create the file with header and tooling detection**

```bash
#!/usr/bin/env bash
# Probe system for autoresearch harness-check
# Each probe detects tooling, runs checks, and returns structured JSON.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Detect which probes are available for this project
# Prints JSON: {"lint": "eslint", "tests": "jest", "runtime": "npm", "architecture": "static"}
# A value of null means the probe should be skipped.
ar_probe_detect_tooling() {
  local lint="null"
  local tests="null"
  local runtime="null"
  local architecture="\"static\""

  # Lint detection
  if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    lint="\"eslint\""
  elif [ -f "pyproject.toml" ] && grep -q '\[tool\.ruff\]' pyproject.toml 2>/dev/null; then
    lint="\"ruff\""
  elif [ -f ".flake8" ] || ([ -f "setup.cfg" ] && grep -q '\[flake8\]' setup.cfg 2>/dev/null); then
    lint="\"flake8\""
  elif [ -f "Cargo.toml" ]; then
    lint="\"clippy\""
  elif [ -f ".golangci.yml" ] || [ -f ".golangci.yaml" ]; then
    lint="\"golangci-lint\""
  fi

  # Test runner detection
  if [ -f "package.json" ] && grep -q '"jest"' package.json 2>/dev/null; then
    tests="\"jest\""
  elif [ -f "package.json" ] && grep -q '"vitest"' package.json 2>/dev/null; then
    tests="\"vitest\""
  elif [ -f "pyproject.toml" ] || [ -f "pytest.ini" ] || [ -f "setup.cfg" ]; then
    if command -v pytest &>/dev/null; then
      tests="\"pytest\""
    fi
  elif [ -f "Cargo.toml" ]; then
    tests="\"cargo-test\""
  elif [ -f "go.mod" ]; then
    tests="\"go-test\""
  fi

  # Runtime detection (needs a dev server command)
  if [ -f "package.json" ]; then
    local dev_script
    dev_script=$(python3 -c "
import json
with open('package.json') as f:
    pkg = json.load(f)
scripts = pkg.get('scripts', {})
for key in ['dev', 'start', 'serve']:
    if key in scripts:
        print(key)
        break
" 2>/dev/null)
    if [ -n "${dev_script}" ]; then
      runtime="\"npm:${dev_script}\""
    fi
  fi

  # Architecture is always available (static analysis)
  cat <<AREOF
{"lint": ${lint}, "tests": ${tests}, "runtime": ${runtime}, "architecture": ${architecture}}
AREOF
}
```

- [ ] **Step 2: Verify detection works in a sample project**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/probes.sh
cd /tmp && mkdir -p probe-test && cd probe-test
echo '{"scripts":{"dev":"vite"},"devDependencies":{"eslint":"^8.0.0","vitest":"^1.0.0"}}' > package.json
touch eslint.config.js
ar_probe_detect_tooling
rm -rf /tmp/probe-test
```

Expected: `{"lint": "eslint", "tests": "vitest", "runtime": "npm:dev", "architecture": "static"}`

- [ ] **Step 3: Commit**

```bash
git add autoresearch/lib/probes.sh
git commit -m "feat: add probe tooling detection in lib/probes.sh"
```

---

### Task 3: Create lib/probes.sh — lint probe

**Files:**
- Modify: `autoresearch/lib/probes.sh`

- [ ] **Step 1: Add the lint probe function**

Append to `probes.sh`:

```bash
# Calculate score from finding count: 100 - (findings * penalty), clamped to 0
_ar_probe_calc_score() {
  local findings_count="$1"
  local penalty_per_finding="${2:-5}"
  local score=$((100 - findings_count * penalty_per_finding))
  if [ "${score}" -lt 0 ]; then score=0; fi
  echo "${score}"
}

# Lint probe: run detected linter, parse output, return JSON
# Usage: ar_probe_lint "eslint"
ar_probe_lint() {
  local tool="${1:-}"

  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    echo '{"category":"lint","score":null,"max":100,"skipped":true,"reason":"no linter detected","tool":null,"findings":[],"fix_targets":[]}'
    return 0
  fi

  local output=""
  local exit_code=0

  case "${tool}" in
    eslint)
      output=$(npx eslint . --format json 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
    ruff)
      output=$(ruff check . --output-format json 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
    flake8)
      output=$(flake8 --format json . 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
    clippy)
      output=$(cargo clippy --message-format json 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
    golangci-lint)
      output=$(golangci-lint run --out-format json 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
  esac

  local tmpfile
  tmpfile=$(mktemp)
  printf '%s' "${output}" > "${tmpfile}"

  python3 - "${tool}" "${tmpfile}" <<'PYEOF'
import json, sys

tool = sys.argv[1]
with open(sys.argv[2]) as f:
    raw_output = f.read()

findings = []
fix_targets = set()

try:
    if tool == "eslint":
        data = json.loads(raw_output)
        for file_result in data:
            for msg in file_result.get("messages", []):
                findings.append({
                    "file": file_result["filePath"],
                    "line": msg.get("line", 0),
                    "rule": msg.get("ruleId", "unknown"),
                    "severity": "error" if msg.get("severity") == 2 else "warn"
                })
                fix_targets.add(file_result["filePath"])
    elif tool == "ruff":
        data = json.loads(raw_output)
        for item in data:
            findings.append({
                "file": item.get("filename", ""),
                "line": item.get("location", {}).get("row", 0),
                "rule": item.get("code", "unknown"),
                "severity": "error"
            })
            fix_targets.add(item.get("filename", ""))
    else:
        # Generic fallback: count non-empty lines as findings
        lines = [l for l in raw_output.strip().split("\n") if l.strip()]
        for line in lines[:50]:
            findings.append({"file": "unknown", "line": 0, "rule": "unknown", "severity": "warn"})
except (json.JSONDecodeError, KeyError):
    pass

count = len(findings)
score = max(0, 100 - count * 5)
estimated_iterations = max(1, count // 5)

result = {
    "category": "lint",
    "score": score,
    "max": 100,
    "skipped": False,
    "tool": tool,
    "findings": findings[:50],
    "fix_targets": sorted(fix_targets)[:20],
    "estimated_iterations": estimated_iterations
}

print(json.dumps(result))
PYEOF

  rm -f "${tmpfile}"
}
```

- [ ] **Step 2: Verify the function exists and parses**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/probes.sh
type ar_probe_lint
```

Expected: `ar_probe_lint is a function`

- [ ] **Step 3: Test the skip case**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/probes.sh
ar_probe_lint "null" | python3 -m json.tool
```

Expected: JSON with `"skipped": true`

- [ ] **Step 4: Commit**

```bash
git add autoresearch/lib/probes.sh
git commit -m "feat: add lint probe with eslint, ruff, flake8, clippy, golangci-lint support"
```

---

### Task 4: Create lib/probes.sh — tests probe

**Files:**
- Modify: `autoresearch/lib/probes.sh`

- [ ] **Step 1: Add the tests probe function**

Append to `probes.sh`:

```bash
# Tests probe: run detected test runner, parse coverage + failures, return JSON
# Usage: ar_probe_tests "jest"
ar_probe_tests() {
  local tool="${1:-}"

  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    echo '{"category":"tests","score":null,"max":100,"skipped":true,"reason":"no test runner detected","tool":null,"findings":[],"fix_targets":[]}'
    return 0
  fi

  local output=""
  local exit_code=0

  case "${tool}" in
    jest)
      output=$(npx jest --coverage --json --silent 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
    vitest)
      output=$(npx vitest run --coverage --reporter=json 2>/dev/null) && exit_code=0 || exit_code=$?
      ;;
    pytest)
      output=$(pytest --tb=short -q 2>&1) && exit_code=0 || exit_code=$?
      ;;
    cargo-test)
      output=$(cargo test 2>&1) && exit_code=0 || exit_code=$?
      ;;
    go-test)
      output=$(go test ./... -count=1 2>&1) && exit_code=0 || exit_code=$?
      ;;
  esac

  local tmpfile
  tmpfile=$(mktemp)
  printf '%s' "${output}" > "${tmpfile}"

  python3 - "${tool}" "${exit_code}" "${tmpfile}" <<'PYEOF'
import json, sys

tool = sys.argv[1]
exit_code = int(sys.argv[2])
with open(sys.argv[3]) as f:
    raw_output = f.read()

findings = []
fix_targets = set()
coverage_pct = None

try:
    if tool == "jest":
        data = json.loads(raw_output)
        # Failing tests
        for suite in data.get("testResults", []):
            for test in suite.get("testResults", []):
                if test.get("status") == "failed":
                    findings.append({
                        "type": "failing",
                        "test": test.get("fullName", "unknown"),
                        "file": suite.get("name", "unknown"),
                        "error": (test.get("failureMessages") or ["unknown"])[0][:200]
                    })
                    fix_targets.add(suite.get("name", ""))
        # Coverage gaps
        coverage_map = data.get("coverageMap", {})
        for filepath, cov_data in coverage_map.items():
            stmts = cov_data.get("statementMap", {})
            stmt_hits = cov_data.get("s", {})
            if stmts:
                total = len(stmts)
                covered = sum(1 for v in stmt_hits.values() if v > 0)
                pct = round(covered / total * 100) if total > 0 else 100
                if pct < 50:
                    findings.append({"type": "coverage_gap", "file": filepath, "coverage": pct})
                    fix_targets.add(filepath)
    elif tool in ("pytest", "cargo-test", "go-test"):
        # Parse test failures from output lines
        lines = raw_output.strip().split("\n")
        for line in lines:
            if "FAILED" in line or "FAIL" in line:
                findings.append({"type": "failing", "test": line.strip()[:200], "error": ""})
except (json.JSONDecodeError, KeyError):
    pass

# If tests failed but we couldn't parse specifics, add a generic finding
if exit_code != 0 and not findings:
    findings.append({"type": "failing", "test": "unknown", "error": "test suite exited with non-zero"})

failing_count = len([f for f in findings if f.get("type") == "failing"])
gap_count = len([f for f in findings if f.get("type") == "coverage_gap"])

# Score: start at 100, -15 per failing test, -5 per coverage gap
score = max(0, 100 - failing_count * 15 - gap_count * 5)
estimated_iterations = failing_count + gap_count

result = {
    "category": "tests",
    "score": score,
    "max": 100,
    "skipped": False,
    "tool": tool,
    "findings": findings[:50],
    "fix_targets": sorted(fix_targets)[:20],
    "estimated_iterations": max(1, estimated_iterations)
}

print(json.dumps(result))
PYEOF

  rm -f "${tmpfile}"
}
```

- [ ] **Step 2: Test the skip case**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/probes.sh
ar_probe_tests "" | python3 -m json.tool
```

Expected: JSON with `"skipped": true`

- [ ] **Step 3: Commit**

```bash
git add autoresearch/lib/probes.sh
git commit -m "feat: add tests probe with jest, vitest, pytest, cargo, go support"
```

---

### Task 5: Create lib/probes.sh — runtime probe

**Files:**
- Modify: `autoresearch/lib/probes.sh`

- [ ] **Step 1: Add the runtime probe function**

Append to `probes.sh`:

```bash
# Runtime probe: start dev server, curl endpoints, check for errors
# Usage: ar_probe_runtime "npm:dev"
ar_probe_runtime() {
  local tool="${1:-}"

  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    echo '{"category":"runtime","score":null,"max":100,"skipped":true,"reason":"no dev server detected","tool":null,"findings":[],"fix_targets":[]}'
    return 0
  fi

  local pkg_manager="${tool%%:*}"
  local script_name="${tool#*:}"
  local port=""
  local server_pid=""

  # Try to detect port from package.json or common defaults
  port=$(python3 -c "
import json, re
with open('package.json') as f:
    pkg = json.load(f)
script = pkg.get('scripts', {}).get('${script_name}', '')
# Look for --port NNNN or -p NNNN
m = re.search(r'(?:--port|-p)\s+(\d+)', script)
if m:
    print(m.group(1))
else:
    print('3000')
" 2>/dev/null)
  port="${port:-3000}"

  local findings="[]"
  local fix_targets="[]"
  local score=100

  # Start the dev server in background
  npm run "${script_name}" &>/dev/null &
  server_pid=$!

  # Wait for server to be ready (up to 15 seconds)
  local ready=false
  for i in $(seq 1 30); do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${port}/" 2>/dev/null | grep -qE '^[23]'; then
      ready=true
      break
    fi
    sleep 0.5
  done

  if ! "${ready}"; then
    # Server didn't start
    kill "${server_pid}" 2>/dev/null || true
    wait "${server_pid}" 2>/dev/null || true
    cat <<AREOF
{"category":"runtime","score":20,"max":100,"skipped":false,"tool":"${tool}","findings":[{"type":"server_start_failed","error":"Server did not respond on port ${port} within 15s"}],"fix_targets":["package.json"],"estimated_iterations":3}
AREOF
    return 0
  fi

  # Probe common endpoints
  python3 - "${port}" <<'PYEOF'
import json, subprocess, sys

port = sys.argv[1] if len(sys.argv) > 1 else "3000"

endpoints = ["/", "/health", "/api", "/api/health"]
findings = []
fix_targets = set()

for ep in endpoints:
    try:
        result = subprocess.run(
            ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", f"http://localhost:{port}{ep}"],
            capture_output=True, text=True, timeout=5
        )
        status = result.stdout.strip()
        if status.startswith("5"):
            findings.append({"type": "endpoint_error", "endpoint": ep, "status": int(status)})
            fix_targets.add("src/")
    except (subprocess.TimeoutExpired, Exception):
        pass

# Score: 100 - 20 per failing endpoint
score = max(0, 100 - len(findings) * 20)
estimated_iterations = max(1, len(findings) * 2)

result = {
    "category": "runtime",
    "score": score,
    "max": 100,
    "skipped": False,
    "tool": f"npm:{port}",
    "findings": findings,
    "fix_targets": sorted(fix_targets),
    "estimated_iterations": estimated_iterations
}

print(json.dumps(result))
PYEOF

  # Cleanup: kill the dev server
  kill "${server_pid}" 2>/dev/null || true
  wait "${server_pid}" 2>/dev/null || true
}
```

- [ ] **Step 2: Test the skip case**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/probes.sh
ar_probe_runtime "null" | python3 -m json.tool
```

Expected: JSON with `"skipped": true`

- [ ] **Step 3: Commit**

```bash
git add autoresearch/lib/probes.sh
git commit -m "feat: add runtime probe with dev server start + endpoint checking"
```

---

### Task 6: Create lib/probes.sh — architecture probe

**Files:**
- Modify: `autoresearch/lib/probes.sh`

- [ ] **Step 1: Add the architecture probe function**

Append to `probes.sh`:

```bash
# Architecture probe: check file sizes, circular deps, oversized modules
# Usage: ar_probe_architecture "static"
ar_probe_architecture() {
  local tool="${1:-static}"

  python3 <<'PYEOF'
import json, os, subprocess

findings = []
fix_targets = set()

# 1. Oversized files (>800 lines for source files)
src_extensions = {".ts", ".tsx", ".js", ".jsx", ".py", ".rs", ".go", ".java"}
for root, dirs, files in os.walk("."):
    # Skip hidden dirs, node_modules, vendor, target, __pycache__
    dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("node_modules", "vendor", "target", "__pycache__", "dist", "build")]
    for fname in files:
        ext = os.path.splitext(fname)[1]
        if ext in src_extensions:
            fpath = os.path.join(root, fname)
            try:
                with open(fpath, "r", errors="ignore") as f:
                    line_count = sum(1 for _ in f)
                if line_count > 800:
                    findings.append({
                        "type": "oversized_file",
                        "file": fpath,
                        "lines": line_count,
                        "threshold": 800
                    })
                    fix_targets.add(fpath)
            except (OSError, IOError):
                pass

# 2. Circular dependency detection (JS/TS only, if madge is available)
circular_deps = []
try:
    result = subprocess.run(
        ["npx", "madge", "--circular", "--json", "."],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode == 0:
        circular_deps = json.loads(result.stdout)
except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
    pass

for cycle in circular_deps:
    if isinstance(cycle, list) and len(cycle) > 0:
        findings.append({
            "type": "circular_dependency",
            "files": cycle
        })
        for f in cycle:
            fix_targets.add(f)

oversized_count = len([f for f in findings if f["type"] == "oversized_file"])
circular_count = len([f for f in findings if f["type"] == "circular_dependency"])

# Score: 100 - 10 per oversized file - 15 per circular dep
score = max(0, 100 - oversized_count * 10 - circular_count * 15)
estimated_iterations = oversized_count + circular_count * 3

result = {
    "category": "architecture",
    "score": score,
    "max": 100,
    "skipped": False,
    "tool": "static",
    "findings": findings[:50],
    "fix_targets": sorted(fix_targets)[:20],
    "estimated_iterations": max(1, estimated_iterations) if findings else 0
}

print(json.dumps(result))
PYEOF
}
```

- [ ] **Step 2: Add the run-all orchestrator**

Append to `probes.sh`:

```bash
# Run all probes and return combined JSON array
# Usage: ar_probe_run_all
# Prints: JSON object with all probe results keyed by category
ar_probe_run_all() {
  local tooling
  tooling=$(ar_probe_detect_tooling)

  local lint_tool tests_tool runtime_tool arch_tool
  lint_tool=$(echo "${tooling}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('lint') or '')")
  tests_tool=$(echo "${tooling}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tests') or '')")
  runtime_tool=$(echo "${tooling}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('runtime') or '')")
  arch_tool=$(echo "${tooling}" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('architecture') or '')")

  local lint_result tests_result runtime_result arch_result
  lint_result=$(ar_probe_lint "${lint_tool}")
  tests_result=$(ar_probe_tests "${tests_tool}")
  runtime_result=$(ar_probe_runtime "${runtime_tool}")
  arch_result=$(ar_probe_architecture "${arch_tool}")

  python3 - <<PYEOF
import json

results = {}
for raw in ['''${lint_result}''', '''${tests_result}''', '''${runtime_result}''', '''${arch_result}''']:
    try:
        data = json.loads(raw)
        results[data["category"]] = data
    except (json.JSONDecodeError, KeyError):
        pass

print(json.dumps(results, indent=2))
PYEOF
}
```

- [ ] **Step 3: Commit**

```bash
git add autoresearch/lib/probes.sh
git commit -m "feat: add architecture probe and run-all orchestrator"
```

---

### Task 7: Create lib/harness.sh — harness.json management and scoring

**Files:**
- Create: `autoresearch/lib/harness.sh`

- [ ] **Step 1: Create harness.sh with init, rank, and read functions**

```bash
#!/usr/bin/env bash
# Harness management for autoresearch harness-check/harness-improvement
# Manages .autoresearch/harness.json — the project health scorecard.

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Create harness.json from probe results
# Usage: ar_harness_init "$probe_results_json"
ar_harness_init() {
  local probe_results="$1"

  ar_ensure_dir
  ar_ensure_gitignore

  local project_name
  project_name=$(basename "$(pwd)")
  local timestamp
  timestamp=$(ar_datetime)

  python3 - <<PYEOF
import json

probes = json.loads('''${probe_results}''')
project = "${project_name}"
timestamp = "${timestamp}"

# Calculate overall score (average of non-skipped probes)
scores = [p["score"] for p in probes.values() if not p.get("skipped") and p.get("score") is not None]
overall = round(sum(scores) / len(scores)) if scores else 0

# Rank improvements by impact
weights = {"runtime": 1.5, "architecture": 1.2, "lint": 1.0, "tests": 1.0}
ranked = []

for category, probe in probes.items():
    if probe.get("skipped") or probe.get("score") is None:
        continue
    score = probe["score"]
    if score >= 95:
        continue  # Nothing meaningful to improve

    gap = 100 - score
    weight = weights.get(category, 1.0)
    est_iters = probe.get("estimated_iterations", 5)
    fixability = min(1.0, 10.0 / max(1, est_iters))
    impact = round(gap * weight * fixability, 1)

    # Build description from findings
    finding_types = {}
    for f in probe.get("findings", []):
        ft = f.get("type", f.get("rule", "issue"))
        finding_types[ft] = finding_types.get(ft, 0) + 1

    desc_parts = []
    for ft, count in sorted(finding_types.items(), key=lambda x: -x[1]):
        desc_parts.append(f"{count} {ft}")
    description = "Fix " + ", ".join(desc_parts[:3]) if desc_parts else f"Improve {category}"

    ranked.append({
        "category": category,
        "impact_score": impact,
        "description": description,
        "estimated_iterations": est_iters,
        "targets": probe.get("fix_targets", [])
    })

ranked.sort(key=lambda x: -x["impact_score"])
for i, item in enumerate(ranked):
    item["rank"] = i + 1

harness = {
    "version": "1.0",
    "project": project,
    "checked_at": timestamp,
    "probes": probes,
    "summary": {
        "overall_score": overall,
        "ranked_improvements": ranked
    }
}

with open("${AR_HARNESS_FILE}", "w") as f:
    json.dump(harness, f, indent=2)
PYEOF

  ar_log "Wrote harness.json"
}

# Read harness.json as raw JSON
ar_harness_read() {
  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    ar_log "ERROR: harness.json not found. Run /autoresearch:harness-check first."
    return 1
  fi
  cat "${AR_HARNESS_FILE}"
}

# Check if harness.json is stale (>24h old)
# Returns: 0 if stale, 1 if fresh
ar_harness_is_stale() {
  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    return 0
  fi

  python3 - <<PYEOF
import json, sys
from datetime import datetime, timezone, timedelta

with open("${AR_HARNESS_FILE}") as f:
    data = json.load(f)

checked_at = datetime.fromisoformat(data["checked_at"].replace("Z", "+00:00"))
now = datetime.now(timezone.utc)
age = now - checked_at

sys.exit(0 if age > timedelta(hours=24) else 1)
PYEOF
}
```

- [ ] **Step 2: Verify it sources correctly**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/harness.sh
type ar_harness_init
type ar_harness_read
type ar_harness_is_stale
```

Expected: All three are functions.

- [ ] **Step 3: Commit**

```bash
git add autoresearch/lib/harness.sh
git commit -m "feat: add lib/harness.sh with init, read, and staleness check"
```

---

### Task 8: Add harness.sh — scorecard printer and program.md generator

**Files:**
- Modify: `autoresearch/lib/harness.sh`

- [ ] **Step 1: Add the scorecard printer**

Append to `harness.sh`:

```bash
# Print a formatted scorecard to terminal
# Usage: ar_harness_print_scorecard
ar_harness_print_scorecard() {
  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    ar_log "ERROR: harness.json not found."
    return 1
  fi

  python3 - <<'PYEOF'
import json

with open(".autoresearch/harness.json") as f:
    data = json.load(f)

project = data["project"]
probes = data["probes"]
summary = data["summary"]

# Category display order: by score ascending (worst first)
categories = []
for cat, probe in probes.items():
    if not probe.get("skipped"):
        categories.append((cat, probe.get("score", 0)))
categories.sort(key=lambda x: x[1])

# Category labels
labels = {"lint": "Code Quality", "tests": "Tests", "runtime": "Runtime Health", "architecture": "Architecture"}

print(f"\nHarness Check Report — {project}/")
print("─" * 50)

for cat, score in categories:
    probe = probes[cat]
    label = labels.get(cat, cat).ljust(18)
    bar_filled = score // 5
    bar_empty = 20 - bar_filled
    bar = "█" * bar_filled + "░" * bar_empty

    # Summary of findings
    finding_count = len(probe.get("findings", []))
    detail = f"  {finding_count} finding{'s' if finding_count != 1 else ''}" if finding_count else ""

    print(f"  {label} {score:>3}/100  {bar}{detail}")

# Skipped probes
for cat, probe in probes.items():
    if probe.get("skipped"):
        label = labels.get(cat, cat).ljust(18)
        print(f"  {label}   --    (skipped: {probe.get('reason', 'no tooling')})")

print(f"\n  Overall: {summary['overall_score']}/100")

ranked = summary.get("ranked_improvements", [])
if ranked:
    print(f"\n  🎯 Top improvements by impact:")
    for item in ranked[:5]:
        cat_label = labels.get(item["category"], item["category"])
        est = item.get("estimated_iterations", "?")
        gap = 100 - probes[item["category"]]["score"]
        print(f"  #{item['rank']}  {cat_label:<18} → {item['description']:<45} (+{gap} pts, ~{est} iterations)")

    print(f"\n  Run: /autoresearch:harness-improvement           (starts #{ranked[0]['rank']})")
    if len(ranked) > 1:
        print(f"  Run: /autoresearch:harness-improvement --rank 2  (starts #{ranked[1]['rank']})")
    print(f"  Run: /autoresearch:harness-improvement --focus <category>")
else:
    print("\n  ✅ All categories at 95+ — nothing to improve!")
PYEOF
}
```

- [ ] **Step 2: Add the program.md generator**

Append to `harness.sh`:

```bash
# Convert a ranked improvement into a program.md for the experimenter
# Usage: ar_harness_to_program <rank_number>
# Writes: .autoresearch/program.md
ar_harness_to_program() {
  local rank="${1:-1}"

  if [ ! -f "${AR_HARNESS_FILE}" ]; then
    ar_log "ERROR: harness.json not found."
    return 1
  fi

  python3 - "${rank}" <<'PYEOF'
import json, sys, os

rank = int(sys.argv[1])

with open(".autoresearch/harness.json") as f:
    harness = json.load(f)

ranked = harness["summary"]["ranked_improvements"]
target = None
for item in ranked:
    if item["rank"] == rank:
        target = item
        break

if not target:
    print(f"ERROR: No improvement at rank {rank}", file=sys.stderr)
    sys.exit(1)

category = target["category"]
probe = harness["probes"][category]
description = target["description"]
targets = target.get("targets", [])
est_iters = target.get("estimated_iterations", 10)
current_score = probe["score"]

# Build eval command: re-run the relevant probe
plugin_find = "$(find ~/.claude/plugins -path '*/autoresearch/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
eval_cmd = f'source "{plugin_find}" && ar_probe_{category} "{probe.get("tool", "")}" | python3 -c "import json,sys; print(json.load(sys.stdin)[\'score\'])"'

# Threshold: aim for 90 or current + 20, whichever is lower
threshold = min(90, current_score + 20)

program = f"""# Experiment Program

## Goal
{description} — improve {category} score from {current_score}/100 to ≥{threshold}/100.

## Target Files
{chr(10).join('- ' + t for t in targets) if targets else '- (auto-detect from findings)'}

## Eval

### Method
shell

### Shell Command
{eval_cmd}

### LLM Judge Criteria
N/A

### Metrics
- score (higher_is_better)

## Stopping Condition
- Target: score ≥ {threshold}
- Max iterations: {min(10, est_iters + 3)}
- Consecutive non-improvements: 3

## Constraints
- Focus only on {category} issues
- Do not change unrelated code
- Preserve existing functionality

## History

This file was auto-generated by `/autoresearch:harness-improvement` from harness.json.
Category: {category} | Rank: {rank} | Tool: {probe.get('tool', 'N/A')}
"""

with open(".autoresearch/program.md", "w") as f:
    f.write(program)

print(f"Generated program.md for rank #{rank}: {category}")
PYEOF
}
```

- [ ] **Step 3: Verify both functions exist**

Run:
```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/harness.sh
type ar_harness_print_scorecard
type ar_harness_to_program
```

Expected: Both are functions.

- [ ] **Step 4: Commit**

```bash
git add autoresearch/lib/harness.sh
git commit -m "feat: add scorecard printer and program.md generator to harness.sh"
```

---

### Task 9: Create the harness-check command

**Files:**
- Create: `autoresearch/commands/harness-check.md`

- [ ] **Step 1: Write the command file**

```markdown
---
description: "Scan project health across code quality, tests, runtime, and architecture — produces a scored harness report with impact-ranked improvements"
allowed-tools: ["Read", "Bash", "Glob", "Grep"]
---

# /autoresearch:harness-check

You are the harness-check command for the autoresearch plugin. Your job is to scan the current project, run probes, and present a health scorecard with ranked improvement recommendations.

## Step 1: Source Libraries

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

## Step 2: Parse Arguments

Check if the user passed any flags:
- `--json` — output raw harness.json instead of formatted scorecard
- `--probe <name>` — run only a specific probe (lint, tests, runtime, architecture)

## Step 3: Detect Tooling

```bash
tooling=$(ar_probe_detect_tooling)
```

Print what was detected:
> 🔍 Scanning project...
>   Detected: <list of tools found>

If nothing was detected (all probes would be skipped), tell the user:
> Could not detect any tooling in this project. Make sure you're in a project root with config files (package.json, pyproject.toml, Cargo.toml, etc).

## Step 4: Run Probes

If `--probe <name>` was specified, run only that probe. Otherwise run all:

```bash
results=$(ar_probe_run_all)
```

## Step 5: Generate Harness Report

```bash
ar_harness_init "${results}"
```

## Step 6: Display Results

If `--json` was specified:
```bash
ar_harness_read
```

Otherwise print the formatted scorecard:
```bash
ar_harness_print_scorecard
```

## Step 7: Suggest Next Steps

After the scorecard, tell the user:
> Run `/autoresearch:harness-improvement` to start fixing the top-ranked issue.

If all scores are ≥95:
> ✅ Project health looks great! All categories at 95+.
```

- [ ] **Step 2: Verify the command file has valid frontmatter**

Run:
```bash
head -5 /Users/williamhung/Projects/cc-plugins/autoresearch/commands/harness-check.md
```

Expected: YAML frontmatter with `---` delimiters and `description` field.

- [ ] **Step 3: Commit**

```bash
git add autoresearch/commands/harness-check.md
git commit -m "feat: add /autoresearch:harness-check command"
```

---

### Task 10: Create the harness-improvement command

**Files:**
- Create: `autoresearch/commands/harness-improvement.md`

- [ ] **Step 1: Write the command file**

```markdown
---
description: "Execute improvement loop on the top-ranked harness issue — auto-generates eval from probes and spawns the experimenter agent"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "Agent", "AskUserQuestion"]
---

# /autoresearch:harness-improvement

You are the harness-improvement command for the autoresearch plugin. Your job is to read the harness report, pick the top improvement target, auto-generate a program.md, and hand off to the experimenter agent.

## Step 1: Source Libraries

```bash
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/harness.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/probes.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/experiment-log.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/eval.sh' -print -quit 2>/dev/null || echo '/dev/null')"
source "$(find ~/.claude/plugins -path '*/autoresearch/lib/dashboard.sh' -print -quit 2>/dev/null || echo '/dev/null')"
```

## Step 2: Validate Harness Exists

Check if `.autoresearch/harness.json` exists:
```bash
ar_harness_read > /dev/null
```

If it doesn't exist, tell the user:
> No harness report found. Run `/autoresearch:harness-check` first to scan your project.

If it's stale (>24h old), warn:
> ⚠️ Harness report is over 24 hours old. Consider re-running `/autoresearch:harness-check` for fresh results.
> Proceeding with existing report...

## Step 3: Parse Arguments

Check if the user passed any flags:
- `--rank <N>` — target the Nth ranked improvement (default: 1)
- `--focus <category>` — target a specific category (lint, tests, runtime, architecture)
- `--threshold <N>` — override the default target score
- `--max-iterations <N>` — override default iteration limit

If `--focus <category>` is specified, find the rank for that category from harness.json.

## Step 4: Check Target Viability

Read the harness.json and check the target:
- If the target category's score is already ≥90, suggest the next ranked improvement:
  > <Category> is already at <score>/100. Try `--rank 2` for the next improvement.

## Step 5: Generate program.md

```bash
ar_harness_to_program <rank>
```

Print what's being targeted:
> **Target:** <Category> (rank #<N>, score <score>/100)
> **Goal:** <description>
> **Eval:** ar_probe_<category> (re-run after each iteration)
> **Threshold:** ≥<threshold>/100
> **Max iterations:** <max>

## Step 6: Initialize Experiment Log

Read the generated program.md to extract the goal and eval details, then:

```bash
ar_log_init "<goal>" "shell" "<eval_command>" "" "<max_iterations>" "3"
```

## Step 7: Run Baseline Eval

Run the probe as eval to get the starting score:

```bash
result=$(ar_eval_run "<eval_command>")
exit_code=$(echo "${result}" | head -1)
score=$(echo "${result}" | tail -n +2)
ar_log_set_baseline "{\"score\": ${score}}"
```

Print:
> Running baseline... <score>/100

## Step 8: Generate Initial Dashboard

```bash
ar_dashboard_generate
ar_dashboard_open
```

If `ar_dashboard_generate` fails, stop and report the error. Do NOT proceed.

## Step 9: Hand Off to Experimenter Agent

Tell the user:
> Baseline established. Dashboard is open. Starting the improvement loop.

Then spawn the experimenter agent using the Agent tool. Pass:
1. The full content of `.autoresearch/program.md`
2. The path to the project root
3. The paths to the lib scripts
4. Instruction to read the experiment-loop skill for the iteration protocol

The experimenter agent handles the edit-eval-keep/discard loop from here. It is defined at `agents/experimenter.md` within the autoresearch plugin.

## Important Notes

- This command reuses the existing experimenter agent and experiment-loop skill unchanged.
- The only difference from `/autoresearch:improve` is that goal/eval/targets come from harness.json, not from the user.
- Probes serve double duty: discovery in harness-check AND eval in harness-improvement.
```

- [ ] **Step 2: Verify the command file has valid frontmatter**

Run:
```bash
head -5 /Users/williamhung/Projects/cc-plugins/autoresearch/commands/harness-improvement.md
```

Expected: YAML frontmatter with `---` delimiters and `description` field.

- [ ] **Step 3: Commit**

```bash
git add autoresearch/commands/harness-improvement.md
git commit -m "feat: add /autoresearch:harness-improvement command"
```

---

### Task 11: Create the harness-probes skill

**Files:**
- Create: `autoresearch/skills/harness-probes/SKILL.md`

- [ ] **Step 1: Write the skill file**

```markdown
---
name: harness-probes
description: "Guide for adding custom probes to the autoresearch harness-check system."
---

# Harness Probes

This skill describes how probes work and how to add new ones.

## Probe Contract

Every probe is a bash function in `lib/probes.sh` that:

1. Takes a tool name as its first argument (or empty/"null" to skip)
2. Prints a single JSON object to stdout
3. Returns exit code 0 (even on skip)

### Required JSON Shape

```json
{
  "category": "string",
  "score": 0-100 | null,
  "max": 100,
  "skipped": true | false,
  "reason": "string (only if skipped)",
  "tool": "string | null",
  "findings": [
    { "type": "string", "file": "string", ... }
  ],
  "fix_targets": ["file/paths"],
  "estimated_iterations": 1
}
```

### Score Calculation

- Start at 100 (perfect)
- Deduct points per finding based on severity
- Clamp to 0 minimum
- Return null if skipped

### Adding a New Probe

1. Add a detection case in `ar_probe_detect_tooling()`
2. Write the `ar_probe_<name>()` function following the contract above
3. Add the call to `ar_probe_run_all()`
4. Add the weight in `ar_harness_init()` (in `lib/harness.sh`)

### Example: Adding a security probe

```bash
ar_probe_security() {
  local tool="${1:-}"
  if [ -z "${tool}" ] || [ "${tool}" = "null" ]; then
    echo '{"category":"security","score":null,"max":100,"skipped":true,"reason":"no security scanner detected","tool":null,"findings":[],"fix_targets":[]}'
    return 0
  fi
  # Run scanner, parse output, return JSON...
}
```

Then add `"security": 1.3` to the weights dict in `ar_harness_init()`.
```

- [ ] **Step 2: Commit**

```bash
mkdir -p /Users/williamhung/Projects/cc-plugins/autoresearch/skills/harness-probes
git add autoresearch/skills/harness-probes/SKILL.md
git commit -m "feat: add harness-probes skill with probe authoring guide"
```

---

### Task 12: Integration test — end-to-end harness-check flow

**Files:**
- Test against a real or mock project

- [ ] **Step 1: Create a minimal test project**

```bash
mkdir -p /tmp/harness-test && cd /tmp/harness-test
git init
echo '{"name":"test","scripts":{"dev":"echo hi","test":"echo ok"},"devDependencies":{"eslint":"^8.0.0"}}' > package.json
touch eslint.config.js
mkdir -p src
cat > src/app.ts << 'EOF'
const unused = 42;
export function main() { return "hello"; }
EOF
git add -A && git commit -m "init"
```

- [ ] **Step 2: Run probes**

```bash
cd /tmp/harness-test
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/probes.sh
ar_probe_detect_tooling | python3 -m json.tool
```

Expected: JSON with at least `"lint": "eslint"` detected.

- [ ] **Step 3: Run full harness init**

```bash
source /Users/williamhung/Projects/cc-plugins/autoresearch/lib/harness.sh
results=$(ar_probe_run_all)
ar_harness_init "${results}"
cat .autoresearch/harness.json | python3 -m json.tool
```

Expected: Valid JSON with probes, summary, ranked_improvements.

- [ ] **Step 4: Print scorecard**

```bash
ar_harness_print_scorecard
```

Expected: Formatted terminal output with progress bars and ranked improvements.

- [ ] **Step 5: Generate program.md**

```bash
ar_harness_to_program 1
cat .autoresearch/program.md
```

Expected: Valid program.md with goal, eval command, targets, stopping condition.

- [ ] **Step 6: Cleanup**

```bash
rm -rf /tmp/harness-test
```

- [ ] **Step 7: Commit any fixes found during integration testing**

```bash
cd /Users/williamhung/Projects/cc-plugins
git add autoresearch/
git commit -m "fix: integration test fixes for harness-check flow"
```

(Skip this commit if no fixes were needed.)
