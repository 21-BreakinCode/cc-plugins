import { test } from 'node:test';
import assert from 'node:assert/strict';

import { parseFrontmatter } from './lib/frontmatter.mjs';
import { buildModel, commandName, isDeprecated, firstSentence } from './lib/collect.mjs';
import { cliOneLiner, settingsSnippet, installOne, updateAllCli } from './lib/install.mjs';
import { renderReadme } from './lib/render-readme.mjs';
import { renderCatalog } from './lib/render-catalog.mjs';
import { stampAssets } from './lib/stamp.mjs';

const marketplace = {
  name: 'cc-plugins',
  owner: { name: '21-BreakinCode' },
  metadata: { version: '1.7.4' },
  plugins: [
    { name: 'alpha', source: './alpha', description: 'Alpha one-liner', version: '1.0.0' },
    { name: 'hh', source: './handover-handler', description: 'HH one-liner', version: '0.1.5' },
  ],
};

const content = {
  categories: [{ id: 'cat', label: 'Cat' }],
  plugins: {
    alpha: { tagline: 'A tag', summary: 'A summary', category: 'cat', icon: '🅰️', dependsOn: [], config: [] },
    hh: { tagline: 'H tag', summary: 'H summary', category: 'cat', icon: '🤝', dependsOn: [], config: [] },
  },
};

const fakeRead = (name) => ({
  alpha: { commands: [{ name: '/alpha:run', description: 'Run it' }], skills: [] },
  hh: { commands: [{ name: '/hh:new', description: 'New doc' }], skills: [] },
}[name]);

const model = () => buildModel({ marketplace, content, readPlugin: fakeRead });

// --- frontmatter ---
test('parseFrontmatter extracts quoted and bare scalars', () => {
  const fm = parseFrontmatter('---\ndescription: "Hi there"\nname: x\n---\nbody text');
  assert.equal(fm.description, 'Hi there');
  assert.equal(fm.name, 'x');
});

test('parseFrontmatter returns {} when no frontmatter', () => {
  assert.deepEqual(parseFrontmatter('# no frontmatter here'), {});
});

// --- small helpers ---
test('commandName composes slash form', () => {
  assert.equal(commandName('harness', 'check'), '/harness:check');
});

test('isDeprecated detects the marker', () => {
  assert.equal(isDeprecated('[DEPRECATED] moved to /harness:check'), true);
  assert.equal(isDeprecated('Run the thing'), false);
});

test('firstSentence shortens long descriptions', () => {
  assert.equal(firstSentence('One sentence. Two sentence.', 160), 'One sentence.');
  assert.ok(firstSentence('x'.repeat(500), 140).length <= 141);
});

// --- buildModel ---
test('buildModel derives repo from owner + marketplace name', () => {
  assert.equal(model().marketplace.repo, '21-BreakinCode/cc-plugins');
  assert.equal(model().marketplace.version, '1.7.4');
});

test('buildModel honors an explicit metadata.repo, decoupled from the @name', () => {
  const mp = {
    ...marketplace,
    name: '21-breakincode',
    metadata: { version: '1.7.4', repo: '21-BreakinCode/cc-plugins' },
  };
  const m = buildModel({ marketplace: mp, content, readPlugin: fakeRead });
  assert.equal(m.marketplace.repo, '21-BreakinCode/cc-plugins');
  assert.equal(m.plugins.find((p) => p.name === 'alpha').install, 'claude plugin install alpha@21-breakincode');
});

test('buildModel produces per-plugin install commands using published name', () => {
  const m = model();
  const alpha = m.plugins.find((p) => p.name === 'alpha');
  const hh = m.plugins.find((p) => p.name === 'hh');
  assert.equal(alpha.install, 'claude plugin install alpha@cc-plugins');
  assert.equal(hh.install, 'claude plugin install hh@cc-plugins');
});

test('buildModel throws when a marketplace plugin has no content entry', () => {
  const broken = { ...content, plugins: { alpha: content.plugins.alpha } };
  assert.throws(() => buildModel({ marketplace, content: broken, readPlugin: fakeRead }), /hh/);
});

test('buildModel groups plugins under categories', () => {
  const cat = model().categories.find((c) => c.id === 'cat');
  assert.deepEqual(cat.plugins.sort(), ['alpha', 'hh']);
});

