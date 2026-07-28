"""Content guards for the shipped locale catalogs (issue #95).

`extract-keys --check` compares key *structure* and never looks at
a translated value; `merge-keys` folds in any non-empty worksheet
entry. Nothing else in the pipeline reads the copy, so a bad
worksheet lands silently and renders live: a reviewer skimming a
language they do not read sees plausible text.

Eight predicates live here. Five are **exact contracts** and hold
for any corpus of translated strings:

1. `foreign_scripts` — the writing system is wrong for the locale
   (ported from KiwiCV's `scripts/i18n/check-scripts.cjs` via
   KiwiCanopy-web's `scripts/check-scripts.mjs`, which had already
   adapted it to flat `{key: string}` JSON — KiwiDesk's exact
   shape).
2. `tagged_stub` — English text with a locale marker appended,
   `"Icon & name (ES)"` / `"Group adjacent…（JA）"`.
3. `placeholder_drift` — the `%1$@`/`%1$d` set does not match the
   English. The only one that guards a runtime path.
4. `overlapping_locales` — two different languages sharing a
   suspicious number of byte-identical values (the shape that
   caught ~360 entries of French sitting in `it.json`).
5. `collapsed_translations` — one locale reusing a single value
   for many unrelated English strings (the shape that caught 48
   interpolated strings per locale replaced with a bare
   `"Opzione %1$@"` / `"Opção %1$@"`).

The sixth is a **heuristic tuned on short app UI labels**, and the
only one with a corpus scope:

6. `english_residue` — an English sentence with single words
   swapped, `"追加 Window"`, `"編集ing init.lua directly"`. Runs on
   non-Latin-script locales only (see its docstring), and callers
   apply it to the app catalogs only — the marketing site's
   manifests are prose full of third-party product names
   (`Homebrew`, `SketchyBar`, `JankyBorders`) and embedded HTML,
   where every retained token is legitimate. Pulling that
   vocabulary into `GLOSSARY` would couple the app's glossary to
   the site's copy; scoping the predicate is the smaller seam.

A script guard catches the wrong *script*, never the wrong
*language within one script* — French in Italian is Latin either
way. That gap is why 2–6 exist alongside 1.

Every predicate takes the strings it judges as arguments and is
kept apart from the corpus walk, so the sibling Swift suite can
exercise it against text the test controls. Asserting against the
shipped catalogs instead would make the guard's own coverage
depend on the corpus staying dirty — a test that passes only
while a bug is live and fails the moment it is fixed.

There is deliberately **no baseline/exemption file**: the corpus
is clean once this change lands, so any hit is a real defect.
"""

# `X | None` in a signature is evaluated at def time, so without
# this the module will not import on macOS's own python3 (3.9.6) —
# which is what `/usr/bin/env python3` finds for a contributor who
# has not installed a newer one, and this repo asks for none.
# `scripts/merge-keys` and `scripts/drop-key` carry it for the same
# reason. Deferring annotation evaluation keeps the modern syntax
# readable without pinning an interpreter.
#
# (An earlier version of this comment blamed the Swift fixtures for
# replacing the process environment and so dropping PATH. That was
# true and is now fixed — they inherit it — but it was never the
# whole reason, and it made the constraint look test-only.)
from __future__ import annotations

import re

