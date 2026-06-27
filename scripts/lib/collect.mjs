import { installOne, cliOneLiner, settingsSnippet, updateAllCli } from './install.mjs';

export function commandName(pluginName, fileBase) {
  return `/${pluginName}:${fileBase}`;
}

export function isDeprecated(description) {
  return String(description ?? '').trim().startsWith('[DEPRECATED]');
}

export function firstSentence(text, max = 160) {
  const t = String(text ?? '').trim();
  const dot = t.indexOf('. ');
  let s = dot === -1 ? t : t.slice(0, dot + 1);
  if (s.length > max) s = `${s.slice(0, max - 1).trimEnd()}…`;
  return s;
}

// readPlugin(name, source) -> { commands: [{name, description}], skills: [{name, description}] }
// is injected so the model builder stays pure and testable without the filesystem.
export function buildModel({ marketplace, content, readPlugin }) {
  if (!marketplace?.plugins?.length) throw new Error('marketplace.json has no plugins');
  if (!content?.plugins) throw new Error('content file has no `plugins` map');

  const name = marketplace.name;
  // The marketplace name (the @suffix) is decoupled from the GitHub repo: an explicit
  // metadata.repo wins, else fall back to owner/name (when they happen to match).
  const repo = marketplace.metadata?.repo ?? `${marketplace.owner.name}/${name}`;
  const version = marketplace.metadata?.version ?? '0.0.0';

  const plugins = marketplace.plugins.map((entry) => {
    const c = content.plugins[entry.name];
    if (!c) {
      throw new Error(
        `Missing content entry for plugin "${entry.name}" — add it to content/plugins.content.json`,
      );
    }
    const harvested = readPlugin(entry.name, entry.source) ?? { commands: [], skills: [] };
    return {
      name: entry.name,
      source: entry.source,
      version: entry.version ?? version,
      oneLiner: entry.description ?? '',
      tagline: c.tagline ?? '',
      summary: c.summary ?? '',
      category: c.category ?? '',
      dependsOn: c.dependsOn ?? [],
      config: c.config ?? [],
      install: installOne(entry.name, name),
      commands: harvested.commands ?? [],
      skills: harvested.skills ?? [],
    };
  });

  const categories = (content.categories ?? []).map((cat) => ({
    id: cat.id,
    label: cat.label,
    plugins: plugins.filter((p) => p.category === cat.id).map((p) => p.name),
  }));

  const model = { marketplace: { name, repo, version }, categories, plugins };
  model.installAll = { cli: cliOneLiner(model), settings: settingsSnippet(model), update: updateAllCli(model) };
  return model;
}
