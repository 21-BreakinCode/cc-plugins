// Stamp a cache-busting `?v=<version>` onto the site's local asset references
// (app.js / styles.css) so a new release invalidates the browser cache. GitHub
// Pages serves assets with a ~10-minute max-age and no way to set custom headers,
// so the query string is the only reliable busting mechanism. Idempotent: an
// existing `?v=…` is replaced, a missing one is added.

const ASSET_RE = /(href|src)="(assets\/(?:app\.js|styles\.css))(?:\?v=[^"]*)?"/g;

export function stampAssets(html, version) {
  return html.replace(ASSET_RE, (_match, attr, path) => `${attr}="${path}?v=${version}"`);
}