# Writing systems attributable to a locale. Latin is deliberately
# absent: every locale uses it legitimately for `KiwiDesk`, URLs
# and `%1$@`, so its presence proves nothing.
#
# Han is shared by Japanese and both Chinese scripts and so cannot
# separate them; kana can, because Chinese has none. That
# asymmetry is why the table lists which locales may use each
# script rather than one "expected script" per locale.
#
# The scripts with an empty tuple are not "unused forever" — they
# are unclaimed. Ship `ar.json` without adding `ar` here and every
# Arabic value fails as foreign to its own locale. That is
# fail-closed rather than fail-open, which is the right direction,
# and `unregistered_locales` fires first with a message that says
# where to register.
#
# Ranges use `\u` escapes: the exact boundaries carry the reasoning
# (see Kana), and a literal `・` inside a character class is
# invisible in review.
SCRIPTS = [
    ("Cyrillic", r"[\u0400-\u04ff\u0500-\u052f]", ("ru",)),
    ("Greek", r"[\u0370-\u03ff]", ()),
    (
        # Hiragana, then katakana split so U+30FB `・` falls in
        # the hole: that interpunct is shared CJK punctuation, not
        # a kana letter, and Traditional Chinese uses it between
        # transliterated foreign names (`史蒂夫・賈伯斯`) — inside
        # the range it failed correct zh-Hant copy as Japanese.
        # Half-width katakana is included: unambiguously kana, and
        # previously unattributable to any locale.
        "Kana",
        r"[\u3041-\u309f\u30a0-\u30fa"
        r"\u30fc-\u30ff\uff66-\uff9d]",
        ("ja",),
    ),
    (
        # URO, Ext-A, compatibility ideographs. Ext-B and beyond
        # (U+20000+) are deliberately out — astral-plane rare
        # characters are not the case this guard is aimed at.
        "Han",
        r"[\u4e00-\u9fff\u3400-\u4dbf\uf900-\ufaff]",
        ("ja", "zh-Hans", "zh-Hant"),
    ),
    (
        # Syllables, conjoining jamo, and the compatibility jamo
        # block a plain Hangul range misses.
        "Hangul",
        r"[\uac00-\ud7af\u1100-\u11ff\u3130-\u318f]",
        ("ko",),
    ),
    ("Arabic", r"[\u0600-\u06ff]", ()),
    ("Hebrew", r"[\u0590-\u05ff]", ()),
]

_SCRIPT_RES = [
    (name, re.compile(pattern), set(locales))
    for name, pattern, locales in SCRIPTS
]

# Locales whose copy is written in a non-Latin script. Derived
# from the table above rather than restated, so adding a locale
# there cannot leave this set behind. `english_residue` applies
# only to these — see its docstring.
NON_LATIN_LOCALES = {
    locale for _, _, locales in SCRIPTS for locale in locales
}

# Locales that write in Latin script, declared rather than
# inferred. There is no `("Latin", …)` row in `SCRIPTS` because
# every locale uses Latin characters for `KiwiDesk`, URLs and
# `%1$@`, so a Latin *pattern* proves nothing — and a locale
# missing from both sets would have `english_residue` silently
# disabled, which is the failure the registry exists to prevent.
# `unregistered_locales` refuses such a locale;
# `LocalizationRegistryTests` pins it.
LATIN_LOCALES = {
    "de",
    "es",
    "fr",
    "it",
    "pt-BR",
}

