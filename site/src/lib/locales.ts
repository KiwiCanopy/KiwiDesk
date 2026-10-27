/**
 * The site's locales: the one list the head metadata (hreflang,
 * og:locale) and the sitemap derive from. English is first and
 * lives at the root. `check-site-tokens.py` ▸ `check_locales`
 * holds it equal to the catalogs in `src/i18n/` and every built
 * hreflang link to a page the build emits.
 */
export const locales = ["en", "de", "ja"] as const;

export type Lang = (typeof locales)[number];

/** Each locale's `og:locale` value. */
export const ogLocales: Record<Lang, string> = {
  en: "en_US",
  de: "de_DE",
  ja: "ja_JP",
};

/** The `og:locale:alternate` values for a page in `lang`. */
export function ogLocaleAlternates(lang: Lang): string[] {
  return locales.filter((l) => l !== lang).map((l) => ogLocales[l]);
}

/**
 * `sub` in locale `l`: English at the root, the others under
 * `/<lang>`. `sub` starts and ends with a slash; the default is
 * the locale's home.
 */
export function localePath(l: Lang, sub = "/"): string {
  return `${l === "en" ? "" : `/${l}`}${sub}`;
}
