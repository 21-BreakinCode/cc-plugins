// Stamp a cache-busting `?v=<version>` onto the site's local asset references
// (app.js / styles.css) so a new release invalidates the browser cache. GitHub
// Pages serves assets with a ~10-minute max-age and no way to set custom headers,
// so the query string is the only reliable busting mechanism. Idempotent: an
// existing `?v=…` is replaced, a missing one is added.

const ASSET_RE = /(href|src)="(assets\/(?:app\.js|styles\.css))(?:\?v=[^"]*)?"/g;

export function stampAssets(html, version) {
  return html.replace(ASSET_RE, (_match, attr, path) => `${attr}="${path}?v=${version}"`);
}

// Stamp the live plugin count into the hero's `#count-head` / `#count-cta` spans
// so the static markup matches the marketplace — no-JS visitors, crawlers, and
// link-preview scrapers see the real number instead of a hand-typed one. app.js
// sets the same spans from the data at runtime; this keeps the pre-JS HTML correct.
// Idempotent: any existing digits are replaced.
const COUNT_RE = /(<span id="count-(?:head|cta)"[^>]*>)\d*(<\/span>)/g;

export function stampCounts(html, count) {
  return html.replace(COUNT_RE, (_match, open, close) => `${open}${count}${close}`);
}