# Terms that stay English in every locale by design: the product,
# the technologies it wraps, Apple's own feature and key names,
# and the layout-mode names the GUI shows verbatim. This is a
# glossary — the vocabulary a translator is told to leave alone —
# not a per-key exemption list.
#
# The layout names are here to stop the residue rule flagging a
# locale that legitimately KEEPS a mode name in Latin inside its
# own script. Only `ru` and `zh-Hant` exercise it (18 and 10
# values); the CJK three never have, and structurally now cannot
# for a capitalised name, since `untranslated_mode_names` forbids
# it there. (`de` keeps them Latin as well but needs no exemption
# — `english_residue` is scoped away from Latin-script locales
# regardless.) It costs the residue
# rule a little reach: `"フォーカス Stack"` for "Focus Stack" reads
# as a deliberate name rather than residue.
#
# Do NOT read this as "the GUI ships mode names untranslated":
# the three CJK locales (`ja` モノクル, `ko` 트랙, `zh-Hans` 单窗)
# render them natively, while the seven Latin-script locales keep
# them English so the picker matches the value typed into Lua and
# the CLI (`set_mode(1, "stack")`). That is why no guard REQUIRES
# a mode name to be KEPT, unlike `PRODUCT_NAMES`;
# `untranslated_mode_names` instead requires the English name to
# be ABSENT once a locale has translated its own picker.
# `LocalizationModeNamePolicyTests` pins which locales are on
# which side, so this comment cannot drift.
#
# Grouped, because an unlabelled flat set is how a glossary turns
# into a baseline: without the grouping a reader cannot tell "the
# shipped UI really renders this untranslated" from "someone
# silenced a hit to get the gate green". Add to the group that
# justifies the term, or argue for a new group.
GLOSSARY = {
    # The product, and the technologies it wraps or names.
    "bsp",
    "ide",
    "kiwidesk",
    "lua",
    "macos",
    "tiling",
    "sip",
    "ui",
    # Apple's own names: features, key names, and API terms. The
    # `system_shortcut.*` keys follow macOS per locale, but these
    # words stay English inside prose in every locale.
    "bundle",  # "Bundle identifier"
    "control",  # "Mission Control"
    "desktop",  # Mission Control's own noun
    "dock",
    "esc",
    "finder",
    "mission",
    "sf",  # "SF Symbol"
    "symbol",
    "symbols",
    # Layout-mode names, for the locales that keep one in Latin
    # inside their own script. See the block comment above.
    "floating",
    "grid",
    "monocle",
    "scrolling",
    "stack",
    "track",
    # `sticky` is a `PRODUCT_NAMES` entry (#579) — kept verbatim in
    # every locale, like "App Bar"/"Space Bar" below. It stays in
    # `GLOSSARY` for the SAME reason those do: the residue guard must
    # not flag the now-*required* verbatim "Sticky" sitting in a
    # non-Latin sentence as leaked English. The two guards agree —
    # `dropped_product_names` demands it be present, `english_residue`
    # is told it is allowed. (It is NOT a layout mode; not in
    # `MODE_NAME_KEYS`.)
    "sticky",
    # Nouns the shipped UI renders untranslated in the GUI's own
    # feature names — "App Bar", "Space Bar", "Gaps" — so prose
    # referring to them keeps the word. These are the entries most
    # worth challenging if the GUI ever translates those names.
    "app",
    "apps",
    "bar",
    "gaps",
    "space",
    "spaces",
    # Literal values and format tokens the user types or reads.
    "default",  # the standard shortcut mode's literal name
    "pt",  # the unit
    "rrggbb",
    "rrggbbaa",
}

# Multi-word feature names the GUI renders untranslated, which a
# translation must therefore carry verbatim. `GLOSSARY` above only
# *exempts* these words from the residue rule — it never checked
# that anyone kept them, and `de` had independently rendered every
# one of them as "Space-Leiste" / "App-Leiste".
#
# Enforced in EVERY locale, whatever its script: the label keys
# (`bars.switch.app_bar`, `bars.switch.space_bar`) ship Latin in
# all eleven catalogs, so a translation that renames them names
# something the picker does not. That catalog fact is the
# membership test — a name belongs here when its own label key is
# untranslated everywhere, which is checkable, unlike "is it a
# coinage". `MODE_NAME_KEYS` below is the other side: those labels
# ARE translated per locale, so they get the opposite guard.
#
# A phrase, not the tokens: `GLOSSARY` holds "app", "bar" and
# "space" individually, so a word-level rule could not tell
# "App Bar" from "App-Leiste". Adding a name here is a product
# decision about what the GUI leaves in English — argue it, do
# not grow the list to silence a hit.
PRODUCT_NAMES = (
    "App Bar",
    "Space Bar",
    # The window-sticky feature (#579): a coined KiwiDesk name kept
    # verbatim in every locale, like the bars — NOT translated to a
    # native word for "pinned" (de "Fixierung", ru "закрепление",
    # zh-Hant "常駐"). The first single-word product name: every
    # `sticky`/`Sticky` hit in en.json names this exact feature (no
    # incidental UI use to false-positive on), so it is safe as one
    # word. The obligation auto-scopes to the ~16 keys whose English
    # carries the word; the display tier is "Display Sticky" (de
    # "Display-Sticky"), "display" being an ordinary qualifier that
    # compounds per locale around the fixed "Sticky" atom.
    "Sticky",
)

