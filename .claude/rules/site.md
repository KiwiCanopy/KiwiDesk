---
paths:
  - "site/**"
  # The Node version would be restated here, not in site/.
  - ".github/workflows/site.yml"
  # The scripts this file constrains hardest — the published
  # body as an input contract, the appcast written from released
  # bytes, the release-time retirement of the docs markers. They
  # live in scripts/, so nothing under site/** loads for whoever
  # edits them.
  - "scripts/changelog-sync"
  - "scripts/appcast-sync"
  - "scripts/unreleased-strip"
  - "scripts/check-site-tokens.py"
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

## The docs plugin rides `markdown.processor` (#985)

`remark-docs-links.mjs` is what lets one `docs/` file read
correctly on both surfaces: it drops the `# H1` Starlight already
renders from frontmatter, and rewrites relative `.md` cross-links
into Starlight routes. **Hand it to `unified({ remarkPlugins:
[...] })` on `markdown.processor`, never to the deprecated
`markdown.remarkPlugins` array, and keep
`@astrojs/markdown-remark` declared in `site/package.json`.**

That array is a compat shim, and it is easy to read as more
broken than it is — the issue that filed this did. It *migrates*
the plugins onto a unified processor when **none** is configured,
which is why it worked here for as long as it did; it
`console.warn`s and DROPS them only once something configures a
processor that is not unified (both branches run directly against
the installed astro 7.2.6, 2026-08-27). Which is a plausible next
edit rather than a hypothetical: `astro-mermaid` already branches
on `markdown.processor?.name` and carries a `satteri()` arm, and
Sätteri is the schema default the moment nothing else claims the
slot. A dropped plugin leaves the build green and every docs page
shipping two `<h1>`s and prose cross-links the host has no route
for.

Declaring the package is the smaller half, and it stands on its
own ground: this config now `import`s `unified` from it directly.
It reaches the tree over `@astrojs/starlight → @astrojs/mdx →
@astrojs/markdown-remark`, a hard edge at an exact version but
two `^` ranges deep, and it is an *optional* peer of `astro` and
Starlight themselves (astro 7.2.6 / starlight 0.41.8,
2026-08-27), so nothing there is obliged to keep supplying it.
Neither half fails quietly — an absent package is an unresolvable
import, and the old shim threw with the install command in its
message — which is why this is worth doing early rather than
urgently.

**Guard the artifact, not the config**, for the reason the 404
check is: the config API is what keeps moving, and the next
upstream rearrangement takes this same shape whatever it renames.
`scripts/check-site-tokens.py` ▸ `check_markdown_pipeline` holds
every built page to exactly one `<h1>`, to no site-relative `.md`
href — an absolute one on another host is a link to the canonical
doc on GitHub and stays — and to every site-relative href
resolving against what the build actually emitted, which is what
catches the plugin rewriting links against the site root when its
slug derivation falls back to `""`. It also holds the docs corpus
to still carrying Starlight's heading anchors, because the
processor is ours to construct now and Starlight only `warn`s
when handed one it cannot drive. Reverting the config change
alone does not red it, by design: the invariant is what the
artifact says, not which API expresses it. On this gate for the
reason the feed check below is.

## Unreleased docs mark themselves (#1232)

Every push to the production branch auto-deploys, so a behavior
change merged to `main` is described on the published docs while
every installed copy is still the last release. The doc is not
wrong; it is *early*, with nothing on the page saying so.

**A block that describes unshipped behavior carries the marker in
the same change set that writes it:**

```md
:::unreleased
Each Desktop now owns its own Spaces…
:::
```

**Block level, never page frontmatter.** A page is almost never
wholly unreleased — the change that filed this moved three
paragraphs of `user-guide.md`, not the page — and an
all-or-nothing `since:` field gets used for neither.

**The marker names no version, and an attribute on it is a build
failure.** Under the owner's cut policy — everything fix-only
that has landed becomes the next patch — an author genuinely
cannot know which release their block will ship in, so a
hand-written version is wrong more often than right, and it is
wrong in the direction that keeps badging behavior that shipped
weeks ago. What retires a marker instead is
`scripts/unreleased-strip`, run by `changelog.yml` on `release:
published`. A marker still in the corpus means "not in a release"
**because** that ran at the last one.

That is a real dependency and it is the accepted trade, so state
it rather than discover it: if the strip is skipped or broken,
markers survive a release and the site badges shipped behavior
until the next one clears them. Two things bound it, and they
bound different halves.

**The strip runs on PUBLICATION only.** `changelog.yml`'s
`workflow_dispatch` is a rebuild — of a refused body, or of the
whole file — and nothing published at that moment, so the step is
gated on the release event. Unmarking early is the unsafe
direction (the page claims something ships that does not, with
nothing on it to hint otherwise), and this job arms its own
auto-merge, so an ungated sweep would land that unattended. A
dispatch therefore leaves the markers for one more release, which
is the bounded direction above.

