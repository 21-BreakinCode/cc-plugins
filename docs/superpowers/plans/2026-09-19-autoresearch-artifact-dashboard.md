# Autoresearch Artifact Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace autoresearch's local auto-refreshing dashboard with one private Artifact that updates at a stable URL throughout an improvement loop.

**Architecture:** Dashboard rendering remains a shell function that turns `experiments.json` into HTML. The generated page is self-contained and draws its score chart with inline SVG. Setup commands publish the first Artifact, then pass its URL to the experimenter. The experimenter regenerates and republishes to that URL after each log update.

**Tech Stack:** POSIX shell, Python 3 string substitution, Artifact tool, vanilla JavaScript, inline SVG, Node test runner.

**Spec:** `docs/superpowers/specs/2026-09-19-autoresearch-artifact-dashboard-design.md`

## Global Constraints

- Add no dependencies.
- Use no remote assets.
- Publish private Artifacts by default.
- Use `📈` for every Artifact publish and update.
- Keep `.autoresearch/dashboard.html` as generated fallback output.
- Bump autoresearch `2.2.1` to `2.2.2` in both manifests.

---

### Task 1: Lock the dashboard contract with smoke tests

**Files:**
- Modify: `autoresearch/tests/run-tests.sh`
- Test: `autoresearch/tests/run-tests.sh`

**Interfaces:**
- Consumes: `autoresearch/templates/dashboard.html`, `autoresearch/lib/dashboard.sh`
- Produces: a regression test. It fails for Chart.js, remote URLs, meta refresh, or a removed open helper.

- [ ] **Step 1: Read the existing test runner and its test helpers**

Run: `Read autoresearch/tests/run-tests.sh`

Expected: find the existing shell assertion conventions and temporary-directory cleanup.

- [ ] **Step 2: Write failing smoke assertions**

Add assertions equivalent to:

```bash
assert_not_contains "$DASHBOARD_TEMPLATE" 'https://'
assert_not_contains "$DASHBOARD_TEMPLATE" 'new Chart('
assert_not_contains "$DASHBOARD_TEMPLATE" 'http-equiv="refresh"'
assert_contains "$DASHBOARD_TEMPLATE" '<svg'
assert_not_contains "$DASHBOARD_LIBRARY" 'ar_dashboard_open()'
```

- [ ] **Step 3: Run the tests to check RED**

Run: `bash autoresearch/tests/run-tests.sh`

Expected: FAIL because the current template loads Chart.js and includes meta refresh, and `dashboard.sh` defines `ar_dashboard_open`.

- [ ] **Step 4: Keep the red test local**

Keep the known failing test staged locally until Task 2 turns it green. For a project with a green-commit policy, do not commit the failing test.

### Task 2: Make the dashboard self-contained

**Files:**
- Modify: `autoresearch/templates/dashboard.html`
- Modify: `autoresearch/lib/dashboard.sh`
- Test: `autoresearch/tests/run-tests.sh`

**Interfaces:**
- Consumes: `{{DATA_JSON}}` replacement data from `ar_dashboard_generate()`.
- Produces: Artifact-ready HTML with `renderScoreChart()` and no remote dependencies.

- [ ] **Step 1: Remove file-page wrappers and remote dependencies**

Delete the document wrappers, the Chart.js script element, and the meta refresh element. Keep the page content, style, and injected `const DATA` script.

- [ ] **Step 2: Replace the chart canvas with an inline SVG container**

Replace:

```html
<canvas id="scoreChart" height="80"></canvas>
```

with:

```html
<svg id="scoreChart" viewBox="0 0 720 220" role="img" aria-label="Score over iterations"></svg>
```

- [ ] **Step 3: Implement the smallest SVG renderer**

Add `renderScoreChart()` after score-direction selection. It must:

```javascript
const scores = [baselineScore, ...experiments.map(item => item.scores[primaryMetric])]
const validScores = scores.filter(Number.isFinite)
if (validScores.length === 0) {
  chart.innerHTML = '<text x="360" y="110" text-anchor="middle">No score data</text>'
  return
}
```

Compute a five-percent vertical padding range. Use a non-zero fallback range for one score. Compute `x` from array index, reverse `y` for `lower_is_better`, render a line path, then render circles for baseline, kept, and discarded points. Give every circle a `<title>` containing iteration label and score.

- [ ] **Step 4: Remove file-open behavior**

Delete `ar_dashboard_open()` from `autoresearch/lib/dashboard.sh`. Keep `ar_dashboard_generate()` unchanged apart from comments that now call its output Artifact-ready HTML.

- [ ] **Step 5: Run the tests to check GREEN**

Run: `bash autoresearch/tests/run-tests.sh`

Expected: PASS. Add one assertion that a generated output contains injected test data:

```bash
ar_dashboard_generate
assert_contains "$AR_DASHBOARD_FILE" '"goal":"test goal"'
```

- [ ] **Step 6: Commit the self-contained renderer**

```bash
git add autoresearch/templates/dashboard.html autoresearch/lib/dashboard.sh autoresearch/tests/run-tests.sh
git commit -m "feat: render autoresearch dashboard without CDN assets"
```

### Task 3: Route setup and loop lifecycle through Artifact

