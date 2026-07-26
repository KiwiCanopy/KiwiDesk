# Brief for the translator (KiwiDesk app UI, issue #95)

Working files: `missing_<locale>.json` in this directory, one per
locale — `de` (423 keys), `fr`, `es`, `it`, `pt-BR`, `ja`,
`zh-Hans`, `ko` (808 each).

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
3. Keep `\n` escapes, and any leading or trailing space, as in
   the source.
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

## German specifically

`de.json` already ships 385 translated keys. Read it before
starting: the 423 pending keys must match the voice and the
terminology already there (and its address register — the first
translator's choice stands, per *Tone & voice*). Terms already
settled in German should be reused, not re-coined.

Two keys are deliberately empty and need fresh translations
rather than their old ones: `shortcuts.advanced.title` and
`monitors.advanced.title`. Their English **meaning** changed
(they are now "Lua bindings" and "Monitor fingerprints", with
the word "Advanced" dropped), so the previous German was
retired on purpose.

## When a file is done

Hand it back — do not run any script yourself. The merge step is
`scripts/merge-keys <locale>`, which folds `"translation"` values
into `<locale>.json` without touching entries that already exist.
Partial files are fine: any key a locale omits falls back to
English per key, so a half-finished locale ships safely.
