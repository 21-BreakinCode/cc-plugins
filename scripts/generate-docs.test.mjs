import { test } from 'node:test';
import assert from 'node:assert/strict';

import { parseFrontmatter } from './lib/frontmatter.mjs';
import { buildModel, commandName, isDeprecated, firstSentence } from './lib/collect.mjs';
import { cliOneLiner, settingsSnippet, installOne, updateAllCli } from './lib/install.mjs';
import { renderReadme } from './lib/render-readme.mjs';
import { renderCatalog } from './lib/render-catalog.mjs';
import { stampAssets, stampCounts } from './lib/stamp.mjs';
import { buildSiteData } from './lib/site-data.mjs';
import { pickFreshTranslations } from './lib/zh-tw.mjs';
import { renderInline, renderBlocks } from './lib/markdown.mjs';

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

test('stampCounts injects the live plugin count into both hero spans', () => {
  const html = 'Install <span id="count-head">99</span> tools, <span id="count-cta">99</span> plugins';
  const out = stampCounts(html, 6);
  assert.match(out, /<span id="count-head">6<\/span>/);
  assert.match(out, /<span id="count-cta">6<\/span>/);
  assert.doesNotMatch(out, /99/);
  // Spans that aren't the count spans are left untouched.
  assert.equal(stampCounts('<span id="other">1</span>', 6), '<span id="other">1</span>');
});

// --- site data ---
const siteDataFor = (overrides) =>
  buildSiteData({ plugins: [{ name: 'alpha', tagline: '', summary: '', commands: [], skills: [], config: [], changelog: '', ...overrides }] });

test('buildSiteData parses changelog headings with an em-dash or a hyphen before the date', () => {
  const changelog = [
    '## 0.3.0 - 2026-09-25',
    '- **feat:** newest, hyphen heading',
    '## 0.2.0 — 2026-09-24',
    '- **fix:** middle, em-dash heading',
    '## 0.1.0 - 2026-09-20',
    '- **feat:** oldest, hyphen heading',
  ].join('\n');
  const [plugin] = siteDataFor({ changelog }).plugins;
  assert.deepEqual(plugin.changelog, [
    { version: '0.3.0', date: '2026-09-25', changes: [{ type: 'feat', html: 'newest, hyphen heading' }] },
    { version: '0.2.0', date: '2026-09-24', changes: [{ type: 'fix', html: 'middle, em-dash heading' }] },
    { version: '0.1.0', date: '2026-09-20', changes: [{ type: 'feat', html: 'oldest, hyphen heading' }] },
  ]);
});

test('buildSiteData joins wrapped changelog lines into their bullet and renders inline Markdown', () => {
  const changelog = [
    '## 2.2.0 — 2026-08-10',
    '- **feat:** snapshots into `.autoresearch/snapshot/` instead',
    '  of committing, not just a git repo.',
    '- **test:** a discard reverts to the last *kept* state.',
  ].join('\n');
  const [plugin] = siteDataFor({ changelog }).plugins;
  assert.deepEqual(plugin.changelog[0].changes, [
    { type: 'feat', html: 'snapshots into <code>.autoresearch/snapshot/</code> instead of committing, not just a git repo.' },
    { type: 'test', html: 'a discard reverts to the last <em>kept</em> state.' },
  ]);
});

test('buildSiteData renders prose fields to HTML', () => {
  const [plugin] = siteDataFor({
    tagline: 'Flags **FACT:** claims',
    summary: 'Runs `refresh-policy`.',
    commands: [{ name: '/x:run', description: 'Set to `0`' }],
    config: [{ name: 'X_DIR', default: '—', description: 'Where `distill` writes' }],
  }).plugins;
  assert.equal(plugin.taglineHtml, 'Flags <strong>FACT:</strong> claims');
  assert.equal(plugin.summaryHtml, '<p>Runs <code>refresh-policy</code>.</p>');
  assert.deepEqual(plugin.commands, [{ name: '/x:run', descriptionHtml: 'Set to <code>0</code>' }]);
  assert.deepEqual(plugin.config, [{ name: 'X_DIR', default: '—', descriptionHtml: 'Where <code>distill</code> writes' }]);
});

// --- markdown ---
test('renderInline escapes HTML and never formats inside code spans', () => {
  assert.equal(renderInline('a <b> & `x < **y**`'), 'a &lt;b&gt; &amp; <code>x &lt; **y**</code>');
  assert.equal(renderInline('**FACT:** and *kept*'), '<strong>FACT:</strong> and <em>kept</em>');
  // Stray stars and an unclosed backtick stay literal text.
  assert.equal(renderInline('*.md and *.json, 2 * 3, `open'), '*.md and *.json, 2 * 3, `open');
});

