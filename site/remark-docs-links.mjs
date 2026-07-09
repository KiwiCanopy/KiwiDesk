import { visit } from "unist-util-visit";
import path from "node:path";

// The canonical docs in repo-root docs/ are authored for GitHub:
// they open with a `# H1` and cross-link with relative `.md`
// paths (e.g. `user-guide.md`, `../lua-reference.md`). Starlight
// renders that same source (symlinked in) but synthesizes its own
// H1 from frontmatter `title:` and does NOT rewrite `.md` links —
// so without this plugin every page shows two H1s and every prose
// cross-link 404s on the deployed site.
//
// This remark plugin fixes both on the Starlight side only, so the
// canonical files stay correct on GitHub:
//   1. Drops the first top-level H1 (Starlight already renders the
//      title).
//   2. Rewrites relative `*.md` links to Starlight's directory
//      routes (`/docs/<slug>/`), preserving any `#anchor`.
export function remarkDocsLinks() {
  return (tree, file) => {
    // 1. Remove the first depth-1 heading.
    let removed = false;
    tree.children = tree.children.filter((node) => {
      if (!removed && node.type === "heading" && node.depth === 1) {
        removed = true;
        return false;
      }
      return true;
    });

    // 2. Derive this page's slug (route path under /) from its
    //    source path. Works whether Astro reports the symlink path
    //    (.../src/content/docs/docs/x.md) or the resolved repo path
    //    (.../KiwiDesk/docs/x.md) — both end with `docs/<...>.md`.
    const src = file.path ?? file.history?.[0] ?? "";
    const norm = src.split(path.sep).join("/");
    const marker = "/content/docs/";
    let slug;
    const i = norm.indexOf(marker);
    if (i !== -1) {
      slug = norm.slice(i + marker.length);
    } else {
      const j = norm.lastIndexOf("/docs/");
      slug = j !== -1 ? "docs/" + norm.slice(j + "/docs/".length) : "";
    }
    slug = slug.replace(/\.md$/, ""); // e.g. docs/recipes/misc
    const curDir = slug.includes("/")
      ? slug.slice(0, slug.lastIndexOf("/"))
      : "";

    // 3. Rewrite relative `.md` links to route form.
    visit(tree, "link", (node) => {
      const url = node.url;
      if (
        !url ||
        /^[a-z]+:/i.test(url) || // http:, https:, mailto:, …
        url.startsWith("//") ||
        url.startsWith("/") ||
        url.startsWith("#")
      ) {
        return;
      }
      const hashAt = url.indexOf("#");
      const rel = hashAt === -1 ? url : url.slice(0, hashAt);
      const hash = hashAt === -1 ? "" : url.slice(hashAt);
      if (!/\.md$/.test(rel)) return;

      let target = path.posix.normalize(path.posix.join(curDir, rel));
      target = target.replace(/\.md$/, "").replace(/\/index$/, "");
      node.url = "/" + target + "/" + hash;
    });
  };
}
