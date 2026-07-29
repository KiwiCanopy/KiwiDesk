#!/usr/bin/env python3
"""Guard the site's shared brand decisions (#635, #106).

Three checks, all of which DERIVE what they assert from the tree
rather than restating it here — a literal in this file would just
be one more copy to drift.

1. The light-mode accent-as-text green equals the 50/50 midpoint of
   the brand's fill green and the forest ink, in BOTH stylesheets.
   `theme.css` serves the Starlight docs and `landing.css` every
   other surface; neither imports the other, so the value has two
   homes. Comparing them to each other would miss a *both*-sided
   drift, which is exactly the cross-repo failure mode (the same
   value is shared with kiwicanopy.com and KiwiCV) — so the
   midpoint is computed and both sides are checked against it.
2. That green clears WCAG AA (4.5:1) as text on the light page
   background, also read out of the stylesheet. Agreement alone
   would happily pass two files that both name the raw fill green,
   which is ~2.3:1.
3. The built 404 is the branded page. `src/pages/404.astro` and
   `disable404Route: true` in astro.config.mjs must move together,
   and BOTH one-sided failures are silent: without the flag Astro
   only *logs* a duplicate-route collision (a log line fails no
   build), and with the flag but no user page Starlight's stock
   route is withdrawn and NOTHING is emitted — Cloudflare then
   serves its own generic 404 forever. Asserting on the artifact
   catches both, plus a rename of the page and an upstream rename
   of the option, which a config-pair check cannot.

Usage: scripts/check-site-tokens.py [--dist site/dist]

Paths are resolved against the repo root, so it runs from
anywhere. --dist is required for check 3 and takes a path rather
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

# The light-theme token block selector shared by both stylesheets.
LIGHT = ':root[data-theme="light"]'


def fail(msg: str) -> None:
    sys.exit(f"check-site-tokens: {msg}")


def hex_of(text: str, prop: str) -> str | None:
    """First `prop: #rrggbb` in `text`, lower-cased."""
    m = re.search(re.escape(prop) + r":\s*(#[0-9a-fA-F]{6})", text)
    return m.group(1).lower() if m else None


def light_blocks(path: pathlib.Path) -> list[str]:
    """Every light-theme token block in `path`, in source order."""
    parts = re.split(re.escape(LIGHT), path.read_text())
    if len(parts) < 2:
        fail(f"{path.name}: no {LIGHT} block")
    return [p.split("}", 1)[0] for p in parts[1:]]


def root_hex(path: pathlib.Path, prop: str) -> str:
    value = hex_of(path.read_text(), prop)
    if value is None:
        fail(f"{path.name}: no `{prop}` hex")
    return value


def light_hex(path: pathlib.Path, prop: str) -> str:
    """`prop`'s cascade-winning light value: the LAST block declaring it.

    Resolved per property, not per block. A stylesheet may carry
    more than one light block, and reading only the first would let
    an appended override ship while this check kept reading the
    original — a vacuous pass. Reading only the *last* block is
    equally wrong the other way: a small appended override declaring
    one token would hide every other token's real value.
    """
    found = [
        value
        for block in light_blocks(path)
        if (value := hex_of(block, prop)) is not None
    ]
    if not found:
        fail(f"{path.name}: no `{prop}` hex in any light block")
    return found[-1]


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


def check_accent() -> None:
    theme, landing = STYLES / "theme.css", STYLES / "landing.css"

    # theme.css is the authority for the two endpoints: the raw
    # brand fill green on bare :root, and the forest ink that its
    # light block uses as strong text.
    fill = root_hex(theme, "--kiwi-green")
    ink = light_hex(theme, "--sl-color-white")
    expected = midpoint(fill, ink)

    docs = light_hex(theme, "--sl-color-accent")
    rest = light_hex(landing, "--accent")
    print(
        f"fill {fill} + ink {ink} -> midpoint {expected}; "
        f"theme.css {docs}, landing.css {rest}"
    )

    for name, found in (("theme.css", docs), ("landing.css", rest)):
        if found != expected:
            fail(
                f"{name}'s light-mode accent is {found}, not the "
                f"{expected} midpoint of {fill} and {ink}. This green "
                "is one decision shared with kiwicanopy.com and "
                "KiwiCV — re-derive it and the brand family splits "
                "silently (#635)."
            )

    bg = light_hex(theme, "--sl-color-black")
    ratio = contrast(expected, bg)
    print(f"contrast {ratio:.2f}:1 on the light bg {bg}")
    if ratio < 4.5:
        fail(
            f"{expected} is {ratio:.2f}:1 on {bg}, below WCAG AA "
            "(4.5:1) for body text. The raw fill green fails this, "
            "which is why the midpoint exists."
        )


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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dist",
        help="path to the built site (enables the 404 artifact check)",
    )
    args = parser.parse_args()

    check_accent()
    if args.dist:
        check_branded_404(pathlib.Path(args.dist).resolve())
    else:
        print("no --dist given: skipped the built-404 check")


if __name__ == "__main__":
    main()
