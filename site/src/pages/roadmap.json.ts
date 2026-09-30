// Emits /roadmap.json beside /appcast.xml, for the What's new
// window's "Next on my list" (#1813). Its path is permanent from
// the first build that reads it, like the feed's; `NextOnMyList`
// names it on the app's side and check-site-tokens.py holds the two
// together. ROADMAP.md sits at the repo root, outside `site/`, so
// the Cloudflare build watch paths carry it (.claude/rules/site.md).
import type { APIRoute } from "astro";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { parseRoadmap } from "../lib/roadmap.ts";

export const GET: APIRoute = () => {
  // Every build runs from `site/`, the Pages root directory.
  const markdown = readFileSync(
    resolve(process.cwd(), "..", "ROADMAP.md"),
    "utf8",
  );
  return new Response(`${JSON.stringify(parseRoadmap(markdown))}\n`, {
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
};
