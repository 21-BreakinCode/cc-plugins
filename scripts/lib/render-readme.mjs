// Renders a full per-plugin README from the model. The generator owns these
// files end to end — the human-authored prose lives in content/plugins.content.json.

function sourceBasename(source) {
  return String(source).replace(/^\.\//, '');
}

function depList(plugin, model) {
  const byName = new Map(model.plugins.map((p) => [p.name, p]));
  return plugin.dependsOn.map((dep) => {
    const target = byName.get(dep);
    if (target) return `- [\`${dep}\`](../${sourceBasename(target.source)}/README.md)`;
    return `- \`${dep}\` _(external)_`;
  });
}

function surface(plugin) {
  if (plugin.commands.length) {
    const items = plugin.commands.map((c) => `- **\`${c.name}\`** — ${c.description}`);
    return `## Commands\n\n${items.join('\n')}`;
  }
  if (plugin.skills.length) {
    const items = plugin.skills.map((s) => `- **\`${s.name}\`** — ${s.description}`);
    return `## Skills\n\nThis plugin activates automatically — no slash commands.\n\n${items.join('\n')}`;
  }
  return '## Commands\n\n_This plugin activates automatically — no slash commands._';
}

function configTable(plugin) {
  if (!plugin.config.length) return '';
  const rows = plugin.config.map((c) => `| \`${c.name}\` | \`${c.default}\` | ${c.description} |`);
  return [
    '## Configuration',
    '',
    '| Variable | Default | Description |',
    '|---|---|---|',
    ...rows,
  ].join('\n');
}

export function renderReadme(plugin, model) {
  const blocks = [
    `# ${plugin.name}`,
    `> ${plugin.tagline}`,
    plugin.summary,
    ['## Install', '', '```bash', plugin.install, '```'].join('\n'),
    surface(plugin),
  ];

  const config = configTable(plugin);
  if (config) blocks.push(config);

  const deps = depList(plugin, model);
  if (deps.length) blocks.push(['## Depends on', '', ...deps].join('\n'));

  blocks.push(
    `---\n\nPart of the [${model.marketplace.name}](../README.md) marketplace. ` +
      'Generated from `content/plugins.content.json` + command frontmatter — do not edit by hand.',
  );

  return `${blocks.join('\n\n')}\n`;
}
