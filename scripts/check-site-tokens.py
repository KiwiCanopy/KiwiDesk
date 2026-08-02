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
import pathlib
import re
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
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
    check_sitemaps_disjoint(dist)


if __name__ == "__main__":
    main()
