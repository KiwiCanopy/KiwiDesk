// Emits /llms.txt: the user-facing docs pages with title,
// description and size, each linking its raw Markdown copy under
// /llms/ (#3213). For an agent without the MCP; a program reads it,
// so it has no locale route and no sitemap entry. The path is
// permanent, and check-site-tokens.py ▸ check_llms_txt holds the
// built file.
import type { APIRoute } from "astro";
import {
  LLMS_PREFIX,
  llmsPages,
  siteDescription,
  siteTitle,
} from "../lib/llms.ts";

const REPO_DOCS = "https://github.com/KiwiCanopy/KiwiDesk/tree/main/docs";

export const GET: APIRoute = async ({ site }) => {
  const pages = await llmsPages();
  const lines = [
    `# ${siteTitle()}`,
    "",
    `> ${siteDescription()}`,
    "",
    "Each link is one documentation page as raw Markdown, with its",
    "size in bytes. The pages describe the `main` branch. A block",
    "between `:::unreleased` and `:::` describes behavior that no",
    "release has yet. A relative link inside a page resolves against",
    "the page's own URL; a link to a page not listed here is",
    `contributor documentation, readable at ${REPO_DOCS}.`,
  ];
  let group = "";
  for (const page of pages) {
    if (page.group !== group) {
      group = page.group;
      lines.push("", `## ${group}`, "");
    }
    const url = new URL(LLMS_PREFIX + page.path, site).href;
    lines.push(
      `- [${page.title}](${url}): ${page.description} ` +
        `(${page.bytes} bytes)`,
    );
  }
  return new Response(`${lines.join("\n")}\n`, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
};