test('renderBlocks builds paragraphs and bullet / numbered lists', () => {
  const md = ['Intro line', 'continues here.', '', '- one', '- two', '  wrapped', '', '1. first', '2. second'].join('\n');
  assert.equal(
    renderBlocks(md),
    '<p>Intro line continues here.</p><ul><li>one</li><li>two wrapped</li></ul><ol><li>first</li><li>second</li></ol>',
  );
  assert.equal(renderBlocks(''), '');
});

// --- zh-TW translations ---
const englishPlugin = (overrides = {}) => ({ name: 'alpha', tagline: 'A tag', summary: 'A summary', ...overrides });
const freshAlpha = {
  tagline: { text: '標語', translatedFrom: 'A tag' },
  summary: { text: '摘要', translatedFrom: 'A summary' },
};

test('pickFreshTranslations keeps a translation whose source still matches the English', () => {
  assert.deepEqual(pickFreshTranslations([englishPlugin()], { plugins: { alpha: freshAlpha } }), {
    byPlugin: { alpha: { tagline: '標語', summary: '摘要' } },
    warnings: [],
  });
});

test('pickFreshTranslations drops and reports a translation whose English changed', () => {
  const zhContent = { plugins: { alpha: { ...freshAlpha, summary: { text: '舊摘要', translatedFrom: 'An old summary' } } } };
  assert.deepEqual(pickFreshTranslations([englishPlugin()], zhContent), {
    byPlugin: { alpha: { tagline: '標語' } },
    warnings: ['zh-TW stale: alpha.summary'],
  });
});

test('pickFreshTranslations reports every field of a plugin with no entry', () => {
  assert.deepEqual(pickFreshTranslations([englishPlugin()], { plugins: {} }), {
    byPlugin: {},
    warnings: ['zh-TW missing: alpha.tagline', 'zh-TW missing: alpha.summary'],
  });
});

test('pickFreshTranslations treats a blank or non-string text as missing', () => {
  const zhContent = {
    plugins: {
      alpha: {
        tagline: { text: '   ', translatedFrom: 'A tag' },
        summary: { text: 42, translatedFrom: 'A summary' },
      },
    },
  };
  assert.deepEqual(pickFreshTranslations([englishPlugin()], zhContent).warnings, [
    'zh-TW missing: alpha.tagline',
    'zh-TW missing: alpha.summary',
  ]);
});

test('pickFreshTranslations reports an entry for a plugin not in the marketplace', () => {
  const zhContent = { plugins: { alpha: freshAlpha, ghost: { tagline: { text: '幽靈', translatedFrom: 'Ghost' } } } };
  assert.deepEqual(pickFreshTranslations([englishPlugin()], zhContent).warnings, ['zh-TW unknown plugin: ghost']);
});

test('pickFreshTranslations expects no entry for an empty English field', () => {
  const zhContent = { plugins: { alpha: { tagline: freshAlpha.tagline } } };
  assert.deepEqual(pickFreshTranslations([englishPlugin({ summary: '' })], zhContent), {
    byPlugin: { alpha: { tagline: '標語' } },
    warnings: [],
  });
});

test('pickFreshTranslations treats a file with no plugins map as empty', () => {
  assert.deepEqual(pickFreshTranslations([englishPlugin()], {}).warnings, [
    'zh-TW missing: alpha.tagline',
    'zh-TW missing: alpha.summary',
  ]);
});

const sitePlugin = (name) => ({ name, tagline: 'T', summary: 'S', commands: [], skills: [], config: [], changelog: '' });

test('buildSiteData renders zhTW fields with the same Markdown escaping as English', () => {
  const siteData = buildSiteData(
    { plugins: [sitePlugin('alpha'), sitePlugin('beta')] },
    { alpha: { tagline: '執行 `run` <b>', summary: '**重點**摘要' } },
  );
  const [alpha, beta] = siteData.plugins;
  assert.deepEqual(alpha.zhTW, {
    taglineHtml: '執行 <code>run</code> &lt;b&gt;',
    summaryHtml: '<p><strong>重點</strong>摘要</p>',
  });
  assert.equal('zhTW' in beta, false);
});

test('buildSiteData leaves a stale field out of zhTW', () => {
  const siteData = buildSiteData({ plugins: [sitePlugin('alpha')] }, { alpha: { tagline: '標語' } });
  assert.deepEqual(siteData.plugins[0].zhTW, { taglineHtml: '標語' });
});
