# Brief for the translator (KiwiDesk app UI)

Ten locales ship complete at 810 keys each: `de`, `es`, `fr`, `it`,
`ja`, `ko`, `pt-BR`, `ru`, `zh-Hans`, `zh-Hant`. A round of work
starts by generating worksheets — `scripts/extract-keys <locale>`
writes `missing_<locale>.json` into **`locale-worksheets/`** at
the repo root (not this directory) with whatever that locale is
missing, and nothing when it is complete. Only flat
`{key: string}` catalogs live here; a worksheet's nested shape
breaks every reader of this directory, so `extract-keys --check`
rejects one that turns up.

**Read `docs/translating.md` first** — its *Translating well* and
*Tone & voice* sections are the actual guidance (plain register,
no marketing voice, informal address by default). This file is
only the mechanical contract.

## The contract

1. **Fill `"translation"` only.** Never edit a `"source"` value,
   never rename, add, or remove a key. The key list is generated
   from Swift call sites; a key that isn't in the code is dropped
   again on the next run.
2. **Preserve every placeholder exactly**: `%1$@`, `%2$@`,
   `%1$d`. Same set, same spelling. They are numbered precisely
   so you *can* move them — put them where the sentence needs
   them in your language, not where English has them.
3. **Keep `\n` escapes *inside* the string.** Leading and
   trailing whitespace is a different matter: `merge-keys` trims
   it, so it cannot survive and must never carry meaning. (It used
   to say otherwise. One English string ended in `\n` to separate
   a header from a list; the trim silently dropped it in all
   eleven locales and the header ran into the first bullet. The
   newline moved into the Swift instead — a structural separator
   is not copy.)
4. **Do not translate**: the product name *KiwiDesk*; code and
   config identifiers (`init.lua`, `gui.json`, `set_gap_global`,
   Lua function names); key names themselves.
5. **Apple's own feature names follow macOS, not English.** The
   `system_shortcut.*` keys are macOS features (Spotlight,
   Mission Control, Force Quit, App Switcher…). Use whatever
   macOS itself calls them in that language — look it up rather
   than translating the English literally. If macOS keeps the
   English name in that language, keep it too.
6. **Match the source's punctuation style.** A source without a
   final period stays without one; a source ending in `…` keeps
   it.
7. **Shorter is better, and in German it matters.** These are
   Settings labels in a fixed-width column, and the app has a
   minimum window width — a long label truncates rather than
   wraps. Where two renderings are both correct, take the
   shorter. The known-tight case is "Icon & name" →
   "Symbol & Name".

## Topping up an existing locale

Read the shipped `<locale>.json` before starting: new keys must
match the voice, the terminology, and the address register already
there — the first translator's choice stands, per *Tone & voice*.
Terms already settled in a language get reused, not re-coined.

## Five things the tooling will reject

`scripts/merge-keys` refuses to write a translation that trips the
content guards, and `scripts/extract-keys --check` blocks the whole
commit on one, so these are hard rules rather than advice. See
*Content guards* in `docs/translating.md` for the full account.

1. **A writing system the locale does not use** — Cyrillic in
   Japanese, a stray Han glyph in Russian. This one catches
   fat-finger paste errors that read as fluent text.
2. **English text tagged with the locale code** — `"Icon & name
   (ES)"`, `"Group adjacent…（JA）"`. Not a way to mark work in
   progress: leave `"translation"` empty instead, and the key
   re-surfaces on the next run.
3. **English words left inside a translated sentence** —
   `"追加 Window"`, `"編集ing init.lua directly"`. Checked in the
   non-Latin-script locales, where it is unambiguous.
4. **One filler reused for many keys.** If a string is hard —
   several placeholders, no obvious phrasing — leave it empty. A
   generic `"Option %1$@"` written across every interpolated key
   is worse than English, and is exactly what this check exists to
   catch.
5. **A whole file pasted into the wrong locale**, caught by
   comparing locales against each other.

Rule 3 has one exception worth knowing: terms that stay English by
design — the product name, `Lua`, `macOS`, Apple's feature names,
and every layout-mode name (`BSP`, `Grid`, `Stack`, `Track`,
`Monocle`, `Scrolling`, `Floating`) — live in `GLOSSARY` in
`scripts/localization_guards.py`. If a correct translation is
rejected because it keeps such a term, the term belongs in that
list; say so rather than working around it.

## When a file is done

Hand it back — do not run any script yourself. The merge step is
`scripts/merge-keys <locale>`, which folds `"translation"` values
into `<locale>.json` without touching entries that already exist.
Partial files are fine: any key a locale omits falls back to
English per key, so a half-finished locale ships safely.
