// Renders the human-readable CATALOG.md: a high-level summary of every plugin,
// grouped by category, plus the one-shot install block.

function sourceBasename(source) {
  return String(source).replace(/^\.\//, '');
}

function surfaceLine(plugin) {
  if (plugin.commands.length) {
    return `**Commands** · ${plugin.commands.map((c) => `\`${c.name}\``).join(' · ')}`;
  }
  if (plugin.skills.length) {
    return `**Skills** · ${plugin.skills.map((s) => `\`${s.name}\``).join(' · ')}`;
  }
  return '**Skill-based** · activates automatically';
}

function pluginBlock(plugin) {
  return [
    `### [${plugin.name}](./${sourceBasename(plugin.source)}/README.md) · \`v${plugin.version}\``,
    '',
    `*${plugin.tagline}*`,
    '',
    plugin.summary,
    '',
    `**Install** · \`${plugin.install}\``,
    '',
    surfaceLine(plugin),
  ].join('\n');
}

export function renderCatalog(model) {
  const { name, version, repo } = model.marketplace;
  const out = [
    '# Plugin Catalog',
    '',
    '> Auto-generated from `.claude-plugin/marketplace.json` + `content/plugins.content.json`.',
    '> Do not edit by hand — run `./scripts/cicd.sh GEN`.',
    '>',
    `> **${name}** v${version} · ${model.plugins.length} plugins · [\`${repo}\`](https://github.com/${repo})`,
    '',
    '## Install everything',
    '',
    '```bash',
    model.installAll.cli,
    '```',
    '',
    '## Update everything',
    '',
    'Third-party marketplaces don\'t auto-update by default — refresh the catalog, then',
    'update each installed plugin:',
    '',
    '```bash',
    model.installAll.update,
    '```',
    '',
  ];

  const byName = new Map(model.plugins.map((p) => [p.name, p]));
  for (const cat of model.categories) {
    if (!cat.plugins.length) continue;
    out.push(`## ${cat.label}`, '');
    for (const pname of cat.plugins) {
      out.push(pluginBlock(byName.get(pname)), '');
    }
  }

  return `${out.join('\n').trimEnd()}\n`;
}
