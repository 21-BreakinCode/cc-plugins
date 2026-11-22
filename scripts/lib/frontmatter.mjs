// Minimal YAML frontmatter reader. We only need top-level scalar keys
// (`description`, `name`); arrays / nested maps are ignored on purpose.
// Block scalars (`|`, `>`) are joined into one line with single spaces.

const STRIP_QUOTES = /^(['"])(.*)\1$/;
const BLOCK_SCALAR = /^[|>][+-]?\d*$/;

export function parseFrontmatter(text) {
  if (typeof text !== 'string' || !text.startsWith('---')) return {};
  const end = text.indexOf('\n---', 3);
  if (end === -1) return {};

  const block = text.slice(3, end);
  const out = {};
  const lines = block.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;

    const colon = trimmed.indexOf(':');
    if (colon === -1) continue;

    const key = trimmed.slice(0, colon).trim();
    let value = trimmed.slice(colon + 1).trim();
    if (key && BLOCK_SCALAR.test(value) && !/^\s/.test(line)) {
      const body = [];
      while (i + 1 < lines.length && (lines[i + 1].trim() === '' || /^\s/.test(lines[i + 1]))) {
        body.push(lines[++i].trim());
      }
      out[key] = body.filter(Boolean).join(' ');
      continue;
    }
    if (!key || value === '' || value.startsWith('[') || value.startsWith('{')) continue;

    const quoted = value.match(STRIP_QUOTES);
    if (quoted) value = quoted[2];
    out[key] = value;
  }
  return out;
}
