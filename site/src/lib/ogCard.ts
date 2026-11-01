/**
 * The link-preview card every page wears: one image per page
 * family and locale, its pixel size and its alt text. The one
 * place a page picks its card — `check-site-tokens.py` ▸
 * `check_og_images` holds the built pages to the same mapping.
 * Masters and renderer: `assets/generate-og.sh`.
 */
import type { ImageMetadata } from "astro";
import bannerEn from "../assets/brand/og-banner.jpg";
import bannerDe from "../assets/brand/og-banner.de.jpg";
import bannerJa from "../assets/brand/og-banner.ja.jpg";
import looksEn from "../assets/brand/og-looks.jpg";
import looksDe from "../assets/brand/og-looks.de.jpg";
import looksJa from "../assets/brand/og-looks.ja.jpg";
import compareEn from "../assets/brand/og-compare.jpg";
import compareDe from "../assets/brand/og-compare.de.jpg";
import compareJa from "../assets/brand/og-compare.ja.jpg";
import en from "../i18n/en.json";
import de from "../i18n/de.json";
import ja from "../i18n/ja.json";
import type { Lang } from "./locales";

export type CardFamily = "banner" | "looks" | "compare";

/** Every family names every locale. The type says so in an editor;
 * no site gate runs tsc, so `ogCard` refuses a gap at build time. */
const cards: Record<CardFamily, Record<Lang, ImageMetadata>> = {
  banner: { en: bannerEn, de: bannerDe, ja: bannerJa },
  looks: { en: looksEn, de: looksDe, ja: looksJa },
  compare: { en: compareEn, de: compareDe, ja: compareJa },
};

const catalogs: Record<Lang, Record<string, string>> = { en, de, ja };

export interface OgCard {
  /** Absolute URL, as `og:image` requires. */
  url: string;
  width: number;
  height: number;
  /** Describes the card's own text in the card's language. */
  alt: string;
}

export function ogCard(
  family: CardFamily,
  lang: Lang,
  site: URL | undefined,
): OgCard {
  const image = cards[family]?.[lang];
  const key = `og_alt_${family}`;
  const alt = catalogs[lang]?.[key];
  if (!image || !alt) {
    throw new Error(
      `ogCard: no ${family} card or ${key} for "${lang}" — render ` +
        "it with assets/generate-og.sh and add the catalog key",
    );
  }
  return {
    url: new URL(image.src, site).href,
    width: image.width,
    height: image.height,
    alt,
  };
}
