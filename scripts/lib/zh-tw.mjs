// Picks the hand-written zh-TW taglines and summaries that still match their English
// source. Each translation keeps a copy of the English it came from (`translatedFrom`),
// so an English edit without a Chinese edit shows up as a warning instead of shipping
// a stale translation. Input: content/plugins.content.zh-TW.json.

export const TRANSLATED_FIELDS = ['tagline', 'summary'];

const hasText = (value) => typeof value === 'string' && value.trim() !== '';

function checkField(plugin, field, zhPlugins) {
  const english = plugin[field];
  if (!english) return {};
  const entry = zhPlugins[plugin.name]?.[field];
  if (!hasText(entry?.text)) return { warning: `zh-TW missing: ${plugin.name}.${field}` };
  if (entry.translatedFrom !== english) return { warning: `zh-TW stale: ${plugin.name}.${field}` };
  return { text: entry.text };
}

export function pickFreshTranslations(plugins, zhContent) {
  const zhPlugins = zhContent?.plugins ?? {};
  const checks = plugins.flatMap((plugin) =>
    TRANSLATED_FIELDS.map((field) => ({ name: plugin.name, field, ...checkField(plugin, field, zhPlugins) })),
  );

  const freshFieldsOf = (name) =>
    Object.fromEntries(checks.filter((c) => c.name === name && c.text !== undefined).map((c) => [c.field, c.text]));
  const byPlugin = Object.fromEntries(
    plugins.map((p) => [p.name, freshFieldsOf(p.name)]).filter(([, fields]) => Object.keys(fields).length),
  );

  const knownNames = new Set(plugins.map((p) => p.name));
  const unknownWarnings = Object.keys(zhPlugins)
    .filter((name) => !knownNames.has(name))
    .map((name) => `zh-TW unknown plugin: ${name}`);
  const fieldWarnings = checks.filter((c) => c.warning).map((c) => c.warning);

  return { byPlugin, warnings: [...fieldWarnings, ...unknownWarnings] };
}
