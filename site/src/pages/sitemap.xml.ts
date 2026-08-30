import type { APIRoute } from "astro";

// Hand-rolled sitemap for the custom (non-Starlight) pages that
// carry locale variants. @astrojs/sitemap covers the /docs/* tree
// in its own sitemap-index.xml and is filtered in astro.config.mjs
// to *only* that tree, so the two files describe disjoint URL sets
// — this one covers the marketing landing and guide pages with
// full hreflang alternates so crawlers see the same graph the
// <link rel="alternate"> tags declare. Legal pages (imprint,
// privacy) are noindex and excluded from both.

const langs = ["en", "de", "ja"] as const;
type Lang = (typeof langs)[number];

// Indexable routes — the path segment *after* the locale prefix.
// "" is the landing page; "nerd" its dev-audience sibling (the
// 2026-08-26 mode split — a separate PATH entry, so its hreflang
// cluster stays within the mode and never cross-links a Simple
// page); "guide" is the guide page; "changelog" is the release
// notes (#873). Every entry here is emitted for ALL THREE locales
// with hreflang alternates, so a path may only join this list
// once its /de/ and /ja/ routes genuinely exist — otherwise the
// alternates advertise URLs that 404.
const paths = ["", "nerd", "guide", "changelog", "compare"];

function urlFor(base: string, lang: Lang, path: string): string {
  // English lives at root, other locales under /<lang>/
  const segments = lang === "en"
    ? (path ? `/${path}/` : "/")
    : (path ? `/${lang}/${path}/` : `/${lang}/`);
  return `${base}${segments}`;
}

export const GET: APIRoute = ({ site }) => {
  // No fallback URL here on purpose: `astro.config.mjs` owns the
  // canonical default (site.md), and a second copy would be
  // unreachable while `site` is set and silently stale the day the
  // domain moves. Let a missing `site` throw, as robots.txt does.
  const base = new URL("/", site).href.replace(/\/$/, "");

  const entries = paths
    .map((p) => {
      const alternates = [
        ...langs.map(
          (l) =>
            `<xhtml:link rel="alternate" hreflang="${l}"` +
            ` href="${urlFor(base, l, p)}"/>`,
        ),
        `<xhtml:link rel="alternate" hreflang="x-default"` +
        ` href="${urlFor(base, "en", p)}"/>`,
      ].join("");
      return langs
        .map(
          (l) =>
            `<url><loc>${urlFor(base, l, p)}</loc>` +
            `${alternates}</url>`,
        )
        .join("");
    })
    .join("");

  const xml =
    `<?xml version="1.0" encoding="UTF-8"?>` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"` +
    ` xmlns:xhtml="http://www.w3.org/1999/xhtml">` +
    `${entries}</urlset>`;

  return new Response(xml, {
    headers: {
      "Content-Type": "application/xml; charset=utf-8",
    },
  });
};
