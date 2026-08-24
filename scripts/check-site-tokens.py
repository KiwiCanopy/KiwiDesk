#!/usr/bin/env python3
"""Guard the site's shared brand decisions (#635, #106).

The checks below all DERIVE what they assert from the tree rather
than restating it here — a literal in this file would just be one
more copy to drift. They are numbered as a reader's map, not as a
register: add one and give it a number, rather than keeping a
count in this sentence for the next author to falsify.

1. `brand-tokens.css` is the one raw brand-color layer. Its hexes
   appear nowhere else under `site/src`, and both role-mapping
   stylesheets import it.

2. The light-mode accent-as-text green equals the 50/50 midpoint of
   the brand's fill green and forest ink in that token layer.

   What this does NOT cover: it pins the *relationship*, and both
   endpoints are in-tree and mutable. Retune the fill green, then
   dutifully re-derive everything downstream here but not in
   kiwicanopy.com / KiwiCV, and this passes while the brand family
   splits — which is the most likely way it actually happens. So
   **any edit to the fill green or the forest ink still needs the
   cross-repo check by hand.**
3. That green clears WCAG AA (4.5:1) as text on both tokenized light
   backgrounds. Agreement alone would happily pass the raw fill
   green, which is ~2.3:1.
4. The built 404 is the branded page. `src/pages/404.astro` and
   `disable404Route: true` in astro.config.mjs must move together,
   and BOTH one-sided failures are silent: without the flag Astro
   only *logs* a duplicate-route collision (a log line fails no
   build), and with the flag but no user page Starlight's stock
   route is withdrawn and NOTHING is emitted — Cloudflare then
   serves its own generic 404 forever. Asserting on the artifact
   catches both, plus a rename of the page and an upstream rename
   of the option, which a config-pair check cannot.
5. The two sitemaps submit disjoint URL sets, and neither carries
   a noindex legal page. Also artifact-read: that contract lives
   between a `filter` callback in astro.config.mjs and a
   hand-maintained `paths` array, and nothing else can see the two
   disagree.

KNOWN LIMIT. This reads CSS with regexes, not a parser, so treat it
as a net for ordinary edits rather than proof. `CONSUMERS` names the
two role-mapping stylesheets by hand; add any future consumer there.

Usage: scripts/check-site-tokens.py --dist site/dist

Paths are resolved against the repo root, so it runs from
anywhere. --dist is required by the artifact checks and takes a path rather
than defaulting, so a missing build directory is an error instead
of a silently skipped assertion.
"""

# macOS still ships Python 3.9 as `python3`, which evaluates
# annotations eagerly and chokes on `str | None`. CI runs newer, so
# without this the script would pass there and fail on the machine
# a developer actually runs it from.
from __future__ import annotations

import argparse
import io
import json
import pathlib
import re
import sys
import urllib.parse
import xml.etree.ElementTree as ET

REPO = pathlib.Path(__file__).resolve().parent.parent

# The exact namespace Sparkle binds its elements to.
SPARKLE_NS = (
    "http://www.andymatuschak.org/xml-namespaces/sparkle"
)
STYLES = REPO / "site" / "src" / "styles"
SRC = REPO / "site" / "src"
TOKENS = STYLES / "brand-tokens.css"
CONSUMERS = (STYLES / "theme.css", STYLES / "landing.css")
HEX = re.compile(r"#[0-9a-fA-F]{6}\b")
TOKEN_DECL = re.compile(r"(--kiwi-[a-z0-9-]+)\s*:\s*([^;}]+)")
SCAN_SUFFIXES = {".css", ".astro", ".ts", ".js", ".mjs"}
LIGHT = (
    r"[^{}]*\[\s*data-theme\s*[|~^$*]?=\s*['\"]?light['\"]?"
    r"\s*[isIS]?\s*\][^{}]*\{"
)

def fail(msg: str) -> None:
    sys.exit(f"check-site-tokens: {msg}")


def source(path: pathlib.Path) -> str:
    """`path` with block and JSX comments stripped."""
    return re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.S)


def source_without_comments(path: pathlib.Path) -> str:
    """Source with block, JSX, and ordinary line comments removed."""
    text = source(path)
    return re.sub(r"(?<!:)//[^\n]*", "", text)


