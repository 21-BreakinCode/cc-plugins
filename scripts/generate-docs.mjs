#!/usr/bin/env node
// Generates CATALOG.md, per-plugin README.md, and site/data/plugins.json from
// the single source of truth (marketplace.json + content/plugins.content.json +
// command/skill frontmatter). Run via ./scripts/cicd.sh GEN|CHECK.
//
//   node scripts/generate-docs.mjs            # write outputs
//   node scripts/generate-docs.mjs --check    # exit 1 if any output is stale

import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, statSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parseFrontmatter } from './lib/frontmatter.mjs';
import { buildModel, commandName, isDeprecated, firstSentence } from './lib/collect.mjs';
import { renderCatalog } from './lib/render-catalog.mjs';
import { renderReadme } from './lib/render-readme.mjs';
import { buildSiteData } from './lib/site-data.mjs';
import { stampAssets } from './lib/stamp.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..');

function readJSON(rel) {
  return JSON.parse(readFileSync(join(REPO_ROOT, rel), 'utf8'));
}

function listMarkdown(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((f) => f.endsWith('.md'))
    .map((f) => join(dir, f));
}

function makeReadPlugin() {
  return (pluginName, source) => {
    const dir = join(REPO_ROOT, source);
    if (!existsSync(dir) || !statSync(dir).isDirectory()) {
      throw new Error(`Plugin source folder not found: ${source} (for "${pluginName}")`);
    }

    const commands = listMarkdown(join(dir, 'commands'))
      .map((file) => ({
        name: commandName(pluginName, basename(file, '.md')),
        description: parseFrontmatter(readFileSync(file, 'utf8')).description ?? '',
      }))
      .filter((c) => c.description && !isDeprecated(c.description))
      .sort((a, b) => a.name.localeCompare(b.name));

    const skillsDir = join(dir, 'skills');
    const skills = (existsSync(skillsDir) ? readdirSync(skillsDir) : [])
      .map((entry) => join(skillsDir, entry, 'SKILL.md'))
      .filter((f) => existsSync(f))
      .map((file) => {
        const fm = parseFrontmatter(readFileSync(file, 'utf8'));
        return { name: fm.name ?? basename(dirname(file)), description: firstSentence(fm.description, 140) };
      })
      .sort((a, b) => a.name.localeCompare(b.name));

    return { commands, skills };
  };
}

function buildOutputs() {
  const marketplace = readJSON('.claude-plugin/marketplace.json');
  const content = readJSON('content/plugins.content.json');
  const model = buildModel({ marketplace, content, readPlugin: makeReadPlugin() });

  const outputs = [
    { path: 'CATALOG.md', body: renderCatalog(model) },
    { path: 'site/data/plugins.json', body: `${JSON.stringify(buildSiteData(model), null, 2)}\n` },
  ];
  for (const plugin of model.plugins) {
    outputs.push({ path: join(plugin.source, 'README.md'), body: renderReadme(plugin, model) });
  }
  // Re-stamp the static site pages with the current version so each release busts
  // the asset cache. Only the `?v=` query is rewritten; the rest is hand-authored.
  for (const page of ['site/index.html', 'site/plugin.html']) {
    const current = readFileSync(join(REPO_ROOT, page), 'utf8');
    outputs.push({ path: page, body: stampAssets(current, model.marketplace.version) });
  }
  return outputs;
}

function writeOutput({ path, body }) {
  const abs = join(REPO_ROOT, path);
  mkdirSync(dirname(abs), { recursive: true });
  writeFileSync(abs, body);
}

function isStale({ path, body }) {
  const abs = join(REPO_ROOT, path);
  return !existsSync(abs) || readFileSync(abs, 'utf8') !== body;
}

function main() {
  const check = process.argv.includes('--check');
  const outputs = buildOutputs();

  if (check) {
    const stale = outputs.filter(isStale).map((o) => o.path);
    if (stale.length) {
      console.error('✖ Out of sync — run `./scripts/cicd.sh GEN`:');
      for (const p of stale) console.error(`  - ${p}`);
      process.exit(1);
    }
    console.log(`✓ ${outputs.length} generated files in sync`);
    return;
  }

  outputs.forEach(writeOutput);
  console.log(`✓ wrote ${outputs.length} files (CATALOG.md, per-plugin READMEs, site data + stamped HTML)`);
}

main();
