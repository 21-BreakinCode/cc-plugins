// Minimal Markdown → HTML for the site's prose fields: `code`, **bold**, *italic*,
// paragraphs, and `-` / `1.` lists. Text is escaped first, so source prose can never
// inject markup. Anything else (links, headings, nesting) stays literal text.

const LIST_ITEM = /^\s*(?:([-*])|\d+\.)\s+(.*)$/;

function escapeHtml(s) {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function emphasis(html) {
  return html
    .replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>')
    .replace(/(^|[^\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])/g, '$1<em>$2</em>');
}

export function renderInline(md) {
  // split() with one capture group puts every code span at an odd index.
  return String(md ?? '')
    .split(/(`[^`]+`)/)
    .map((part, i) => (i % 2 ? `<code>${escapeHtml(part.slice(1, -1))}</code>` : emphasis(escapeHtml(part))))
    .join('');
}

export function renderBlocks(md) {
  const blocks = [];
  let open = null;
  for (const line of String(md ?? '').split('\n')) {
    if (!line.trim()) {
      open = null;
      continue;
    }
    const item = line.match(LIST_ITEM);
    if (item) {
      const tag = item[1] ? 'ul' : 'ol';
      if (open?.tag !== tag) blocks.push((open = { tag, items: [] }));
      open.items.push(item[2]);
    } else if (open) {
      open.items[open.items.length - 1] += ` ${line.trim()}`;
    } else {
      blocks.push((open = { tag: 'p', items: [line.trim()] }));
    }
  }
  return blocks
    .map(({ tag, items }) =>
      tag === 'p'
        ? `<p>${renderInline(items[0])}</p>`
        : `<${tag}>${items.map((text) => `<li>${renderInline(text)}</li>`).join('')}</${tag}>`,
    )
    .join('');
}
