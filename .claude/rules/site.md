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

**Never add a second Node pin file.** Cloudflare Pages resolved
`.node-version` ahead of `.nvmrc` as of 2026-07-30, so a duplicate
does not merely restate the number — it *wins* the deploy, while
every local and CI signal keeps reading `.nvmrc`. What is silent is
which pin wins; the outcome is a loud engine error, on the one
machine you are not watching. This repo carried a stale
`.node-version` below Astro's floor against a current `.nvmrc`
until #106. `package.json` → `engines` is not a safe alternative
either: Cloudflare's own docs listed it as unsupported by the
Pages v3 build image (2026-07-30).

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
`astro.config.mjs` move together, and **both** one-sided states
build green:

- **Page, no flag.** A user page already outranks Starlight's
  injected route, so the override works — while Astro logs a
  duplicate-route collision it says "will result in a hard error in
  following versions" (astro 7.1.1 / starlight 0.41.3, 2026-07-30).
  A log line fails no build, so the site ships until a bump.
- **Flag, no page.** Starlight injects its stock route only when
  the option is false, so withdrawing it with nothing in its place
  emits **no `404.html` at all** and the host serves its own
  generic one forever.

`scripts/check-site-tokens.py` therefore asserts on the *artifact*
— `dist/404.html` exists and carries a marker only the branded page
emits. That also covers a rename of the page and an upstream rename
of the option, neither of which a config-pair check would see.

Static hosting serves that one page for **every** unmatched path,
including `/de/*` and `/ja/*`, so it cannot pick a locale from the
URL: every locale renders on it together. Which is also why it must
not carry `Landing.astro`'s language-resolve script — that
redirects a stored-locale visitor to `/de/` or `/ja/`, which on a
404 URL swallows the broken link and lands them on a homepage with
nothing to explain why.

Consequence for **adding a locale**: `404.astro`'s `alts` array is
the site's only hand-enumerated locale list (every other route is
one file per locale), so a new locale must be added there or its
404 silently omits itself. `docs/translating.md`'s add-a-locale
checklist carries that step.

## The light-mode green is derived, not chosen (#635)

The accent-as-text green is the 50/50 midpoint of the brand fill
green and the forest ink — a rule, not a hex — and it is one
decision with two homes: `theme.css` for the Starlight docs and
`landing.css` for every non-Starlight surface (`grep -l landing.css
site/src` lists them). They were independently derived and one
notch apart until #635.

`scripts/check-site-tokens.py` recomputes the midpoint from the
tree and holds both files to it, plus AA as text on the light bg —
so it catches a **both**-sided drift, which comparing the two files
to each other would not, and which is exactly the cross-repo case:
the same value is shared with kiwicanopy.com and KiwiCV, where CI
here cannot reach. Pinning the derivation rather than the output is
what makes the rule portable to those repos.

Those two stylesheets are deliberately independent — neither
imports the other. If a future change unifies them behind a shared
token file, **delete that check in the same change set**: it
requires a literal hex in each light block and would otherwise fail
with a message that reads like a bug rather than like a fix.

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
