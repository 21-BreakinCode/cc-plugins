// Build the install commands the marketplace exposes. There is no batch-install
// command in Claude Code, so "install everything" is a chained one-liner.

export function installOne(pluginName, marketplaceName) {
  return `claude plugin install ${pluginName}@${marketplaceName}`;
}

// A plugin from another marketplace needs that marketplace added first.
export function installExternal(pluginName, marketplaceName, repo) {
  return `claude plugin marketplace add ${repo} && ${installOne(pluginName, marketplaceName)}`;
}

export function cliOneLiner(model) {
  const { name, repo } = model.marketplace;
  const lines = [`claude plugin marketplace add ${repo}`];
  for (const p of model.plugins) {
    if (p.external) lines.push(`claude plugin marketplace add ${p.external.repo}`);
    lines.push(installOne(p.name, p.external?.marketplace ?? name));
  }
  return lines.join(' && \\\n  ');
}

// "Update everything": refresh the catalog (by marketplace name, not repo), then
// update each installed plugin. There is no bulk-update command, so it's chained.
export function updateAllCli(model) {
  const { name } = model.marketplace;
  const lines = [`claude plugin marketplace update ${name}`];
  for (const p of model.plugins) {
    if (p.external) lines.push(`claude plugin marketplace update ${p.external.marketplace}`);
    lines.push(`claude plugin update ${p.name}@${p.external?.marketplace ?? name}`);
  }
  return lines.join(' && \\\n  ');
}

export function settingsSnippet(model) {
  const { name, repo } = model.marketplace;
  const enabledPlugins = {};
  const extraKnownMarketplaces = { [name]: { source: { source: 'github', repo } } };
  for (const p of model.plugins) {
    enabledPlugins[`${p.name}@${p.external?.marketplace ?? name}`] = true;
    if (p.external) {
      extraKnownMarketplaces[p.external.marketplace] = { source: { source: 'github', repo: p.external.repo } };
    }
  }
  return { extraKnownMarketplaces, enabledPlugins };
}
