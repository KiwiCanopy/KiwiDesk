// @ts-check
import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import icon from "astro-icon";
import mermaid from "astro-mermaid";
import { remarkDocsLinks } from "./remark-docs-links.mjs";

// The public site URL. Override with SITE_URL at build time
// (Cloudflare Pages sets it per environment); the default is
// the free pages.dev subdomain until a custom domain lands.
const site = process.env.SITE_URL ?? "https://kiwidesk.pages.dev";

export default defineConfig({
  site,
  // Rewrite the canonical docs' GitHub-style `.md` links to
  // Starlight routes and drop their duplicate H1 (see the plugin).
  markdown: { remarkPlugins: [remarkDocsLinks] },
  integrations: [
    // Renders ```mermaid fenced blocks in docs as diagrams,
    // client-side, with light/dark synced to the site theme
    // (`autoTheme` reads the `data-theme` Starlight sets). Must
    // precede Starlight so its remark/rehype pass runs first
    // (astro-mermaid ordering requirement). GitHub renders the
    // same fenced blocks natively, so the source stays one form.
    mermaid({ theme: "forest", autoTheme: true }),
    icon(),
    starlight({
      title: "KiwiDesk",
      description:
        "A tiling window manager for macOS — flat arrays, " +
        "Lua config, six layouts.",
      // Icon-only mark in the header (the stacked wordmark is
      // too tall for the top bar); the "KiwiDesk" title sits
      // beside it. Masters are symlinked from repo-root assets/.
      // One mark in both themes (#479) — the symbol holds its
      // kiwi green, so there is no light/dark pair to declare.
      logo: { src: "./src/assets/brand/logo.svg" },
      favicon: "/favicon.svg",
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/KiwiCanopy/KiwiDesk",
        },
      ],
      // Append a quiet KiwiCanopy parent-brand mention below the
      // default docs footer (see src/components/Footer.astro).
      components: {
        Footer: "./src/components/Footer.astro",
      },
      customCss: ["./src/styles/theme.css"],
      // Docs live under /docs/* (repo docs/ is symlinked into
      // src/content/docs/docs/). The landing page at / is a
      // custom Astro page, not Starlight.
      sidebar: [
        {
          label: "Start Here",
          items: [
            { label: "Overview", slug: "docs" },
            { label: "User Guide", slug: "docs/user-guide" },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "Lua Reference", slug: "docs/lua-reference" },
            { label: "CLI & IPC", slug: "docs/cli" },
            {
              // A user-facing page of its own (bugs-by-design):
              // split out of the contributor Design Decisions doc
              // so it owns a real sidebar entry + active state.
              label: "Accepted Limitations",
              slug: "docs/accepted-limitations",
            },
          ],
        },
        {
          label: "Recipes",
          items: [
            { label: "Overview", slug: "docs/recipes" },
            { label: "SketchyBar", slug: "docs/recipes/sketchybar" },
            {
              label: "JankyBorders",
              slug: "docs/recipes/jankyborders",
            },
            { label: "More Recipes", slug: "docs/recipes/misc" },
          ],
        },
        {
          label: "Contributing",
          items: [
            { label: "Architecture", slug: "docs/architecture" },
            {
              label: "Design Decisions",
              slug: "docs/design-decisions",
            },
            {
              label: "Settings UI Patterns",
              slug: "docs/ui-patterns",
            },
            { label: "Translating", slug: "docs/translating" },
          ],
        },
      ],
    }),
  ],
});