# Locale codes a stub marker is written with. Keyed by the base
# language, so `"Texto Item (PT)"` in `pt-BR.json` is caught even
# though the tag is not the full locale code.
_STUB_TAGS = {
    "de": {"de"},
    "en": {"en"},
    "es": {"es"},
    "fr": {"fr"},
    "it": {"it"},
    "ja": {"ja", "jp"},
    "ko": {"ko", "kr"},
    "pt": {"pt", "br", "ptbr", "pt-br"},
    "ru": {"ru"},
    "zh": {"zh", "cn", "tw", "hans", "hant", "zh-hans", "zh-hant"},
}

# Both paren shapes. The full-width pair is the reason an
# ASCII-only regex once reported a 45%-complete ja file as 98%
# complete.
_TAG = re.compile(r"[(（]\s*([A-Za-z][A-Za-z\-]{0,7})\s*[)）]")


def unregistered_locales(names: list[str]) -> list[str]:
    """Shipped locales this module has no policy for.

    `SCRIPTS` and `_STUB_TAGS` are registries, and a locale absent
    from them loses guards **silently** — `tagged_stub("pl", …)`
    finds no tag set and returns None, `english_residue("pl", …)`
    reads `pl` as Latin-script and returns nothing. Two of the
    guards would be off with no signal at all, which is the exact
    failure the guards exist to prevent, one level up.

    So membership is checked rather than assumed — in **both**
    registries, which is a tightening. It used to require only
    `_STUB_TAGS`, on the reasoning that a locale absent from
    `SCRIPTS` is Latin-script and that is a real answer.

    The reasoning is sound and the default is still wrong to rely
    on, because being wrong is invisible. `english_residue` keys
    off `NON_LATIN_LOCALES`, so a Greek or Hebrew locale
    registered in `_STUB_TAGS` but forgotten in `SCRIPTS` is read
    as Latin-script and has that guard **silently disabled** — it
    reports nothing and looks exactly like a clean catalog. A
    guard that cannot fire is worse than no guard, since it also
    carries the claim of coverage. So which script a locale writes
    in is a declaration, not a default: a Latin-script locale says
    so by joining `LATIN_LOCALES`.

    (`dropped_product_names` no longer keys off either set — it
    applies to every locale — so it is not the reason this is a
    declaration, though it was when the rule was written.)

    `LocalizationRegistryTests` walks the shipped files and pins
    the same requirement.
    """
    return sorted(
        name
        for name in names
        if name != "en"
        and (
            base_language(name) not in _STUB_TAGS
            or (
                name not in LATIN_LOCALES
                and name not in NON_LATIN_LOCALES
            )
        )
    )

# Interpolation specifiers, so `%1$d` never contributes the word
# `d` and `%1$@` never contributes `@`. Includes `%%`, the literal
# percent escape, which is likewise not a word.
_SPECIFIER = re.compile(r"%\d+\$[@d]|%[@d]|%%")

# Just the *argument* references, for `placeholder_drift`. `%%`
# is deliberately excluded: it renders a literal `%` and carries
# no argument, so a translation may legitimately add or drop it —
# several locales write "%1$d%%" where the English spells out
# "percent". Counting it as drift flagged four correct values.
_ARG_SPECIFIER = re.compile(r"%\d+\$[@d]")

# A modifier glyph and the key name that follows it: `⌘ Command`,
# `⇧Shift`. These are Apple's key names, correctly left English in
# every locale, and stripping them here is better than
# glossarising `command` — which would hide the real residue in
# `"Command 中央"` for English "Command Center".
_KEY_NAME = re.compile(r"[⌘⌥⌃⇧⇪]+[ \t]*[A-Za-z]*")

# Dotted identifiers and calls: `init.lua`,
# `KiwiDesk.reload_config()`.
_IDENTIFIER = re.compile(
    r"\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+(?:\(\))?"
)

# `+n` in "collapse into a +n badge" is a literal the UI renders.
_COUNT_TOKEN = re.compile(r"\+[a-z]\b")

_WORD = re.compile(r"[A-Za-z]+")


def base_language(locale: str) -> str:
    """`pt-BR` → `pt`, `zh-Hant` → `zh`, `ja` → `ja`."""
    return locale.split("-")[0]


