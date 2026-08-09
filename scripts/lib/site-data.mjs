// Shapes the model into the JSON the static site consumes (site/data/plugins.json).
// Same content as CATALOG.md, in machine-readable form.

function parseChangelog(md) {
  if (!md) return [];
  const versions = [];
  let current = null;
  for (const line of md.split('\n')) {
    const heading = line.match(/^## (.+?) — (\d{4}-\d{2}-\d{2})$/);
    if (heading) {
      current = { version: heading[1], date: heading[2], changes: [] };
      versions.push(current);
      continue;
    }
    if (current) {
      const bullet = line.match(/^- \*\*(\w+):\*\* (.+)$/);
      if (bullet) current.changes.push({ type: bullet[1], text: bullet[2] });
    }
  }
  return versions;
}

export function buildSiteData(model) {
  return {
    marketplace: model.marketplace,
    installAll: model.installAll,
    categories: model.categories,
    plugins: model.plugins.map((p) => ({
      name: p.name,
      version: p.version,
      tagline: p.tagline,
      summary: p.summary,
      category: p.category,
      install: p.install,
      oneLiner: p.oneLiner,
      commands: p.commands,
      skills: p.skills,
      dependsOn: p.dependsOn,
      config: p.config,
      changelog: parseChangelog(p.changelog),
    })),
  };
}
