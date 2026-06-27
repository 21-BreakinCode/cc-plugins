// Build the install commands the marketplace exposes. There is no batch-install
// command in Claude Code, so "install everything" is a chained one-liner.

export function installOne(pluginName, marketplaceName) {
  return `claude plugin install ${pluginName}@${marketplaceName}`;
}

export function cliOneLiner(model) {
  const { name, repo } = model.marketplace;
  const lines = [`claude plugin marketplace add ${repo}`];
  for (const p of model.plugins) lines.push(installOne(p.name, name));
  return lines.join(' && \\\n  ');
}

// "Update everything": refresh the catalog (by marketplace name, not repo), then
// update each installed plugin. There is no bulk-update command, so it's chained.
export function updateAllCli(model) {
  const { name } = model.marketplace;
  const lines = [`claude plugin marketplace update ${name}`];
  for (const p of model.plugins) lines.push(`claude plugin update ${p.name}@${name}`);
  return lines.join(' && \\\n  ');
}

export function settingsSnippet(model) {
  const { name, repo } = model.marketplace;
  const enabledPlugins = {};
  for (const p of model.plugins) enabledPlugins[`${p.name}@${name}`] = true;
  return {
    extraKnownMarketplaces: {
      [name]: { source: { source: 'github', repo } },
    },
    enabledPlugins,
  };
}