def foreign_scripts(locale: str, value: str) -> list[str]:
    """The writing systems in `value` that `locale` does not use."""
    return [
        name
        for name, pattern, locales in _SCRIPT_RES
        if locale not in locales and pattern.search(value)
    ]


def tagged_stub(locale: str, value: str) -> str | None:
    """The locale marker `value` carries, if it is a tagged stub.

    A stub is untranslated English with the target locale's own
    code appended, so only that locale's tags count — a value
    legitimately naming a *different* language is not a stub.
    """
    allowed = _STUB_TAGS.get(base_language(locale), set())
    for tag in _TAG.findall(value):
        if tag.lower() in allowed:
            return tag
    return None


def placeholder_drift(value: str, english: str) -> str | None:
    """How `value`'s interpolation specifiers differ from
    `english`'s, or None when they match.

    The one guard here that protects a *runtime* path rather than
    the copy: these values reach `String(format:)`, so a dropped
    `%1$@` silently loses the interpolated name or count and an
    invented one reads an argument that was never passed.
    `TRANSLATION_BRIEF.md` has always told translators to preserve
    the set exactly; nothing enforced it.

    Compares as a multiset, so a duplicate specifier counts — but
    not as a sequence: the numbering exists precisely so a
    translation *can* reorder them, and many languages must.
    """
    want = sorted(_ARG_SPECIFIER.findall(english))
    got = sorted(_ARG_SPECIFIER.findall(value))
    if want == got:
        return None
    missing = sorted(_multiset_difference(want, got))
    extra = sorted(_multiset_difference(got, want))
    parts = []
    if missing:
        parts.append(f"drops {', '.join(missing)}")
    if extra:
        parts.append(f"adds {', '.join(extra)}")
    return " and ".join(parts)


def _multiset_difference(
    left: list[str], right: list[str]
) -> list[str]:
    """Members of `left` not covered by `right`, counting
    duplicates — a plain set difference would call `%1$@ %1$@`
    against `%1$@` a match."""
    remaining = list(right)
    surplus: list[str] = []
    for item in left:
        if item in remaining:
            remaining.remove(item)
        else:
            surplus.append(item)
    return surplus


def _words(text: str) -> list[str]:
    """Latin words in `text`, with everything that is English by
    design removed first: specifiers, Apple key names, dotted
    identifiers and literal UI tokens."""
    for pattern in (
        _SPECIFIER,
        _KEY_NAME,
        _IDENTIFIER,
        _COUNT_TOKEN,
    ):
        text = pattern.sub(" ", text)
    return _WORD.findall(text)


def english_residue(
    locale: str, value: str, english: str
) -> list[str]:
    """English fragments left behind in `value`.

    Aimed at a worksheet that substituted single words instead of
    translating the sentence — `"追加 Window"` for "Add Window",
    `"編集ing init.lua directly"` for "Editing init.lua directly".

    **Non-Latin-script locales only, by design.** In a
    Latin-script locale a retained English word is
    indistinguishable from a cognate or a loanword: `"Item ativo"`,
    `"Mein Setup"` and `"Limite del track"` are all correct, so
    the rule would flag good translations by the dozen. Scoped
    here, it needs no per-language lexicon.

    An earlier draft carried a second sub-rule that ran in *every*
    locale: an English `-ing` welded onto a translated stem
    (`"Modifiering"`, `"Editaring"`), justified by "no target
    language forms a word that way". German falsifies that outright
    — `fing`, `ging`, `Ring`, and the productive `-ling` class
    (`Frühling`, `Lehrling`); the repo's own site copy contains
    `fing`. Scoping it here instead made it unreachable rather than
    correct: a weld in a non-Latin locale has a non-Latin stem
    (`"保存d"`, `"編集ing"`), so tokenizing leaves a bare suffix and
    nothing to match. It is gone. The values it aimed at are caught
    by the rule above — `"編集ing init.lua directly."` fails on
    `directly`, not on the weld — and a Latin locale's genuine weld
    is review-caught, like the rest of Latin word-swap residue.

    The `-s`/`-ed`/`-d` welds (`"保存d profiles"`, `"Salvard"`) were
    never checked, for the same reason plus a worse one: native
    words ending in those letters are everywhere ("und", "bord",
    "Feld").
    """
    if locale not in NON_LATIN_LOCALES:
        return []
    if not _is_partly_translated(locale, value):
        return []
    source = _words(english)
    lowered = {word.lower() for word in source}
    value_words = _words(value)
    found = [
        word
        for word in value_words
        if word.lower() in lowered
        and word.lower() not in GLOSSARY
        and (len(word) > 1 or word.lower() == "a")
    ]
    return sorted(set(found))


