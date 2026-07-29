---
paths:
  - "site/**"
  # The Node version would be restated here, not in site/.
  - ".github/workflows/site.yml"
---

# Marketing / docs site (`site/`)

Canonical for this subsystem (AGENTS.md §3 and §5 index it).

## `docs/` reaches the site through a symlink

Doc *content* edits flow to the site automatically — **never
hand-copy a doc into `site/`**. The symlink is not full coverage
though:

- a **new doc page** needs a sidebar entry in
  `site/astro.config.mjs`;
- **site-only surfaces** (the landing page, cross-page callouts)
  are updated in the same change set when a feature warrants
  surfacing there — e.g. a new layout mode (#128) adds its
  user-guide / reference prose *and* whatever nav or callout makes
  it findable.
- `site/src/assets/brand` is a symlink to the repo's `assets/`.
- Site i18n is hand-maintained (not generated from the app
  catalogs).

## Build

Run `npm run build` in `site/` when you touch either, after
`nvm use` there. **`site/.nvmrc` is the one copy of the Node
version** — read by that command and by CI's `node-version-file`,
so never restate the number in prose or in `site.yml`.

Astro refuses anything below 22.12, and an install performed on an
older Node resolves the wrong platform binaries, so a later
`nvm use` alone still fails on a missing native binding — delete
`node_modules` and reinstall if that happens.

**Never add a second Node pin file.** Cloudflare Pages resolves
`.node-version` ahead of `.nvmrc`, so a duplicate does not merely
restate the number — it silently *wins* the deploy while every
local and CI signal keeps reading `.nvmrc`. This repo carried
`.node-version` at 20 against `.nvmrc` at 24 until #106, and
Astro refuses below 22.12 as above. `package.json` → `engines` is
not a safe alternative either: the Pages v3 build image does not
read it (Cloudflare's own docs list it as unsupported,
2026-07-30).

## Cloudflare Pages: the dashboard is not a config surface (#106)

`site/wrangler.toml` is committed, and its presence makes Pages
source project config from the file and **ignore environment
variables added in the dashboard** — a `SITE_URL` set there never
reaches a build (observed on the KiwiCanopy launch, 2026-07-29).

So configure the site in the repo, not the dashboard: the
canonical URL is the committed default in `astro.config.mjs` and
`SITE_URL` is a local override for one-off builds only. That
wrangler.toml holds the one-time setup fields too, including the
one that reads wrong — *Build output directory* is relative to
*Root directory*, so it is `dist`, never `site/dist`.

## The 404 is a user page, so withdraw Starlight's (#635)

`src/pages/404.astro` and `disable404Route: true` in
`astro.config.mjs` move together. A user page already outranks
Starlight's injected route, so the override *appears* to work with
the option missing — but Astro then logs a duplicate-route
collision it says "will result in a hard error in following
versions", i.e. the site builds until a minor bump and then does
not.

Static hosting serves that one page for **every** unmatched path,
including `/de/*` and `/ja/*`, so it cannot pick a locale from the
URL: all three locales render together instead. Which is also why
it must not carry `Landing.astro`'s language-resolve script — that
redirects a stored-locale visitor to `/de/` or `/ja/`, which on a
404 URL swallows the broken link and lands them on a homepage with
nothing to explain why.

## One AA green-text literal, two homes (#635)

The light-mode accent-as-text green is one decision. `theme.css`
declares it for the docs and `landing.css` for the landing, guide
and 404, because neither stylesheet imports the other — change
both together. They were independently derived and one notch apart
until #635. The `Check the AA green-text literal agrees` step in
`.github/workflows/site.yml` compares the two files' own values,
so a one-sided edit fails the gate.

What that step cannot see: the same value is shared with
kiwicanopy.com and KiwiCV, which is the point of pinning it —
re-deriving a private near-neighbour here splits the brand family
silently. Keeping *that* in step is a review obligation.

## Template comments ship to visitors (#557)

An `.astro` **template** comment written `<!-- ... -->` is emitted
verbatim into `dist/` and downloaded by everyone; only JSX-style
`{/* ... */}` is stripped at build.

The design rationale in `site/src/**` — the notes citing AGENTS.md
sections, issue numbers and `docs/` paths that explain a
non-obvious UX call, e.g. why there is deliberately no App Store
badge — is worth keeping in the source and must use `{/* */}`.
`Guide.astro` and `Landing.astro` published ~22 KB of it across
the locales before #557.

Two places are **not** template: frontmatter (between the `---`
fences) is already JS, so leave it alone; and inside
`<script is:inline>` / `<style>` Astro treats the body as raw
text, where a JSX comment renders literally — use `//` there.

A comment body containing `*/` self-terminates early, so check
before a bulk swap. Verify one by rebuilding the pre-change
baseline, regex-stripping `<!--.*?-->` from its output and diffing
against the new build: byte-identical across every page proves no
markup was swallowed by a mis-terminated delimiter, which counting
`<section` only weakly suggests.
