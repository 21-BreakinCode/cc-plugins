// Shapes the model into the JSON the static site consumes (site/data/plugins.json).
// Same content as CATALOG.md, in machine-readable form.

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
      icon: p.icon,
      install: p.install,
      oneLiner: p.oneLiner,
      commands: p.commands,
      skills: p.skills,
      dependsOn: p.dependsOn,
      config: p.config,
    })),
  };
}