def dropped_product_names(
    value: str, english: str
) -> list[str]:
    """`PRODUCT_NAMES` the English carries and `value` does not.

    The GUI ships "App Bar" and "Space Bar" untranslated in
    **every** locale — `bars.switch.app_bar` and
    `bars.switch.space_bar` are Latin in all eleven — so any locale
    that renders them in its own words leaves the prose naming
    something the interface does not ("Die App-Leiste erscheint…"
    beside a chip reading "App Bar"). Search made it plainer still:
    the destination and surface names are now breadcrumb segments,
    so a locale-invented name shows up on every hit inside that
    pane.

    Applies to every locale, script irrelevant. An earlier cut
    exempted non-Latin locales on the reasoning that an English
    phrase sits in a Japanese sentence as a foreign body, so
    adapting it is a real editorial choice. That is the right lens
    for `english_residue` — a *forgotten* English word — and the
    wrong one here: these two names were never meant to be
    translated in any locale, no more than "KiwiDesk", "Lua" or
    "BSP" are, which `_is_partly_translated` already assumes when
    it lists "App Bar" among the values that are correctly
    all-English in a non-Latin catalog. The exemption was also
    unused — ja/ko/zh-Hans never once transliterated a name; the
    values that failed had dropped whole clauses instead.

    Transliterating would actively hurt in ja and ko, which is why
    this is a rule and not a preference: スペースバー and 스페이스바
    are the ordinary words for the *spacebar key*, and neither
    script has capitalization to mark a proper noun, so the feature
    name would be indistinguishable from the key.

    Case-insensitive, because a locale's capitalization rules are
    its own ("App bar" is a style choice, not a dropped name).
    Substring, not word-boundary: German's "App-Leiste" must NOT
    count as carrying "App Bar", which is exactly what a
    token-level test would conclude.

    Separators are normalised first, and that is load-bearing for
    the very locale this guard was written for. German joins a
    two-word proper noun to a following noun with hyphens, so
    "Space-Bar-Farben" is the orthographically CORRECT rendering
    of "Space Bar colors" and it does keep the name — a raw
    substring test rejects it and pushes the translator toward the
    ungrammatical "Space Bar Farben". A non-breaking space between
    the two words is the same class, and travels invisibly through
    translation tools. Normalising costs nothing: "App-Leiste"
    still fails, because `leiste` is not `bar`.
    """
    haystack = _flatten_separators(value)
    needles = _flatten_separators(english)
    return [
        name
        for name in PRODUCT_NAMES
        if _flatten_separators(name) in needles
        and _flatten_separators(name) not in haystack
    ]


# The layout modes whose name a locale may translate. `BSP` is
# absent deliberately: it is an initialism every locale keeps, so
# it has no translated form to diverge from.
MODE_NAME_KEYS = (
    "layout.floating.name",
    "layout.grid.name",
    "layout.monocle.name",
    "layout.scrolling.name",
    "layout.stack.name",
    "layout.track.name",
)


