# Autoresearch Artifact Dashboard Design

## Goal

Show each autoresearch improvement run in one private Claude Artifact instead of a local `.autoresearch/dashboard.html` file opened by the operating system.

## Current State

The dashboard generator inserts `.autoresearch/experiments.json` into `templates/dashboard.html`, then writes `.autoresearch/dashboard.html`. The setup commands call `open` on macOS. During the loop, the browser reloads the local file every five seconds through a meta refresh tag.

The page loads Chart.js from `cdn.jsdelivr.net`. Claude Artifacts block external asset requests, so the current chart cannot render there.

## Design

### Self-contained Dashboard

`templates/dashboard.html` becomes Artifact-ready HTML content:

- Remove `<!DOCTYPE>`, `<html>`, `<head>`, and `<body>` wrappers because Artifact provides them.
- Remove the Chart.js CDN script and every `new Chart(...)` call.
- Render the score history with inline SVG and vanilla JavaScript.
- Keep the existing status cards, iteration table, expandable details, visual style, and `{{DATA_JSON}}` injection.
- Remove the meta-refresh tag and the completion-time removal script. Artifact redeploys show new data.

The inline SVG chart must display baseline and experiment points. Kept points are green. Discarded points are red. Reverse the Y scale for `lower_is_better`. Support zero or one score.

### Artifact Lifecycle

The Artifact tool is the delivery mechanism:

1. Setup commands generate dashboard HTML from the baseline data.
2. They publish it as a private Artifact named `autoresearch-dashboard`, with a stable `📈` favicon and a short description.
3. The returned Artifact URL is included in the handoff prompt and shown to the user.
4. Each loop update regenerates HTML and republishes with that exact URL. The tool updates the same Artifact rather than creating a new page.
5. The final loop update republishes completed data to the same URL.

The URL is runtime state for the current Claude session. Do not write it into `experiments.json`. That JSON log must remain portable. The Artifact link is not valid outside the session. The experimenter receives the URL in its prompt.

### Removed Local-File Behavior

`ar_dashboard_open()` is removed. The dashboard generator keeps one responsibility: render dashboard HTML from the experiment log. `.autoresearch/dashboard.html` remains a generated local fallback/output artifact for debugging and portability, but the commands no longer open it or describe it as live.

### Prompt and Documentation Updates

- `commands/improve.md` and `commands/harness-improvement.md` publish the initial Artifact and pass the URL to the experimenter.
- `skills/experiment-loop/SKILL.md` requires the experimenter to regenerate and republish after each log update. Publishing failures stop the loop because the dashboard is part of the requested run experience.
- `agents/experimenter.md` includes Artifact in its tool list and tells the agent to preserve the supplied URL.
- `CLAUDE.md` documents the Artifact dashboard and the local HTML fallback.

## Error Handling

- If `ar_dashboard_generate` fails, setup does not start the loop.
- If the first Artifact publish fails, setup does not start the loop.
- If an update publish fails, the loop retries once. A second failure stops the loop and reports the error.
- If no URL was supplied to the experimenter, it publishes a new Artifact once, reports the URL, then uses it for later updates.

## Testing

Add shell assertions that confirm:

- generated dashboard HTML has no `http://` or `https://` asset references
- dashboard HTML uses inline `<svg` and no `new Chart(` call
- `ar_dashboard_generate` embeds supplied experiment data
- `ar_dashboard_open` no longer exists
- command/skill/agent instructions reference Artifact publication and the stable update URL

Run the plugin test suite plus `./scripts/cicd.sh GEN` and `./scripts/cicd.sh VERIFY`.

## Constraints

- No new dependencies.
- No external web assets.
- Keep the Artifact private by default.
- Use `📈` for the Artifact favicon across initial publishes and updates.
- Bump autoresearch from `2.2.1` to `2.2.2` in plugin and marketplace manifests.
- Add the matching autoresearch changelog entry.