**Files:**
- Modify: `autoresearch/commands/improve.md`
- Modify: `autoresearch/commands/harness-improvement.md`
- Modify: `autoresearch/skills/experiment-loop/SKILL.md`
- Modify: `autoresearch/agents/experimenter.md`
- Test: `autoresearch/tests/run-tests.sh`

**Interfaces:**
- Consumes: generated path `.autoresearch/dashboard.html` and Artifact publish result URL.
- Produces: an initial Artifact URL that reaches the experimenter as `<dashboard_url>`. Later updates call Artifact with `url: <dashboard_url>`.

- [ ] **Step 1: Add failing instruction-contract tests**

Assert that setup commands contain an Artifact publish instruction, that `experiment-loop` contains `url: <dashboard_url>`, and that the experimenter tool list includes `Artifact`.

- [ ] **Step 2: Check RED**

Run: `bash autoresearch/tests/run-tests.sh`

Expected: FAIL because the existing commands call `ar_dashboard_open`, the skill does not use `url:`, and the agent cannot use Artifact.

- [ ] **Step 3: Publish the initial Artifact in both setup commands**

Replace the open call with instructions to publish:

```text
Call Artifact with:
- `file_path`: `.autoresearch/dashboard.html`
- `favicon`: `📈`
- `title`: `Autoresearch Dashboard`
- `description`: `Live progress for the current autoresearch improvement run.`
```

Save the returned URL as `<dashboard_url>`. Show the URL in the baseline message. Pass it to the experimenter prompt.

- [ ] **Step 4: Republish the stable Artifact during the loop**

In `experiment-loop/SKILL.md`, after `ar_dashboard_generate`, call Artifact with:

```text
- `file_path`: `.autoresearch/dashboard.html`
- `url`: `<dashboard_url>`
- `favicon`: `📈`
```

State that a publish failure gets one retry and then stops the loop. The final status update uses the same Artifact URL.

- [ ] **Step 5: Allow the experimenter to publish**

Change agent frontmatter tools to include `Artifact`. State that `<dashboard_url>` comes from the setup command and must be used for every update. If the prompt lacks a URL, publish once as the fallback.

- [ ] **Step 6: Check GREEN**

Run: `bash autoresearch/tests/run-tests.sh`

Expected: PASS.

- [ ] **Step 7: Commit lifecycle instructions**

```bash
git add autoresearch/commands/improve.md autoresearch/commands/harness-improvement.md \
  autoresearch/skills/experiment-loop/SKILL.md autoresearch/agents/experimenter.md \
  autoresearch/tests/run-tests.sh
git commit -m "feat: publish autoresearch dashboards as Artifacts"
```

### Task 4: Version, document, generate, and check

**Files:**
- Modify: `autoresearch/CLAUDE.md`
- Modify: `autoresearch/CHANGELOG.md`
- Modify: `autoresearch/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Generated: `CATALOG.md`, `autoresearch/README.md`, `site/data/plugins.json`, `site/*.html`

**Interfaces:**
- Consumes: final Artifact dashboard behavior.
- Produces: version `2.2.2`, generated documentation, and verified manifest lockstep.

- [ ] **Step 1: Update runtime-artifact documentation**

Replace the local live-dashboard wording with:

```markdown
- `dashboard.html`: self-contained local fallback for the live Artifact dashboard
```

Document that Artifact publication uses a session-scoped URL and does not write that URL to `experiments.json`.

- [ ] **Step 2: Bump manifests and changelog**

Change `autoresearch/.claude-plugin/plugin.json` and the `autoresearch` entry in `.claude-plugin/marketplace.json` from `2.2.1` to `2.2.2`.

Add at the top of `autoresearch/CHANGELOG.md`:

```markdown
## 2.2.2 - 2026-09-19

- **feat:** publish the live improvement dashboard as a private Claude Artifact. The dashboard now uses inline SVG and no external assets.
```

- [ ] **Step 3: Regenerate owned documentation**

Run: `./scripts/cicd.sh GEN`

Expected: generated catalog, README, and site data reflect `2.2.2`.

- [ ] **Step 4: Run all verification**

Run:

```bash
bash autoresearch/tests/run-tests.sh
./scripts/cicd.sh VERIFY
python3 /private/tmp/claude-502/-Users-william-hung-Projects-PersonalPlugins/06f2d24a-7e0f-4473-8a68-75b2a5fb1250/scratchpad/diag.py \
  autoresearch/agents/experimenter.md autoresearch/commands/improve.md \
  autoresearch/commands/harness-improvement.md autoresearch/skills/experiment-loop/SKILL.md \
  autoresearch/CLAUDE.md autoresearch/CHANGELOG.md
```

Expected: all tests pass, generated docs remain in sync, real STE violations are zero, and only documented `harness` false positives remain.

- [ ] **Step 5: Commit release documentation**

```bash
git add autoresearch/CLAUDE.md autoresearch/CHANGELOG.md \
  autoresearch/.claude-plugin/plugin.json .claude-plugin/marketplace.json \
  CATALOG.md autoresearch/README.md site/data/plugins.json site/*.html
git commit -m "chore: release autoresearch artifact dashboard"
```
