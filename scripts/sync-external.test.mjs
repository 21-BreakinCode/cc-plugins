import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { syncExternal } from './sync-external.mjs';

function setup() {
  const base = mkdtempSync(join(tmpdir(), 'sync-external-'));
  const repoRoot = join(base, 'repo');
  const plugin = join(base, 'plugin');
  mkdirSync(repoRoot);
  mkdirSync(join(plugin, '.claude-plugin'), { recursive: true });
  writeFileSync(join(plugin, '.claude-plugin/plugin.json'), JSON.stringify({ name: 'demo', version: '1.2.3' }));
  writeFileSync(join(plugin, 'CHANGELOG.md'), '## 1.2.3 - 2026-01-01\n\n- **feat:** x\n');
  mkdirSync(join(plugin, 'skills/go'), { recursive: true });
  writeFileSync(join(plugin, 'skills/go/SKILL.md'), '---\nname: go\ndescription: Go now\n---\n\nSECRET BODY\n');
  mkdirSync(join(plugin, 'skills/help'), { recursive: true });
  writeFileSync(join(plugin, 'skills/help/SKILL.md'), '---\nname: help\ndescription: Helper\nuser-invocable: false\n---\n\nbody\n');
  return { repoRoot, plugin };
}

test('sync copies the manifest, the changelog, and user skills only', () => {
  const { repoRoot, plugin } = setup();
  const version = syncExternal(plugin, repoRoot);
  assert.equal(version, '1.2.3');
  assert.ok(existsSync(join(repoRoot, 'external/demo/.claude-plugin/plugin.json')));
  assert.ok(existsSync(join(repoRoot, 'external/demo/CHANGELOG.md')));
  assert.ok(existsSync(join(repoRoot, 'external/demo/skills/go/SKILL.md')));
  assert.ok(!existsSync(join(repoRoot, 'external/demo/skills/help')));
});

test('sync keeps only the front matter of a skill', () => {
  const { repoRoot, plugin } = setup();
  syncExternal(plugin, repoRoot);
  const copied = readFileSync(join(repoRoot, 'external/demo/skills/go/SKILL.md'), 'utf8');
  assert.ok(copied.trimEnd().endsWith('\n---'));
  assert.ok(!copied.includes('SECRET BODY'));
});

test('sync removes files the plugin no longer has', () => {
  const { repoRoot, plugin } = setup();
  mkdirSync(join(repoRoot, 'external/demo/skills/old'), { recursive: true });
  writeFileSync(join(repoRoot, 'external/demo/skills/old/SKILL.md'), '---\nname: old\n---\n');
  syncExternal(plugin, repoRoot);
  assert.ok(!existsSync(join(repoRoot, 'external/demo/skills/old/SKILL.md')));
});

test('sync without a manifest fails', () => {
  const { repoRoot } = setup();
  const empty = mkdtempSync(join(tmpdir(), 'sync-empty-'));
  assert.throws(() => syncExternal(empty, repoRoot), /plugin\.json/);
});
