// Shapes the model into the JSON the static site consumes (site/data/plugins.json).
// Same content as CATALOG.md, in machine-readable form. Prose fields arrive as
// Markdown and leave as `*Html` fields, so app.js inserts them without re-escaping.

import { renderInline, renderBlocks } from './markdown.mjs';

function parseChangelog(md) {
  if (!md) return [];
  const versions = [];
  let current = null;
  for (const line of md.split('\n')) {
    const heading = line.match(/^## (.+?) [—-] (\d{4}-\d{2}-\d{2})$/);
    if (heading) {
      current = { version: heading[1], date: heading[2], changes: [] };
      versions.push(current);
      continue;
    }
    if (!current) continue;
    const bullet = line.match(/^- \*\*(\w+):\*\* (.+)$/);
    const lastChange = current.changes[current.changes.length - 1];
    if (bullet) current.changes.push({ type: bullet[1], text: bullet[2] });
    else if (/^\s+\S/.test(line) && lastChange) lastChange.text += ` ${line.trim()}`;
  }
  return versions.map((v) => ({
    ...v,
    changes: v.changes.map((c) => ({ type: c.type, html: renderInline(c.text) })),
  }));
}

const withDescriptionHtml = ({ description, ...rest }) => ({ ...rest, descriptionHtml: renderInline(description) });

export function buildSiteData(model) {
  return {
    marketplace: model.marketplace,
    installAll: model.installAll,
    categories: model.categories,
    plugins: model.plugins.map((p) => ({
      name: p.name,
      version: p.version,
      taglineHtml: renderInline(p.tagline),
      summaryHtml: renderBlocks(p.summary),
      category: p.category,
      install: p.install,
      oneLiner: p.oneLiner,
      commands: p.commands.map(withDescriptionHtml),
      skills: p.skills.map(withDescriptionHtml),
      dependsOn: p.dependsOn,
      config: p.config.map(withDescriptionHtml),
      changelog: parseChangelog(p.changelog),
    })),
  };
}