**The strip verifies that its rewrite LANDED, and nothing
more.** It re-reads through the parser that did the rewrite, so a
marker that parser cannot see is invisible to its own
postcondition too — do not write that check up as covering "the
sweep matched nothing", which an earlier draft of this section
did. That half is caught one step later, by something that knows
the real grammar: `changelog.yml` builds the site AFTER the
sweep, and `check_unreleased_markers` reds when this parser's
count and the badges the pipeline actually rendered disagree.
**That ORDER is the coverage, so it is pinned** —
`UnreleasedStripWorkflowTests` ▸ `theBuildFollowsTheSweep`,
because moving the build above the sweep leaves every other
clause green and takes the only thing watching this with it.

**The corpus is validated at PR time**, by
`unreleased-strip --check` on the site gate, and that is what
lets the release-time sweep stay fail-fast. It sits in the
workflow carrying the appcast, so a malformed `:::` reaching
`main` would otherwise block the update feed on a docs typo.
`docs/**` is a path input of `site.yml` on both triggers, held by
`UnreleasedStripWorkflowTests` and `GuideRouteGateInputTests` —
that suite also holds `scripts/unreleased-strip` itself as an
input, since the gate runs it and `check-site-tokens.py` imports
it.

**Write the sweep's grammar against a measurement, and refuse
what it cannot place.** It rewrites published prose, so a parser
that merely looks right rewrites the wrong lines: the cases in
its own header — code-fence LENGTH, what one bare `:::` closes,
a marker in a blockquote or a list — were each run through the
installed remark before being written, and `UnreleasedStripTests`
carries them. Where remark and the sweep could disagree it
refuses rather than guesses. It also refuses an opener that is
neither the marker nor a Starlight aside, because an unhandled
container directive renders as a bare `<div>` with no trace of
itself — which makes that refusal, and not the Swift suite, what
catches a rename of the plugin's `DIRECTIVE` export. **A
container directive the corpus adopts joins the sweep's
`STARLIGHT_ASIDES` in the same change set**; nothing can derive
that set, and a stale entry blocks legitimate prose on the site
gate.

**The strip reports what it unmarked, into the sync PR's body.**
Unmarking a block is a claim too, and the one block this design
gets wrong is the one whose feature slipped OUT of the release it
was unmarked by. That listing is the only place it is visible, in
front of the person curating the release at the moment they know
what actually shipped — re-adding the marker is then one edit on
a PR they are already reading.

**One parser of the marker's grammar.** The corpus IS the state
here, so every reader of it — the sweep, the artifact check —
has to agree on the spelling, the fence rule and the nesting
rule. `scripts/unreleased-strip` owns all three and
`check-site-tokens.py` loads it rather than restating them; the
first draft spelled the fence rule twice with different coverage,
which would have redded the site build on a `~~~`-fenced EXAMPLE
with the diagnosis "the plugin stopped running".

