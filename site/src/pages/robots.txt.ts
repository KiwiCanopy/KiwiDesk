// Emits /robots.txt at build time. Driven by Astro's `site`
// (SITE_URL) so the absolute `Sitemap:` lines follow the
// pages.dev → custom-domain switch without a hand edit. Two
// sitemaps: the hand-rolled sitemap.xml (locale landing + guide
// pages with hreflang alternates) and sitemap-index.xml generated
// by @astrojs/sitemap (auto-registered by Starlight, covers /docs/*).
import type { APIRoute } from "astro";

export const GET: APIRoute = ({ site }) => {
  const base = new URL("/", site).href.replace(/\/$/, "");
  const body = [
    "User-agent: *",
    "Allow: /",
    "",
    `Sitemap: ${base}/sitemap.xml`,
    `Sitemap: ${base}/sitemap-index.xml`,
    "",
  ].join("\n");
  return new Response(body, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
};
