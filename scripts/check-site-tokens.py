#!/usr/bin/env python3
"""Guard the site's shared brand decisions (#635, #106).

Three checks, all of which DERIVE what they assert from the tree
rather than restating it here — a literal in this file would just
be one more copy to drift.

1. The light-mode accent-as-text green equals the 50/50 midpoint of
   the brand's fill green and the forest ink, in BOTH stylesheets.
   `theme.css` serves the Starlight docs and `landing.css` every
   other surface; neither imports the other, so the value has two
   homes. Comparing them only to each other would miss a drift
   applied to both at once, so the midpoint is computed and both
   sides are checked against it.

   What this does NOT cover: it pins the *relationship*, and both
   endpoints are in-tree and mutable. Retune the fill green, then
   dutifully re-derive everything downstream here but not in
   kiwicanopy.com / KiwiCV, and this passes while the brand family
   splits — which is the most likely way it actually happens. So
   **any edit to the fill green or the forest ink still needs the
   cross-repo check by hand.**
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

KNOWN LIMITS. This reads CSS with regexes, not a parser, so treat it
as a net for ordinary edits rather than proof. Three adversarial
attribute-selector spellings are known to slip past and would ship:
`[data-theme|="light"]`, `[data-theme~="light"]` and
`[data-theme*="light"]` in a block that also re-declares the token.
Nothing writes those by accident, which is why they are documented
rather than handled — but do not read a green run as "no override
exists anywhere". `STYLES` also names two stylesheets by hand; a
third that declared a light token (e.g. `learn.css`) would be
invisible.

Usage: scripts/check-site-tokens.py --dist site/dist

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

# Any selector that targets the light theme, in any spelling that
# ships: double or single quotes, an unquoted attribute value, a
# tag/pseudo prefix, or CSS nesting (`:root { &[data-theme="light"]
# { … } }`). Matching one literal spelling is a vacuous pass waiting
# to happen — every variant here is valid CSS that lightningcss
# emits happily, and no stylelint config normalizes them.
LIGHT = (
    r"[^{}]*\[\s*data-theme\s*[|~^$*]?=\s*['\"]?light['\"]?"
    r"\s*[isIS]?\s*\][^{}]*\{"
)

# A bare `:root { … }` block — the un-themed token layer. Excludes
# `:root[…]` so the light/dark blocks are not mistaken for it.
BARE_ROOT = r":root\s*\{"


def fail(msg: str) -> None:
    sys.exit(f"check-site-tokens: {msg}")


def declared(block: str, prop: str) -> str | None:
    """`prop`'s winning value in `block`, or None if not declared.

    The LAST declaration, because that is the one CSS takes — and
    re-declaring a token below the old line is the most ordinary way
    to change one, so reading the first would be a vacuous pass on
    the commonest edit there is.

    Returns the raw value text, hex or not. Telling "not declared"
    apart from "declared as something other than a hex" is what
    keeps a `var()` or 3-digit override loud instead of invisible.
    """
    found = re.findall(re.escape(prop) + r"\s*:\s*([^;}]+)", block)
    return found[-1].strip() if found else None


def as_hex(value: str) -> str | None:
    m = re.fullmatch(r"(#[0-9a-fA-F]{6})", value.split()[0] if value else "")
    return m.group(1).lower() if m else None


def source(path: pathlib.Path) -> str:
    """`path` with comments stripped.

    Blocks are delimited by the first `}`, so a `}` inside a comment
    would truncate the block and hide every declaration after it —
    falling back to an earlier block's stale value, the same vacuous
    pass by another route. These stylesheets carry long prose
    comments right above the tokens, so this is not hypothetical.
    """
    return re.sub(r"/\*.*?\*/", "", path.read_text(), flags=re.S)


def blocks(path: pathlib.Path, selector: str, label: str) -> list[str]:
    """Every `selector` block in `path`, in source order."""
    text = source(path)
    found = [
        text[m.end() :].split("}", 1)[0]
        for m in re.finditer(selector, text)
    ]
    if not found:
        fail(f"{path.name}: no {label} block")
    return found


def resolve(path: pathlib.Path, prop: str, selector: str, label: str) -> str:
    """`prop`'s cascade-winning value across every `selector` block.

    Resolved per property, not per block. A stylesheet may carry more
    than one such block: reading only the first would let an appended
    override ship while this check kept reading the original, and
    reading only the last would let a one-token override hide every
    other token's real value. Both are vacuous passes.

    A block that declares `prop` as anything but a 6-digit hex is a
    hard error, not a skip — skipping it would fall back to the
    previous block's stale value, which is the same vacuous pass by
    another route.
    """
    values = []
    for block in blocks(path, selector, label):
        value = declared(block, prop)
        if value is None:
            continue
        if "!important" in value:
            fail(
                f"{path.name}: a {label} block declares `{prop}` "
                "`!important`. A token block has no legitimate use for "
                "it, and this check models the cascade as last-wins, so "
                "it would read the wrong winner. Drop the `!important`."
            )
        found = as_hex(value)
        if found is None:
            fail(
                f"{path.name}: a {label} block declares `{prop}: {value}`, "
                "which is not a 6-digit hex. This check compares hex "
                "values, so it cannot follow that — resolve the colour "
                "to a literal here, or update this script to understand "
                "the new form."
            )
        values.append(found)
    if not values:
        fail(f"{path.name}: no `{prop}` declaration in any {label} block")
    return values[-1]


def root_hex(path: pathlib.Path, prop: str) -> str:
    """A brand endpoint, which must be declared EXACTLY once.

    Not last-wins like a themed token: `theme.css` carries more than
    one bare `:root` block (the brand palette, then the dark-theme
    defaults), and taking the last would let an ordinary addition to
    the dark block silently become the derivation endpoint. The check
    would then still fail — but by accusing the *light* accent of a
    brand violation while naming the dark fill as the authority, when
    nothing about the brand changed. A count check fails in terms of
    the actual problem instead.
    """
    found = [
        value
        for block in blocks(path, BARE_ROOT, "bare `:root`")
        if (value := declared(block, prop)) is not None
    ]
    if not found:
        fail(f"{path.name}: no `{prop}` in any bare `:root` block")
    if len(found) > 1:
        fail(
            f"{path.name}: `{prop}` is declared in {len(found)} bare "
            "`:root` blocks. It is a brand endpoint this check derives "
            "from, so which one wins must not be ambiguous — keep it in "
            "the brand-palette block only."
        )
    value = as_hex(found[0])
    if value is None:
        fail(f"{path.name}: `{prop}` is `{found[0]}`, not a 6-digit hex")
    return value


def light_hex(path: pathlib.Path, prop: str) -> str:
    return resolve(path, prop, LIGHT, "light-theme")


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
        required=True,
        help="path to the built site (for the 404 artifact check)",
    )
    args = parser.parse_args()

    check_accent()
    check_branded_404(pathlib.Path(args.dist).resolve())


if __name__ == "__main__":
    main()
