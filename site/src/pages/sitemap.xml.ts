import type { APIRoute } from "astro";

// Hand-rolled sitemap for the custom (non-Starlight) pages that
// carry locale variants. Starlight's @astrojs/sitemap covers the
// /docs/* tree in its own sitemap-index.xml; this one covers the
// marketing landing and guide pages with full hreflang alternates
// so crawlers see the same graph the <link rel="alternate"> tags
// declare. Legal pages (imprint, privacy) are noindex and excluded.

const langs = ["en", "de", "ja"] as const;
type Lang = (typeof langs)[number];

// Indexable routes — the path segment *after* the locale prefix.
// "" is the landing page; "guide" is the guide page.
const paths = ["", "guide"];

function urlFor(base: string, lang: Lang, path: string): string {
  // English lives at root, other locales under /<lang>/
  const segments = lang === "en"
    ? (path ? `/${path}/` : "/")
    : (path ? `/${lang}/${path}/` : `/${lang}/`);
  return `${base}${segments}`;
}

export const GET: APIRoute = ({ site }) => {
  const base = (
    site?.toString() ?? "https://kiwidesk.kiwicanopy.com"
  ).replace(/\/$/, "");

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