def token_map() -> dict[str, str]:
    if not TOKENS.is_file():
        fail(f"missing {TOKENS.relative_to(REPO)}")
    found = TOKEN_DECL.findall(source_without_comments(TOKENS))
    if not found:
        fail(f"{TOKENS.relative_to(REPO)} declares no brand tokens")
    tokens = {}
    for name, raw in found:
        value = raw.strip()
        if name in tokens:
            fail(f"{TOKENS.relative_to(REPO)} repeats {name}")
        if not HEX.fullmatch(value):
            fail(f"{TOKENS.relative_to(REPO)} declares {name} as "
                 f"`{value}`, not a six-digit hex")
        tokens[name] = value.lower()
    if len(tokens) != len(found):
        fail(f"{TOKENS.relative_to(REPO)} repeats a token name")
    return tokens


def check_token_layer(tokens: dict[str, str]) -> None:
    owners = {value: name for name, value in tokens.items()}
    for path in sorted(SRC.rglob("*")):
        if path == TOKENS or path.suffix not in SCAN_SUFFIXES:
            continue
        body = source_without_comments(path)
        declared = TOKEN_DECL.search(body)
        if declared:
            fail(f"{path.relative_to(REPO)} declares {declared.group(1)}; "
                 f"brand tokens belong in {TOKENS.relative_to(REPO)}")
        for hit in HEX.findall(body):
            if hit.lower() in owners:
                fail(
                    f"{path.relative_to(REPO)} repeats {owners[hit.lower()]} "
                    f"as {hit}; use var({owners[hit.lower()]})"
                )
    needle = f'@import "./{TOKENS.name}";'
    for path in CONSUMERS:
        body = source_without_comments(path).lstrip()
        if not body.startswith(needle):
            fail(f"{path.name}: `{needle}` must be its first rule")


def light_role(path: pathlib.Path, prop: str) -> str:
    """Return the cascade-winning light-theme value for `prop`."""
    values = []
    body = source(path)
    for match in re.finditer(LIGHT, body):
        block = body[match.end() :].split("}", 1)[0]
        found = re.findall(re.escape(prop) + r"\s*:\s*([^;}]+)", block)
        if found:
            values.append(found[-1].strip())
    if not values:
        fail(f"{path.name}: no light-theme {prop} declaration")
    if any("!important" in value for value in values):
        fail(f"{path.name}: {prop} must not use !important")
    return values[-1]