def untranslated_mode_names(
    value: str, catalog: dict, english: dict
) -> list[str]:
    """English mode names `value` keeps that its own picker doesn't.

    The mirror of `dropped_product_names`, and deliberately the
    *opposite* shape. A product name is a coinage the GUI never
    translates, so that guard demands the English be **present**. A
    mode name is ordinary tiling vocabulary each locale may render
    natively, so there is no single right word to demand — this
    guard instead requires the English name to be **absent** once
    the locale has translated the picker. `de`, `ru` and `zh-Hant`
    keep the English names, so their picker *is* the English word
    and they are skipped by construction, with no exemption list.

    Reading `layout.<mode>.name` from the locale's own catalog is
    the whole trick: the rule is "prose agrees with your picker",
    which needs no opinion about which word is correct.

    The symmetric form — demand the locale's own translation be
    present — cannot work, and rejecting it is what made this shape
    look impossible. Spanish renders one help string "las
    ventanas… flotarán", a verb inflection carrying no noun, so
    demanding "Flotante" would flag correct copy.

    **Case-sensitive, and that is the referential/descriptive
    discriminator.** Capitalised "Floating" names the mode;
    lower-case "la modalità floating" is a borrowed adjective
    describing behaviour, which a locale is free to use. Matching
    only the capitalised form separates the two at no cost. The
    residual ambiguity is a sentence-initial capital — `it`'s
    "Stack dell'IDE" reads as either — so a hit is a prompt for
    judgment, not proof; there are few enough for that to be the
    right trade.

    One blind spot the case-note understates (#568): a *lower-case*
    English name that is also a `GLOSSARY` word — `track` is both —
    is unreachable by BOTH passes, not merely rare. This guard
    skips it (case-sensitive by design) and `english_residue`
    exempts it (glossary), so a `ja` value writing "track
    レイアウト" against a トラック picker passes both. The
    lower-case referential use is the accepted cost of the
    referential/descriptive split; naming it here so the next
    reader does not mistake the hole for an edge case.
    """
    found = []
    for key in MODE_NAME_KEYS:
        source = english.get(key)
        local = catalog.get(key)
        if not source or not local:
            continue
        if _flatten_separators(local) == _flatten_separators(
            source
        ):
            continue
        # NOT `\b`: a CJK character is a Unicode word character,
        # so `\bMonocle\b` does not match "Monocleは" — Japanese
        # and Chinese set the name flush against native text with
        # no space, which is the commonest shape in exactly the
        # locales this guard covers. The boundary that is wanted
        # is "not part of a longer LATIN word", so assert on ASCII
        # alphanumerics directly: "Stackoverflow" still does not
        # match "Stack".
        pattern = (
            rf"(?<![A-Za-z0-9]){re.escape(source)}"
            rf"(?![A-Za-z0-9])"
        )
        if re.search(pattern, value):
            found.append(source)
    return sorted(set(found))


# Whitespace (including NBSP) and the hyphen/dash family, which a
# compounding language uses where English uses a space.
_SEPARATORS = re.compile(r"[\s ‐-―\-]+")


def _flatten_separators(text: str) -> str:
    """`text` lower-cased with every separator run as one space."""
    return _SEPARATORS.sub(" ", text).strip().lower()


def _is_partly_translated(locale: str, value: str) -> bool:
    """Whether `value` carries any character of its own script.

    An all-English value in a non-Latin locale is *untranslated*,
    and this rule stays out of it: for 15-21 keys per locale that
    is the correct answer (`KiwiDesk`, `Lua`, `BSP`, `App Bar`,
    `Mission Control`), and telling those apart from a genuinely
    skipped string needs a per-locale allowlist nothing here has.

    Stated plainly because an earlier draft of this docstring
    claimed the defect had "a different fix": it does not. No guard
    owns it, and `write_missing` will not re-mint a key whose
    locale value is non-empty, so an untranslated-but-English value
    never resurfaces on a to-translate list either. `drop-key
    --locale` is the only way to put one back in play.
    """
    return any(
        pattern.search(value)
        for name, pattern, locales in _SCRIPT_RES
        if locale in locales
    )


# A locale pair is flagged at 5% of the keys they share, floored at
# 20. Sibling languages really do coincide on short UI labels —
# `es`/`pt-BR` sit at 13 identical values with the corpus clean —
# while a whole file pasted into the wrong locale lands near 45%.
#
# At the corpus's 810 shared keys the ratio governs (5% = 40) and
# the floor is dead outside fixtures; the floor is what keeps a
# *small* catalog (the 237-key site manifests, or a new locale
# mid-translation) from tripping on a handful of matches.
OVERLAP_RATIO = 0.05
OVERLAP_FLOOR = 20


