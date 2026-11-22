// Copy the catalog-visible parts of a plugin from another repository into external/<name>/.
import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { parseFrontmatter } from './lib/frontmatter.mjs';

const CLOSING_FENCE = '\n---';
const PLUGIN_SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;

export function syncExternal(pluginFolder, repoRoot) {
  const manifestPath = join(pluginFolder, '.claude-plugin/plugin.json');
  if (!existsSync(manifestPath)) throw new Error(`missing plugin manifest: ${manifestPath}`);
  const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));

  if (typeof manifest.name !== 'string' || !PLUGIN_SLUG.test(manifest.name)) {
    throw new Error(`invalid plugin name in ${manifestPath}: ${JSON.stringify(manifest.name)}`);
  }

  const externalRoot = join(repoRoot, 'external');
  const finalTarget = join(externalRoot, manifest.name);
  const target = join(externalRoot, `.${manifest.name}.tmp-${process.pid}`);
  rmSync(target, { recursive: true, force: true });
  try {
    mkdirSync(join(target, '.claude-plugin'), { recursive: true });
    cpSync(manifestPath, join(target, '.claude-plugin/plugin.json'));
    if (existsSync(join(pluginFolder, 'CHANGELOG.md'))) {
      cpSync(join(pluginFolder, 'CHANGELOG.md'), join(target, 'CHANGELOG.md'));
    }

    const skillsFolder = join(pluginFolder, 'skills');
    const skillDirs = existsSync(skillsFolder) ? readdirSync(skillsFolder, { withFileTypes: true }).filter((d) => d.isDirectory()) : [];
    for (const { name: dir } of skillDirs) {
      const skillPath = join(skillsFolder, dir, 'SKILL.md');
      if (!existsSync(skillPath)) continue;
      const text = readFileSync(skillPath, 'utf8');
      if (!text.startsWith('---')) {
        console.error(`warning: skipped ${skillPath}: no front matter`);
        continue;
      }
      if (parseFrontmatter(text)['user-invocable'] === 'false') continue;
      const frontMatterEnd = text.indexOf(CLOSING_FENCE, 3);
      if (frontMatterEnd === -1) {
        console.error(`warning: skipped ${skillPath}: front matter has no closing ---`);
        continue;
      }
      mkdirSync(join(target, 'skills', dir), { recursive: true });
      writeFileSync(join(target, 'skills', dir, 'SKILL.md'), `${text.slice(0, frontMatterEnd + CLOSING_FENCE.length)}\n`);
    }
    rmSync(finalTarget, { recursive: true, force: true });
    renameSync(target, finalTarget);
  } finally {
    rmSync(target, { recursive: true, force: true });
  }
  return manifest.version;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const pluginFolder = process.argv[2];
  if (!pluginFolder) {
    console.error('usage: sync-external.mjs <plugin folder>');
    process.exit(2);
  }
  const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  try {
    console.log(`synced ${pluginFolder} -> version ${syncExternal(resolve(pluginFolder), repoRoot)}`);
  } catch (error) {
    console.error(error.message);
    process.exit(2);
  }
}