def midpoint(a: str, b: str) -> str:
    """Per-channel 50/50 blend, rounding half up (as #506c37 does)."""
    ca = [int(a[i : i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{(x + y + 1) // 2:02x}" for x, y in zip(ca, cb))


def relative_luminance(color: str) -> float:
    def channel(value: int) -> float:
        c = value / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(int(color[i : i + 2], 16)) for i in (1, 3, 5))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg: str, bg: str) -> float:
    a, b = relative_luminance(fg), relative_luminance(bg)
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def check_accent(tokens: dict[str, str]) -> None:
    fill = tokens.get("--kiwi-flesh")
    ink = tokens.get("--kiwi-ink")
    text = tokens.get("--kiwi-flesh-text")
    if not fill or not ink or not text:
        fail("token layer needs --kiwi-flesh, --kiwi-ink, and "
             "--kiwi-flesh-text")
    expected = midpoint(fill, ink)
    if text != expected:
        fail(f"--kiwi-flesh-text is {text}, not the {expected} midpoint "
             f"of {fill} and {ink} (#635)")
    expected_role = "var(--kiwi-flesh-text)"
    roles = (
        (STYLES / "theme.css", "--sl-color-accent"),
        (STYLES / "landing.css", "--accent"),
    )
    for path, prop in roles:
        value = light_role(path, prop)
        if value != expected_role:
            fail(f"{path.name}: light {prop} is `{value}`, not "
                 f"`{expected_role}`")
    for surface in ("--kiwi-cream", "--kiwi-snow"):
        bg = tokens.get(surface)
        if not bg:
            fail(f"token layer needs {surface} for the contrast check")
        ratio = contrast(text, bg)
        print(f"contrast {ratio:.2f}:1 on {surface} {bg}")
        if ratio < 4.5:
            fail(f"{text} is {ratio:.2f}:1 on {bg}, below WCAG AA")


def check_branded_404(dist: pathlib.Path) -> None:
    page = dist / "404.html"
    if not page.is_file():
        fail(
            f"{page} is missing. Static hosting serves it for every "
            "unmatched path, so with no artifact Cloudflare falls "
            "back to its own generic 404. Either src/pages/404.astro "
            "was removed or renamed while astro.config.mjs still "
            "sets disable404Route (which withdraws Starlight's stock "
            "route), or the build did not run (#635)."
        )
    # A class only the branded page emits. Starlight's stock 404 and
    # Cloudflare's fallback carry no such marker, so this separates
    # "a 404 exists" from "OUR 404 shipped".
    if "nf__code" not in page.read_text():
        fail(
            f"{page} exists but is not the branded page — no "
            "`nf__code` marker. Starlight's stock 404 outranking "
            "ours, or disable404Route lost to an upstream rename "
            "(#635)."
        )
    print(f"{page.relative_to(REPO)} is the branded 4-kiwi-4 page")


def check_appcast(dist: pathlib.Path) -> None:
    """Sparkle's feed must be served, at the URL every build bakes in.

    This lives on the SITE gate rather than in the Swift suite, and
    that placement is the whole point. `site/**` is on
    `.github/ci-ignore.txt`, so a change confined to the site skips
    the macOS jobs — which is exactly the change that could delete
    this file. A guard in a suite that does not run for the edit it
    is watching guards nothing; `site.yml` runs on every `site/**`
    PR, so it is the gate that can actually catch it
    (`CiPathFilterTests` is what refused the other placement), and
    `changelog.yml` runs it again on the sync PR, which fires no
    workflows of its own.

    Read from the BUILT output, not from `public/`: what matters is
    the file Cloudflare serves, and `public/` reaching `dist/` is an
    Astro behaviour rather than a promise this repo controls.

    Losing this is unrecoverable in the strict sense — an installed
    copy reads one URL forever, so a 404 here is an error dialog on
    the screen of every user who ever installed KiwiDesk, with no
    way to reach them (docs/design-decisions.md, "No distribution
    channel without an update path").

    **What it does NOT check: that the feed offers anything.** An
    itemless channel is well-formed and passes here, deliberately —
    it is the correct state before the first signed release. The
    guard that a PUBLISHED release actually reaches the feed is
    `appcast-sync --release`, run by `changelog.yml`; this one
    answers "is it served, and is it a feed".
    """
    # `.read_text()`, never `source()`. That helper strips JSX
    # block comments, and a shell script opens one every time it
    # globs — `for locale_file in "$LOCALES"/*.json` begins a
    # span that swallows the plist and everything else up to the
    # next `*/`. Read through it, this reported "no SUFeedURL
    # declared" for a plist that was plainly there.
    build = (REPO / "scripts" / "build-app.sh").read_text(
        encoding="utf-8"
    )
    match = re.search(
        r"<key>SUFeedURL</key>\s*<string>(?P<url>[^<]+)</string>",
        build,
    )
    if not match:
        fail(
            "scripts/build-app.sh declares no SUFeedURL, so the "
            "feed this checks for has no shipped URL to answer."
        )
    url = match.group("url")
    parts = urllib.parse.urlsplit(url)

    # The WHOLE path, not the basename. Checking only the last
    # component means a feed URL that ever gains a directory
    # segment is looked for at the wrong place, found, and passes
    # green while the shipped URL 404s — the exact false green
    # this check exists to make impossible.
    relative = parts.path.strip("/")
    if not relative:
        fail(f"SUFeedURL names no path to serve: {url}")
    served = dist.joinpath(*relative.split("/"))

    # The host, too. Nothing else covers it: `build-app.sh` is
    # outside site.yml's path filter, so a host typo would ship
    # with no gate having read it.
    canonical = re.search(
        r'SITE_URL\s*\?\?\s*"(?P<site>[^"]+)"',
        source_without_comments(REPO / "site" / "astro.config.mjs"),
    )
    # A miss FAILS rather than skipping. Hanging the host check
    # on `if canonical:` meant that the day astro.config.mjs
    # stopped matching, half this function would switch itself
    # off while the other half still printed its success line —
    # a guard that stops guarding with no signal. The site cannot
    # build without a canonical URL, so not finding one is a
    # defect, not an absence.
    if not canonical:
        fail(
            "site/astro.config.mjs declares no `SITE_URL ?? \"…\"`, "
            "so the host every build bakes into SUFeedURL cannot "
            "be checked against the host the site publishes at."
        )
    expected_host = urllib.parse.urlsplit(
        canonical.group("site")
    ).netloc
    if not expected_host:
        fail(
            f"site/astro.config.mjs's SITE_URL "
            f"({canonical.group('site')}) has no host."
        )
    if parts.netloc != expected_host:
        fail(
            f"SUFeedURL points at {parts.netloc} but the site "
            f"is published at {expected_host}. Every build ever "
            "shipped reads that host and no other."
        )

    if not served.is_file():
        fail(
            f"{served} is missing, but every KiwiDesk build ships "
            f"SUFeedURL={url}. An installed copy reads that URL and "
            "no other, so this file 404ing is a permanent update "
            "error for everyone who already installed. It is "
            "generated by scripts/appcast-sync — rebuild it rather "
            "than writing one by hand."
        )

    # PARSED, not grepped. Substring checks for `<rss` and the
    # namespace are satisfied by a truncated file — a half-written
    # feed keeps both and still fails in Sparkle, which parses it
    # with NSXMLDocument and then runs XPath /rss/channel/item.
    text = served.read_text(encoding="utf-8")
    try:
        root = ET.fromstring(text)
    except ET.ParseError as error:
        fail(
            f"{served} is not well-formed XML ({error}). Sparkle "
            "reports a malformed feed as an update error, which "
            "is the same failure as a 404 with a more confusing "
            "message."
        )
    if root.tag != "rss" or root.find("channel") is None:
        fail(
            f"{served} parses but is not an appcast — Sparkle "
            "looks for /rss/channel/item and would find nothing."
        )
    # The DECLARED namespaces, collected from the parse rather
    # than matched as a substring. `SPARKLE_NS in text` looked
    # equivalent and is not: a feed declaring
    # `…/xml-namespaces/sparkle-v2` contains the correct URI as a
    # prefix of a wrong one and passed, while Sparkle would bind
    # nothing and silently ignore every `sparkle:` element in the
    # file — the signatures among them.
    declared = {
        uri
        for _, (_, uri) in ET.iterparse(
            io.StringIO(text), events=("start-ns",)
        )
    }
    if SPARKLE_NS not in declared:
        fail(
            f"{served} declares {sorted(declared) or 'no'} "
            f"namespace(s), not {SPARKLE_NS}. Without the exact "
            "URI Sparkle binds no sparkle: element, signatures "
            "included."
        )
    items = root.findall("./channel/item")
    print(
        f"{served.relative_to(REPO)} answers the shipped "
        f"SUFeedURL ({url}), {len(items)} item(s)"
    )


def check_promoted_download(dist: pathlib.Path) -> None:
    """The download the site promotes is the one the data names,
    and nothing offers a download the data does not carry (#904).

    This lives on the SITE gate rather than in a Swift suite for
    the reason `check_appcast` does: `site/**` is on
    `.github/ci-ignore.txt`, so a change confined to the site
    skips the macOS jobs — and a change confined to the site is
    exactly the one that could drop the button or point it
    somewhere else. `CiPathFilterTests` refuses the other
    placement outright.

    It reads the BUILT pages, not the components: a guard over
    rendered output that greps the source proves the source says
    something, never that a visitor receives it.

    Two directions, asserted over different things on purpose:

    - **Offered.** Every landing and guide page must carry the
      promoted URL as an anchor `href`. Asserting it merely
      APPEARS on the page is vacuous — the JSON-LD graph embeds
      the same URL as metadata, so a page that had lost every
      button would still contain the string and pass. The first
      draft of this check did exactly that.
    - **No strays.** Every `.dmg` URL anywhere in any built page
      — anchors, JSON-LD, inline scripts, data attributes — must
      be one the data RECORDS. Not the promoted one: the
      changelog page offers each release its own image, so the
      second release to ship one would otherwise fail this check
      inside `changelog.yml`'s own build step and strand the
      notes and the appcast on the release that just published.
      Membership is the rule; equality belongs only to the pages
      that promote.

    **The promoted release is chosen by DATE here, deliberately
    not by position.** `download.ts` takes the first entry with a
    download because `changelog-sync` emits newest-first; if this
    guard re-derived it the same way, both would pick the same
    wrong release the day that ordering changed and stay green.
    Picking independently is what makes the agreement evidence.

    What it does not see, stated rather than implied: presence is
    per PAGE, not per affordance. A page carrying three download
    buttons still passes with two removed. The page-level
    question — did this locale stop offering the download at all
    — is the one whose failure is silent and total; a single
    button lost among several is a visible layout change that
    review catches. A per-site count would pin a number that
    legitimately moves.
    """
    data = REPO / "site" / "src" / "data" / "changelog.json"
    try:
        releases = json.loads(
            data.read_text(encoding="utf-8")
        )["releases"]
    except (OSError, KeyError, json.JSONDecodeError) as error:
        fail(f"cannot read {data} ({error})")
        return

    carriers = [
        r
        for r in releases
        if isinstance(r.get("download"), str) and r["download"]
    ]
    recorded = {r["download"] for r in carriers}

    def newest(entry: dict) -> tuple:
        """Sort key: date, then version numerically.

        The version tiebreak is not decoration. `max` returns the
        FIRST maximal element, so keying on date alone would fall
        back to the file's own order the moment two releases
        shared a date — which is the newest-first assumption this
        derivation exists to avoid, coming back through a side
        door. A same-day patch release is the ordinary case that
        would trigger it.
        """
        parts = str(entry.get("version", "")).split(".")
        number = tuple(
            int(part) if part.isdigit() else 0 for part in parts
        )
        return (str(entry.get("date", "")), number)

    promoted = (
        max(carriers, key=newest)["download"] if carriers else None
    )

    # Landing and guide pages are found by markers only their own
    # components emit, never by enumerating locales: `site/**`
    # already hand-lists the locale set in about a dozen places
    # (`docs/translating.md` owns that grep), and a thirteenth
    # would let a new locale ship an unchecked page silently.
    every = sorted(dist.rglob("*.html"))
    html = {p: p.read_text(encoding="utf-8") for p in every}
    landing = [p for p in every if 'id="modeToggle"' in html[p]]
    guides = [p for p in every if "learn-install" in html[p]]
    for label, pages in (("landing", landing), ("guide", guides)):
        if not pages:
            fail(
                f"no built {label} pages found — the marker this "
                "check finds them by has moved"
            )
            return

    anchor = re.compile(r'href="([^"]*\.dmg)"')
    anywhere = re.compile(r'https?://[^\s"\'<>\\]+\.dmg')

    for page in every:
        strays = {
            url
            for url in anywhere.findall(html[page])
            if url not in recorded
        }
        if strays:
            fail(
                f"{page.relative_to(dist)} names a disk image the "
                f"data does not record: {sorted(strays)}"
            )

    if promoted is None:
        print("no promoted download recorded; no page offers one")
        return

    missing = [
        str(p.relative_to(dist))
        for p in landing + guides
        if promoted not in set(anchor.findall(html[p]))
    ]
    if missing:
        fail(
            "these pages do not link the promoted download: "
            f"{missing}"
        )
    print(
        f"promoted download {promoted} linked from "
        f"{len(landing)} landing and {len(guides)} guide page(s); "
        f"{len(recorded)} recorded image(s) allowed elsewhere"
    )


def check_sitemaps_disjoint(dist: pathlib.Path) -> None:
    """The site ships two sitemaps, and they must not overlap.

    `src/pages/sitemap.xml.ts` hand-rolls the locale marketing
    URLs *with* hreflang alternates; `@astrojs/sitemap` covers
    `/docs/**`, filtered to that in `astro.config.mjs`. Submitting
    one URL from both — annotated in one file and bare in the
    other — is not redundancy a crawler resolves in our favour,
    and it is what shipped between #656 and #660.

    Read off the artifact rather than the config, because the
    contract is between a `filter` callback and a hand-maintained
    `paths` array and nothing else can see them disagree.
    """
    locs = {}
    for name in ("sitemap.xml", "sitemap-0.xml"):
        page = dist / name
        if not page.is_file():
            fail(
                f"{page} is missing. Both sitemaps are declared in "
                "robots.txt, so a missing one is a 404 handed to "
                "every crawler that follows it."
            )
        locs[name] = set(
            re.findall(r"<loc>(.*?)</loc>", page.read_text())
        )

    overlap = locs["sitemap.xml"] & locs["sitemap-0.xml"]
    if overlap:
        fail(
            "the two sitemaps both submit "
            f"{len(overlap)} URL(s): {sorted(overlap)[:4]}. Either "
            "the @astrojs/sitemap `filter` in astro.config.mjs "
            "widened, or a route was added to the hand-rolled "
            "sitemap that the filter does not exclude."
        )

    legal = {u for u in locs["sitemap.xml"] | locs["sitemap-0.xml"]
             if "/imprint/" in u or "/privacy/" in u}
    if legal:
        fail(
            f"noindex legal pages are in a sitemap: {sorted(legal)}."
        )

    print(
        f"sitemaps disjoint: {len(locs['sitemap.xml'])} marketing + "
        f"{len(locs['sitemap-0.xml'])} docs URLs, no overlap"
    )


# Starlight's own custom-property layer. Exempt by NAMESPACE
# rather than by file, because the point is whose layer it is: we
# do not author these, we cannot fix a dangling one, and Starlight
# ships several (`--sl-text-h6`, `--sl-icon-size`) that its own
# bundle references without declaring. Ours are the ones this
# guard is for, and none of ours may hide behind this prefix.
THIRD_PARTY_PREFIX = "--sl-"


def check_var_references(dist: pathlib.Path) -> None:
    """Every `var(--x)` in the built CSS resolves to a `--x:`
    declaration in the same artifact.

    An undeclared custom property is the quietest failure this
    tree has: the build stays green, the page still renders, and
    every rule using it silently drops. A colour falls back to
    the inherited one, so a muted tier collapses into the body
    text; worse, `border: 1px solid var(--nope)` is invalid at
    computed-value time, so the whole shorthand unsets and
    `border-style` becomes `none` — the rule simply is not there.

    That is not hypothetical. The release-notes page (#873)
    shipped its first draft against `--fg-1`, `--fg-2` and
    `--line`, none of which exists here (`--text`, `--text-dim`,
    `--border` do). Its section eyebrows, dates and back link all
    rendered at full body strength, its separators and its BETA
    pill had no border at all, and the only link out to the
    GitHub release was the same colour as the paragraph above it
    with no underline — a WCAG 1.4.1 failure that no build, test
    or lint noticed.

    Reads the ARTIFACT rather than `site/src`, so it also covers
    an Astro component's scoped `<style>` block and anything a
    dependency emits."""
    declared: set[str] = set()
    used: dict[str, str] = {}
    sheets = sorted(dist.rglob("*.css"))
    inline = sorted(dist.rglob("*.html"))
    if not sheets:
        fail(
            f"no CSS found under {dist} — this check would pass "
            "for having looked at nothing."
        )
    blocks: list[tuple[str, str]] = [
        (str(path.relative_to(dist)), path.read_text(encoding="utf-8"))
        for path in sheets
    ]
    for path in inline:
        text = path.read_text(encoding="utf-8")
        where = str(path.relative_to(dist))
        for match in re.finditer(
            r"<style[^>]*>(.*?)</style>", text, re.DOTALL
        ):
            blocks.append((where, match.group(1)))
        # An inline `style="--depth: 0"` IS a declaration, and it
        # is how a component hands a per-element value to CSS —
        # Starlight's sidebar nesting does exactly this. Scanning
        # only stylesheets would report those as dangling.
        for match in re.finditer(r'style="([^"]*)"', text):
            blocks.append((where, match.group(1)))
    for where, text in blocks:
        declared.update(re.findall(r"(--[\w-]+)\s*:", text))
        # Only the NO-FALLBACK form. `var(--x, 1em)` survives an
        # undeclared `--x` by design — that is what the fallback
        # is — so flagging it would be flagging correct CSS, and
        # Starlight's own layer uses that form throughout.
        for name in re.findall(
            r"var\(\s*(--[\w-]+)\s*\)", text
        ):
            used.setdefault(name, where)
    if not used:
        fail(
            "no `var(--x)` references found in the built CSS — "
            "this check would pass for having looked at nothing."
        )
    missing = sorted(
        name
        for name in set(used) - declared
        if not name.startswith(THIRD_PARTY_PREFIX)
    )
    if missing:
        listed = "\n".join(
            f"    - {name}  (first seen in {used[name]})"
            for name in missing
        )
        fail(
            "CSS custom propert(ies) used but never declared. "
            "Every rule referencing one is silently dropped:\n"
            f"{listed}\n"
            "  Declared names live in site/src/styles/*.css — "
            "text is --text / --text-dim / --text-faint, borders "
            "are --border / --border-strong."
        )
    print(
        f"var(--x) references resolve: {len(used)} name(s) across "
        f"{len(blocks)} stylesheet(s)/block(s)"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dist",
        required=True,
        help="path to the built site (for the artifact checks)",
    )
    args = parser.parse_args()

    tokens = token_map()
    check_token_layer(tokens)
    check_accent(tokens)
    dist = pathlib.Path(args.dist).resolve()
    check_branded_404(dist)
    check_appcast(dist)
    check_promoted_download(dist)
    check_sitemaps_disjoint(dist)
    check_var_references(dist)


if __name__ == "__main__":
    main()
