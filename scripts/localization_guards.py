"""Content guards for the shipped locale catalogs (issue #95).

`extract-keys --check` compares key *structure* and never looks at
a translated value; `merge-keys` folds in any non-empty worksheet
entry. Nothing else in the pipeline reads the copy, so a bad
worksheet lands silently and renders live: a reviewer skimming a
language they do not read sees plausible text.

Four predicates live here, ordered by how much they can prove:

1. `foreign_scripts` — the writing system is wrong for the locale
   (ported from KiwiCV's `scripts/i18n/check-scripts.cjs` via
   KiwiCanopy-web's `scripts/check-scripts.mjs`, which had already
   adapted it to flat `{key: string}` JSON — KiwiDesk's exact
   shape).
2. `tagged_stub` — English text with a locale marker appended,
   `"Icon & name (ES)"` / `"Group adjacent…（JA）"`.
3. `english_residue` — an English sentence with single words
   swapped, `"保存 as New Profile…"`, `"編集ing init.lua directly"`.
4. `overlapping_locales` — two different languages sharing a
   suspicious number of byte-identical values (the shape that
   caught ~360 entries of French sitting in `it.json`).
5. `collapsed_translations` — one locale reusing a single value
   for many unrelated English strings (the shape that caught 48
   interpolated strings per locale replaced with a bare
   `"Opzione %1$@"` / `"Opção %1$@"`).

A script guard catches the wrong *script*, never the wrong
*language within one script* — French in Italian is Latin either
way. That gap is why 2–4 exist alongside 1.

Every predicate takes the strings it judges as arguments and is
kept apart from the corpus walk, so the sibling Swift suite can
exercise it against text the test controls. Asserting against the
shipped catalogs instead would make the guard's own coverage
depend on the corpus staying dirty — a test that passes only
while a bug is live and fails the moment it is fixed.

There is deliberately **no baseline/exemption file**: the corpus
is clean once this change lands, so any hit is a real defect.
"""

# `X | None` in a signature is evaluated at def time, and the
# oldest interpreter this has to run under is the system python3
# (3.9) — a test that replaces the environment drops PATH, so
# `/usr/bin/env python3` no longer finds a newer one. Deferring
# annotation evaluation keeps the modern syntax readable without
# pinning an interpreter the repo does not otherwise require.
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
SCRIPTS = [
    ("Cyrillic", r"[Ѐ-ӿԀ-ԯ]", ("ru",)),
    ("Greek", r"[Ͱ-Ͽ]", ()),
    ("Kana", r"[぀-ヿ]", ("ja",)),
    (
        "Han",
        r"[一-鿿㐀-䶿豈-﫿]",
        ("ja", "zh-Hans", "zh-Hant"),
    ),
    ("Hangul", r"[가-힯ᄀ-ᇿ]", ("ko",)),
    ("Arabic", r"[؀-ۿ]", ()),
    ("Hebrew", r"[֐-׿]", ()),
]

_SCRIPT_RES = [
    (name, re.compile(pattern), set(locales))
    for name, pattern, locales in SCRIPTS
]

# Locales whose copy is written in a non-Latin script. Derived
# from the table above rather than restated, so adding a locale
# there cannot leave this set behind. `english_residue`'s first
# rule only applies to these: in a Latin-script locale a retained
# English word is indistinguishable from a cognate or a loanword.
NON_LATIN_LOCALES = {
    locale
    for name, _, locales in SCRIPTS
    for locale in locales
    if name != "Latin"
}

# Terms that stay English in every locale by design: the product,
# the technologies it wraps, Apple's own feature and key names,
# and the layout-mode names the GUI shows verbatim. This is a
# glossary — the vocabulary a translator is told to leave alone —
# not a per-key exemption list.
GLOSSARY = {
    "app",
    "apps",
    "bar",
    "bsp",
    "control",  # Apple's "Mission Control", kept in every locale
    "default",  # the literal name of the standard shortcut mode
    "desktop",
    "dock",
    "esc",
    "finder",
    "floating",
    "gaps",
    "ide",
    "kiwidesk",
    "lua",
    "macos",
    "mission",
    "monocle",
    "pt",
    "rrggbb",
    "rrggbbaa",
    "sf",
    "sip",
    "space",
    "spaces",
    "sticky",
    "symbol",
    "symbols",
    "tiling",
    "ui",
}

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