// --- install ---
test('cliOneLiner adds the marketplace then installs every plugin', () => {
  const out = cliOneLiner(model());
  assert.match(out, /claude plugin marketplace add 21-BreakinCode\/cc-plugins/);
  assert.match(out, /claude plugin install alpha@cc-plugins/);
  assert.match(out, /claude plugin install hh@cc-plugins/);
});

test('settingsSnippet registers marketplace and enables all plugins', () => {
  const s = settingsSnippet(model());
  assert.equal(s.extraKnownMarketplaces['cc-plugins'].source.repo, '21-BreakinCode/cc-plugins');
  assert.equal(s.extraKnownMarketplaces['cc-plugins'].source.source, 'github');
  assert.equal(s.enabledPlugins['alpha@cc-plugins'], true);
  assert.equal(s.enabledPlugins['hh@cc-plugins'], true);
});

test('installOne builds a single install command', () => {
  assert.equal(installOne('alpha', 'cc-plugins'), 'claude plugin install alpha@cc-plugins');
});

test('updateAllCli refreshes the catalog by name then updates every plugin', () => {
  const out = updateAllCli(model());
  assert.match(out, /claude plugin marketplace update cc-plugins/);
  assert.match(out, /claude plugin update alpha@cc-plugins/);
  assert.match(out, /claude plugin update hh@cc-plugins/);
  assert.doesNotMatch(out, /marketplace add/);
});

// --- render-readme ---
test('renderReadme shows Commands for a command plugin', () => {
  const alpha = model().plugins.find((p) => p.name === 'alpha');
  const md = renderReadme(alpha, model());
  assert.match(md, /^# alpha/m);
  assert.match(md, /## Commands/);
  assert.match(md, /\/alpha:run/);
  assert.match(md, /claude plugin install alpha@cc-plugins/);
  assert.doesNotMatch(md, /## Skills/);
});

test('renderReadme shows Skills for a skill-only plugin', () => {
  const skillPlugin = {
    name: 'designer', version: '1.0.0', tagline: 't', summary: 's',
    category: 'cat', icon: '🎨', install: 'claude plugin install designer@cc-plugins',
    commands: [], skills: [{ name: 'designer', description: 'Design advisor' }],
    dependsOn: [], config: [],
  };
  const md = renderReadme(skillPlugin, model());
  assert.match(md, /## Skills/);
  assert.doesNotMatch(md, /## Commands/);
});

test('renderReadme renders config table and depends-on when present', () => {
  const p = {
    name: 'cfg', version: '1.0.0', tagline: 't', summary: 's', category: 'cat', icon: '⚙️',
    install: 'claude plugin install cfg@cc-plugins', commands: [{ name: '/cfg:go', description: 'Go' }],
    skills: [], dependsOn: ['alpha'], config: [{ name: 'CFG_X', default: '1', description: 'desc x' }],
  };
  const md = renderReadme(p, model());
  assert.match(md, /## Configuration/);
  assert.match(md, /CFG_X/);
  assert.match(md, /## Depends on/);
  assert.match(md, /alpha/);
});

// --- render-catalog ---
test('renderCatalog lists every plugin, version and the install-all block', () => {
  const md = renderCatalog(model());
  assert.match(md, /alpha/);
  assert.match(md, /hh/);
  assert.match(md, /1\.7\.4/);
  assert.match(md, /claude plugin marketplace add 21-BreakinCode\/cc-plugins/);
  assert.match(md, /## Update everything/);
  assert.match(md, /claude plugin marketplace update cc-plugins/);
});

// --- stamp ---
test('stampAssets adds, replaces, and is idempotent on the version query', () => {
  const fresh = '<link href="assets/styles.css" /><script src="assets/app.js"></script>';
  const once = stampAssets(fresh, '1.7.4');
  assert.match(once, /href="assets\/styles\.css\?v=1\.7\.4"/);
  assert.match(once, /src="assets\/app\.js\?v=1\.7\.4"/);
  // Re-stamping with a new version replaces the old query, not appends.
  const bumped = stampAssets(once, '1.7.5');
  assert.match(bumped, /assets\/app\.js\?v=1\.7\.5"/);
  assert.doesNotMatch(bumped, /1\.7\.4/);
  // Same version twice is a no-op.
  assert.equal(stampAssets(once, '1.7.4'), once);
});
