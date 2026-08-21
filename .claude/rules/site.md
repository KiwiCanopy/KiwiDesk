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

## One brand-color layer, imported by both stylesheets

`site/src/styles/brand-tokens.css` is the **only** place a brand
hex may be written. `theme.css` (the Starlight docs, wired through
`customCss` in `astro.config.mjs`) and `landing.css` (every
non-Starlight surface — landing, guide, legal) must both `@import`
it and map their own role names through `var()`.

Neither may re-state a brand hex. The two reach **disjoint page
sets**, so nothing renders both at once and nothing makes them
agree on its own: they had each declared the same nine hexes
independently, several under divergent names for one color
(`--kiwi-green` vs `--kiwi-flesh`) — the vocabulary split
[config-vocabulary.md](config-vocabulary.md) exists to prevent,
one layer below Swift. When two names compete for one color, keep
the one with live `var()` consumers.

**The light-mode text green is derived, not chosen.** Raw
`--kiwi-flesh` is ~2.3:1 on the light surfaces and fails AA, so
every light text/link/eyebrow role takes `--kiwi-flesh-text`, the
50/50 midpoint of `--kiwi-flesh` and `--kiwi-ink` shared with the
wider brand family (#635). Never put raw `--kiwi-flesh` on text.

An edit to `--kiwi-flesh` or `--kiwi-ink` must include a manual
cross-repo check against kiwicanopy.com and KiwiCV. The local guard
can enforce the relationship but cannot see those repositories.

`scripts/check-site-tokens.py` enforces all of the above: it
rejects a brand hex written anywhere else under `site/src`,
recomputes both the midpoint and the WCAG contrast from the tokens
rather than restating them, and fails if a stylesheet drops the
import. The site workflow runs it against the built artifact.

Two gaps it deliberately leaves:

- **Alpha variants.** `landing.css` still spells brand colors as
  decimal `rgba()` triples wherever it needs opacity —
  `rgba(141, 179, 84, 0.45)` is `--kiwi-flesh`. Folding those in
  wants relative-color syntax (`rgb(from var(--kiwi-flesh) r g b /
  0.45)`) and its own browser-support call; until then, don't add
  new ones by hand.
- **Values CSS cannot reach.** A `<meta name="theme-color">`
  attribute cannot read a custom property, so the shared
  `ThemeHead.astro` component owns that non-token browser-chrome
  color for every standalone page.

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
one of a dozen places in `site/src` that hand-enumerate the locale
set, so a new locale must be added there or its 404 omits itself.
`docs/translating.md`'s add-a-locale section owns the full list and
gives a grep for finding them rather than an enumeration to keep in
step.

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

## `src/data/` is generated; a translated catalog is not (#873, #869)

**`site/src/data/changelog.json` is written by
`scripts/changelog-sync`, never by hand.** It is rebuilt from the
published GitHub release bodies on every `release: published`, so
a hand edit survives exactly until the next release and then
disappears with no diff to explain it — the same trap the app
locale catalogs carry, one shelf over. Change what a release body
says, or change the generator; the file itself is output.

**The published body is an input contract, and the parser is what
holds it.** `scripts/changelog-sync --release <tag>` refuses a
body with no `## Highlights` block, no summary sentence, an empty
section or entry, a heading outside `##`/`###`, a nested list, a
code fence, a second `## Highlights`, or an issue number in ANY
authored slot — the entries, the summary and the section titles
alike — and names every problem at once rather than the first. A
template is a suggestion that drifts on the release someone is in
a hurry for; refusing is what keeps the shape identical across
releases, and it fails the workflow loudly instead of rendering a
half-page. Each of those refusals is pinned by
`ChangelogParserTests`, which also pins the bodies that must NOT
be refused — a guard that rejects legitimate input gets switched
off.

**Check a draft before publishing it**, with
`scripts/changelog-sync --body <file>`: a draft has no tag, so
`--release` cannot see one, and publishing is what puts the body
on the site. `scripts/release.sh` prints the skeleton after the
tag push, which is the one place every release passes through.

Section titles under `## Highlights` are the author's own, and
that is a ruling rather than a gap (owner, 2026-08-19): a fixed
New / Improved / Fixed triple splits one story across three
buckets, while a reader notices the story. The parser holds the
SHAPE and never a vocabulary. What the entries must SAY is
`docs/design-decisions.md` ▸ *Release notes are written for the
person installing*, which is a review-time rule by its own ruling
and has no guard.

**A path joins `sitemap.xml.ts`'s `paths` only once its `/de/` and
`/ja/` routes exist.** Every entry there is emitted for all three
locales with `hreflang` alternates, so a single-locale route
advertises two URLs that 404.

**Every site catalog carries every key `en.json` has**, enforced
by `scripts/extract-keys --site --check`, which `site.yml` runs on
any PR touching `site/**`, `docs/**` or `assets/**`. The app
corpus deliberately has no such rule: an `L(key, english)` call
site carries its English inline, so an app locale may lag and the
worksheet round exists for it to catch up. A site component reads
`t.<key>` and an absent key renders **nothing**, so the same
laxity is a blank on a published page in a language the reviewer
may not read. Clear a failure with `scripts/extract-keys --site
<locale>` and `scripts/merge-keys --site <locale>` — never by
deleting the English key.

## `public/appcast.xml` is generated, and its URL is permanent (#874)

**`site/public/appcast.xml` is written by
`scripts/appcast-sync`, never by hand**, for the reason
`changelog.json` is: a `release: published` rebuilds it, so an
edit made here survives until the next release and then vanishes
with no diff to explain it. The two are generated by one
workflow into one PR — `.github/workflows/changelog.yml` carries
why they must not be split.

**It is served at the site root because every KiwiDesk build ever
shipped says so.** `SUFeedURL` is baked into each bundle's
`Info.plist`, and an installed copy reads that URL and no other.
So this is not a page that can be moved, renamed or routed
through a redirect someone later prunes: moving it strands every
user who has not already updated, silently and permanently.
`.claude/rules/packaging-and-release.md` owns that permanence and
what an item must satisfy before it appears in the feed.

**The guard that the feed is actually served lives on THIS
gate, and it has to.** `site/**` is on `.github/ci-ignore.txt`,
so a change confined to the site skips the macOS jobs — which is
precisely the change that could delete the feed. A Swift suite
reading it would therefore be unable to fire for the edit it
watches, and `CiPathFilterTests` refuses that placement outright.
`scripts/check-site-tokens.py` checks it instead, against the
BUILT output, and `site.yml` runs on every `site/**` PR. Read
`scripts/build-app.sh` for the shipped URL rather than restating
it — a guard agreeing with its own literal is how the two would
drift apart while staying green.

**A path served to a program is not a page**, so the site's page
rules do not reach it. Give it no `/de/` or `/ja/` route, add it
to no sitemap, and localize no part of it: Sparkle asks for one
URL and negotiates nothing. (Written as an obligation because no
guard holds it — `check_sitemaps_disjoint` compares the two
sitemaps to each other, never to the feed.)

The entries inside it are the same English release notes the
changelog page renders in every locale, which
`site/src/components/Changelog.astro` argues for and now owns for
both surfaces.