**A plugin-only edit does not invalidate Astro's content
store**, so `npm run build` re-emits `dist/` from the previous
render and a local check reads stale output as confirmation
(measured 2026-09-07, `guard-prover`: a mutation that dropped the
badge's title came back green twice). `rm -rf dist` is not
enough — the cache is `node_modules/.astro/data-store.json`,
keyed on the source file's digest. Delete that too when
verifying a change to `remark-unreleased.mjs` or
`remark-docs-links.mjs` by rebuilding. CI never hits it, which is
exactly why it costs a local afternoon rather than a red build.

**Guard the plugin and the artifact separately, because neither
can hold the other's half.** `site/test-unreleased.mjs` drives
the plugin over fixtures on every site build: what it badges, the
three spellings it refuses, and that an unparsed marker ships as
visible prose rather than vanishing. It exists because the corpus
is EMPTY of markers most of the time, so
`check-site-tokens.py` ▸ `check_unreleased_markers` — which holds
the built pages against the corpus — is vacuous most of the time.
What that check holds and the fixture runner cannot is the REAL
pipeline: Starlight's processor, the docs symlink, `dist/`.

`remark-directive` reaches that pipeline through Starlight's own
asides rather than through anything we declare, which is why the
marker has two ways to die silently and both are watched: it
ships verbatim as prose if the directive stops being parsed, and
it renders as a bare `<div>` carrying its children — with no
trace of the marker — if our plugin stops running.

**The badge is English and carries no catalog key.** That is a
consequence of the docs corpus, not an oversight: it is served at
`/docs/*` in one locale, with no `/de/docs/` or `/ja/docs/`
route, so a key would have nothing to render it while the parity
rule below would still force an untranslatable copy into
`de.json` and `ja.json`. Add the key on the day the docs
themselves gain a second locale.

On GitHub, where the canonical `docs/` files are also read, the
marker lines render as literal text. A deliberate accept: crude,
but it still says *unreleased* to the contributor reading it
there, where an HTML comment would say nothing to anyone.

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

### Build watch paths are the one field the repo cannot hold

`wrangler.toml` has no key for **Build watch paths**, so that
single field is dashboard-held by necessity rather than by
preference (Workers & Pages ▸ `kiwidesk` ▸ Settings ▸ Build).
It includes `site/*` and nothing else, so a PR that touches no
site file starts no deploy — which is also what stops the Pages
bot commenting on every Swift-only PR, and with it the mail
GitHub sends the author about that comment.

Nothing in this repo can read that field, so the two obligations
below are the whole of its enforcement:

- **A change that gives the site build an input outside `site/`
  moves the watch path in the same change set.** The build is
  self-contained today: every import under `site/src` resolves
  within `site/`, there are no symlinks, and nothing reads
  repo-root `docs/`. The day something does, the include list is
  silently wrong and the symptom is a *stale production site* —
  no build runs, so no build can go red.
- **Write the include as `site/*`, never `site/**`.**
  Cloudflare's wildcard matches path separators, so `site/*`
  already covers `site/src/pages/index.astro` (their own example:
  `docs/*` matches `docs/guides/advanced/config.md`). `**` is
  undocumented there, and a pattern that matches nothing skips
  every build, production included.

Excludes are evaluated before includes, so an exclude added later
cannot be reasoned about from the include line alone.

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

**A promoted download link is read off the release's own asset
list, never composed from a version (#904).** `changelog-sync`
records a `download` field only where a published release
actually carries a notarized `.dmg`. The reason is not tidiness:
the site deploys independently of any tag, so a composed
`…/download/<tag>/KiwiDesk-<version>.dmg` is correct
only while the release workflow keeps passing `--dmg` — one edit
away from a first-class button that 404s, on a page nothing
re-publishes.

**Omit a download affordance rather than dimming one**, which is
where *grey, don't hide* stops: a dimmed button still makes a
download's promise, and the fallback is Homebrew alone — a
complete install path rather than a degraded one. That reaches
the PROSE too. A sentence naming a download the page does not
carry promises exactly what the button would, so copy pointing
at one is gated with it or written to stand without it.

Two guards, each holding its own half, because neither can hold
the other's. `ChangelogDownloadTests` holds what
`changelog-sync` writes — the URL is the asset's own, an
`-unnotarized.dmg` is refused rather than ranked, two candidate
images promote neither, and the field is absent rather than
empty. `scripts/check-site-tokens.py` ▸ `check_promoted_download`
holds what the BUILT pages then do with it, in both directions:
every landing AND guide page links the promoted download, and no
built page anywhere names a disk image the data does not record.
Those two are deliberately different tests — the changelog page
offers each release its OWN image, so the stray rule is
membership in what the data records and only the promoting pages
owe the newest one. It also picks the newest release by DATE
rather than by position, so it does not inherit the ordering
assumption the site's own selection makes; agreeing for the same
reason would make the agreement worthless. That one lives on the
site gate for the reason the feed check does — `site/**` is on
`.github/ci-ignore.txt`, so a Swift suite could not fire for the
edit it watches, and `CiPathFilterTests` refuses that placement.

The refusal's spelling is not this file's to state: the packager
decides which of the two names a finished image gets, and
`UnnotarizedSuffixParityTests` is the one authority holding every
reader to it.

**A path joins `sitemap.xml.ts`'s `paths` only once its `/de/` and
`/ja/` routes exist.** Every entry there is emitted for all three
locales with `hreflang` alternates, so a single-locale route
advertises two URLs that 404.

**The app links `/guide/`, so those routes are not the site's
alone to move (#1019).** `SupportLinks.guideRoutes` names the
locales KiwiDesk sends a reader to in their own language, and an
installed copy links whatever it was built with — so dropping or
renaming `/de/guide/` strands that link instead of breaking a
build. Narrow the Swift list in the same change set, never the
route alone. `scripts/check-site-tokens.py` ▸
`check_guide_routes` holds it against the BUILT pages, on this
gate for the reason the feed check below is, and reads that Swift
list rather than restating it; `site.yml` takes
`SupportLinks.swift` as a path input so the check fires when
either side moves. It holds the HOST beside the routes, against
the `site` value `astro.config.mjs` publishes — a domain change
moves every route at once, and it is the appcast's permanence
below reached through a different door. One-directional on purpose: a
locale the site GAINS does not red, the app keeping that reader
on a live English page until someone widens the list.

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