# Interpolation specifiers, so `%1$d` never contributes the word
# `d` and `%1$@` never contributes `@`.
_SPECIFIER = re.compile(r"%\d+\$[@d]|%[@d]|%%")

# A modifier glyph and the key name that follows it: `⌘ Command`,
# `⇧Shift`. These are Apple's key names, correctly left English in
# every locale, and stripping them here is better than
# glossarising `command` — which would hide the real residue in
# `"Command 中央"` for English "Command Center".
_KEY_NAME = re.compile(r"[⌘⌥⌃⇧⇪]+\s*[A-Za-z]*")

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
        if tag.lower().replace("_", "-") in allowed:
            return tag
    return None


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

    Two rules, both aimed at a worksheet that substituted single
    words instead of translating the sentence:

    - In a **non-Latin-script** locale, any word of the English
      source still present in a value that is otherwise
      translated. Decisive there, and *only* there: `"Item ativo"`
      for "Active item" is correct Portuguese, so the same rule
      over `pt-BR` would flag every cognate and loanword.
    - In **any** locale, an English `-ing` welded onto a
      translated stem — `"Modifiering"`, `"編集ing"`. Precise
      because no target language forms a word that way; the
      `-s`/`-ed`/`-d` welds this same worksheet also produced
      (`"保存d profiles"`, `"Salvard"`) are *not* checked, because
      native words ending in those letters are everywhere ("und",
      "bord", "Feld") and the rule would drown in them. Those
      values are caught by the first rule wherever it applies.
    """
    source = _words(english)
    lowered = {word.lower() for word in source}
    found: list[str] = []
    value_words = _words(value)

    if locale in NON_LATIN_LOCALES and _is_partly_translated(
        locale, value
    ):
        found += [
            word
            for word in value_words
            if word.lower() in lowered
            and word.lower() not in GLOSSARY
            and (len(word) > 1 or word.lower() == "a")
        ]

    found += _welded_gerunds(source, value_words, lowered)
    return sorted(set(found))


def _is_partly_translated(locale: str, value: str) -> bool:
    """Whether `value` carries any character of its own script.

    An all-English value is *untranslated*, a different defect
    with a different fix, and legitimately correct for the handful
    of keys whose English is a bare product term ("Lua", "BSP").
    """
    return any(
        pattern.search(value)
        for name, pattern, locales in _SCRIPT_RES
        if locale in locales
    )


def _welded_gerunds(
    source: list[str], value_words: list[str], lowered: set[str]
) -> list[str]:
    """Tokens that took an English `-ing` from `source` onto a
    stem that is not the English one."""
    stems = {
        word[:-3].lower()
        for word in source
        if len(word) > 3 and word.lower().endswith("ing")
    }
    if not stems:
        return []
    return [
        word
        for word in value_words
        if len(word) > 3
        and word.lower().endswith("ing")
        and word.lower() not in lowered
        and word.lower() not in GLOSSARY
        and not any(
            word.lower().startswith(stem) for stem in stems
        )
    ]


# A pair is flagged at 5% of the keys they share, floored at 20.
# Sibling languages really do coincide on short UI labels —
# `es`/`pt-BR` sit at 11 identical values (1.4%) with the corpus
# clean — while a whole file pasted into the wrong locale lands
# near 45%. The floor keeps a small catalog from tripping on a
# handful of matches.
OVERLAP_RATIO = 0.05
OVERLAP_FLOOR = 20


def _nontrivial(value: str) -> bool:
    """Whether two locales sharing this value is worth counting.
    A one-word label ("Lua", "Monitor") coincides innocently;
    length also stands in for the word count CJK does not space."""
    return len(value) >= 12 or " " in value


# A translation reused for this many *distinct* English strings is
# a collapse, and any reuse at all is one when the value carries an
# interpolation specifier. Both thresholds were measured against
# the eight shipped locales: zero false positives, because the
# innocent collapses are near-synonyms sharing one target word
# ("Alignment"/"Orientation" → `Ausrichtung`, "Thickness"/"Width" →
# `Spessore`) and never reach five, while a specifier-bearing
# string is specific enough that two of them never coincide.
COLLAPSE_LIMIT = 5


def collapsed_translations(
    catalog: dict[str, str], english: dict[str, str]
) -> list[tuple[str, list[str]]]:
    """Values this locale reuses for unrelated English strings.

    Catches the defect class the other four cannot see: content
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
            and len({english[key] for key in keys}) >= 2
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
    names = sorted(name for name in catalogs if name != "en")
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
