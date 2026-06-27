// Minimal YAML frontmatter reader. We only need top-level scalar keys
// (`description`, `name`); arrays / nested maps are ignored on purpose.

const STRIP_QUOTES = /^(['"])(.*)\1$/;

export function parseFrontmatter(text) {
  if (typeof text !== 'string' || !text.startsWith('---')) return {};
  const end = text.indexOf('\n---', 3);
  if (end === -1) return {};

  const block = text.slice(3, end);
  const out = {};
  for (const line of block.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const colon = trimmed.indexOf(':');
    if (colon === -1) continue;

    const key = trimmed.slice(0, colon).trim();
    let value = trimmed.slice(colon + 1).trim();
    if (!key || value === '' || value.startsWith('[') || value.startsWith('{')) continue;

    const quoted = value.match(STRIP_QUOTES);
    if (quoted) value = quoted[2];
    out[key] = value;
  }
  return out;
}
