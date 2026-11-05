import { createHash } from "node:crypto";
import { readdir, readFile, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const INLINE_SCRIPT = /<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi;
const HAS_SRC = /\ssrc\s*=/i;
const CHARSET = /<meta\s+charset\b[^>]*>/i;
const HEAD = /<head\b[^>]*>/i;

/** The page's script policy: its own inline scripts by hash, nothing else. */
export function scriptPolicy(html) {
  const hashes = new Set();
  for (const [, attributes, body] of html.matchAll(INLINE_SCRIPT)) {
    if (HAS_SRC.test(attributes) || !body.trim()) continue;
    const digest = createHash("sha256").update(body).digest("base64");
    hashes.add(`'sha256-${digest}'`);
  }
  return ["script-src 'self' 'wasm-unsafe-eval'", ...hashes].join(" ");
}

/**
 * Adds the policy before any script runs. It stays behind the charset, which
 * browsers only find in a page's first 1024 bytes. Throws on a page with
 * neither anchor, because that page would ship with no script policy.
 */
export function withScriptPolicy(html) {
  const anchor = html.match(CHARSET) ?? html.match(HEAD);
  if (!anchor) throw new Error("no <head> to carry the script policy");
  const end = anchor.index + anchor[0].length;
  const meta =
    '<meta http-equiv="content-security-policy" ' +
    `content="${scriptPolicy(html)}">`;
  return html.slice(0, end) + meta + html.slice(end);
}

async function htmlFiles(directory) {
  const entries = await readdir(directory, {
    recursive: true,
    withFileTypes: true,
  });
  return entries
    .filter((entry) => entry.isFile() && entry.name.endsWith(".html"))
    .map((entry) => join(entry.parentPath, entry.name));
}

/**
 * Drops inline scripts that are not the build's own (#3021). `_headers` cannot
 * vary per page and keeps `'unsafe-inline'`; browsers enforce both policies.
 * `security.csp` cannot do this: it skips `is:inline` scripts, and its style
 * hashes would block the `<style>` mermaid injects.
 */
export function cspInlineScripts() {
  return {
    name: "kiwidesk-csp-inline-scripts",
    hooks: {
      "astro:build:done": async ({ dir, logger }) => {
        const files = await htmlFiles(fileURLToPath(dir));
        for (const file of files) {
          const html = await readFile(file, "utf8");
          await writeFile(file, withScriptPolicy(html));
        }
        logger.info(`script policy on ${files.length} page(s)`);
      },
    },
  };
}