def _nontrivial(value: str) -> bool:
    """Whether two locales sharing this value is worth counting.
    A one-word label ("Lua", "Monitor") coincides innocently;
    length also stands in for the word count CJK does not space."""
    return len(value) >= 12 or " " in value


# A translation reused for this many *distinct* English strings is
# a collapse. Both thresholds were measured against the shipped
# corpus, which is the only place their headroom is visible — record
# it here when it moves, because the numbers alone read arbitrary:
#
# - Plain values: the worst *innocent* collapse in the corpus is
#   **3** distinct English strings on one value (`de` "Standard" for
#   "default"/"Default"/"standard", `ko` "고정" for "Make
#   sticky"/"Rigid"/"Sticky"). Near-synonyms sharing one target word
#   are normal and must pass, so the limit sits at 5 — two clear.
#   That is thin for a growing Settings UI, which reuses exactly
#   this word class; a fourth synonym is the signal to re-measure
#   rather than to raise the number reflexively.
# - Specifier-bearing values: 3 as well, not 2. A string specific
#   enough to interpolate an argument rarely coincides across
#   unrelated keys — but *two* keys legitimately share one English
#   string today (`app_bar.preview.caption` and
#   `space_bar.preview.caption`, both "Position: %1$@ · %2$@"), and
#   a purely cosmetic edit to one of them would make the English
#   distinct and hard-fail all eleven catalogs at once. §5 says a
#   cosmetic edit keeps translations, so the guard must not punish
#   it. The real defect this caught had groups of 37, 4, 4 and 3, so
#   3 loses nothing.
COLLAPSE_LIMIT = 5
SPECIFIER_COLLAPSE_LIMIT = 3


def collapsed_translations(
    catalog: dict[str, str], english: dict[str, str]
) -> list[tuple[str, list[str]]]:
    """Values this locale reuses for unrelated English strings.

    Catches the defect class the other five cannot see: content
    that is fluent, in the right script, free of English residue —
    and simply not a translation of its key. A worksheet generator
    that gives up on interpolated strings emits one filler for all
    of them, and every per-value check passes.

    Returns `(value, keys)` worst first, so the report leads with
    the biggest collapse.
    """
    groups: dict[str, list[str]] = {}
    for key in sorted(catalog):
        if key in english:
            groups.setdefault(catalog[key], []).append(key)
    findings = [
        (value, keys)
        for value, keys in groups.items()
        if len({english[key] for key in keys}) >= COLLAPSE_LIMIT
        or (
            _SPECIFIER.search(value)
            and len({english[key] for key in keys})
            >= SPECIFIER_COLLAPSE_LIMIT
        )
    ]
    return sorted(findings, key=lambda hit: -len(hit[1]))


def overlapping_locales(
    catalogs: dict[str, dict[str, str]],
    english: dict[str, str],
) -> list[tuple[str, str, list[str]]]:
    """Locale pairs that share too many identical translations.

    Only values that *differ from English* count: two locales
    agreeing on an untranslated string is the untranslated
    defect, not contamination. Pairs of the same base language are
    skipped — `zh-Hans` and `zh-Hant` are one language in two
    scripts and legitimately agree on a great deal.
    """
    names = sorted(catalogs)
    findings: list[tuple[str, str, list[str]]] = []
    for index, first in enumerate(names):
        for second in names[index + 1 :]:
            if base_language(first) == base_language(second):
                continue
            left, right = catalogs[first], catalogs[second]
            shared = set(left) & set(right)
            same = sorted(
                key
                for key in shared
                if left[key] == right[key]
                and left[key] != english.get(key)
                and _nontrivial(left[key])
            )
            limit = max(
                OVERLAP_FLOOR, int(len(shared) * OVERLAP_RATIO)
            )
            if len(same) >= limit:
                findings.append((first, second, same))
    return findings
