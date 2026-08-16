---
title: Translating KiwiDesk
description: The localization workflow — how to add or fix a translation.
---

# Translating KiwiDesk

KiwiDesk's GUI (Settings window, dashboard, the menu-bar quick
menu, tooltips, and the first-launch onboarding) is
localizable. This is a contributor guide for adding or fixing a
translation. It does not cover Lua/CLI-facing strings — those
stay English-only by design (they are code, not UI copy).

The **marketing website** (the landing page and, soon, the
`/learn/` guide) is localized with the *same* `extract-keys` /
`merge-keys` round-trip, just pointed at the site with a
`--site` flag — see [The marketing
site](#the-marketing-site) below. The rest of this page is about
the app.

> This page will be revisited when the wider docs pass (#63)
> lands; the workflow below is stable in the meantime.

## How it works, in one paragraph

Every user-facing string in `Sources/KiwiDesk` (and the handful
of shared strings in `Sources/KiwiDeskCore`, where `L` itself
lives) is looked up through `L("some.key", "The English
text")` — a free function in `KiwiDeskCore`
(`Sources/KiwiDeskCore/Localization/LocalizationManager.swift`).
**English is always the source of truth**, inlined right at the
call site, and a locale only needs to translate the keys it
wants: any key a locale file omits falls back to that call
site's English argument automatically (per-key fallback), so a
half-translated locale degrades gracefully to English rather
than showing blanks or crashing.

The GUI language pick itself (Settings ▸ General ▸ Language)
persists in app preferences (`UserDefaults`, key `"language"`),
not in `gui.json` — it's a scalar, side-effect-free preference,
never tiling/keybinding state, and never migrates config
ownership the way writing to `gui.json` would.

Some strings a user reads do not *originate* in the GUI: a
keybinding conflict is detected in `KiwiDeskCore`, and so is a
config-load problem, and so are the built-in layout presets.
Those are not left in English — Core returns the **structure**
(a `Conflict` naming a `SystemShortcut`, a `ConfigIssue.Kind`, a
preset's stable `name`) and the GUI turns it into a sentence, so
a translator sees ordinary keys (`system_shortcut.*`,
`keybinding.conflict.*`, `config_issues.*`, `presets.*`) with
nothing special about their plumbing.

That is a rule about *ownership*, not about which file can call
`L`: copy written in Core cannot be re-rendered when the user
switches language, and — the part that actually bit — a plain
English literal there never reaches `extract-keys`, so it never
becomes a key and no locale can translate it however complete.
Four config-issue messages and three preset summaries shipped
that way before #601.

**The `system_shortcut.*` keys do need one thing done
differently.** They are Apple's own feature names — Spotlight,
Mission Control, Force Quit, App Windows — and macOS already
ships a name for each in your language. Use *that* name, the one
a user would see in System Settings › Keyboard › Shortcuts, and
do not translate the English literally. A literal rendering
reads as a bug precisely because the user has seen Apple's
wording for the same thing everywhere else.

Otherwise there is nothing to do differently; the structure
matters only if you are adding such a string in Core, which
should name a case rather than write English prose.

## Key convention

Keys are dot-namespaced, lowercase, area-first, mirroring the
UI structure: `general.language.title`, `menu.quit`,
`shortcuts.section.focus`, `app_bar.color.hover`. When adding a
new localized string, follow the existing area prefix in the
file you're editing (`menu.*` for the quick menu, `general.*`
for the General tab, `shortcuts.*` for the Shortcuts tab, and
so on) — consistency here is what keeps the manifest
navigable as it grows past a few hundred keys.

## Interpolating a value into a sentence

Never build a sentence by concatenating a localized fragment
with a raw value (`L("x.prefix", "Move to ") + name`) — a
translation can't reorder pieces stitched together in Swift,
and many languages need to (a German "Move to Studio" reads
naturally as "Nach Studio verschieben": the destination moves
to the middle of the sentence). Use the interpolating overload
instead:

```swift
L("monitor_chip.move_to", "Move to %1$@", display.name)
```

The template uses **positional** specifiers — `%1$@` for a
string, `%1$d` for an integer, `%2$@` for a second argument,
and so on — never bare `%@`/`%d`. Positional specifiers are
what let a translation place `%1$@` wherever the target
language's grammar wants it, independent of where it sits in
the English source. A German translation of the key above is
free to write `"Nach %1$@ verschieben"` — the placeholder moves,
the argument doesn't change.

## Help texts: bold markers and line breaks

Keys ending in `.help` hold the contextual-help popover copy
(#94). Some of these values contain inline Markdown bold and
literal `\n` line breaks — the pattern is one line per option,
with the option's name bold:

```json
"layout_params.overflow.stack.help":
  "**Cascade overflow** — Keeps as many windows fully tiled
   as fit…\n**Cascade all** — Cascades the whole stack…"
```

Preserve both in a translation: keep each `**…**` pair
balanced around the translated option name (an unbalanced pair
renders literal asterisks to users), keep the option names
matching the field's actual option labels (the sibling keys
without `.help`), and keep the `\n` between option lines. The
sentence around them is yours to reshape as the language
needs.

## Where the files live

```
Sources/KiwiDeskCore/Resources/Locales/
    en.json      # generated manifest — the canonical key list
    de.json      # a shipped locale (translated keys only)
    <code>.json  # one file per shipped language

locale-worksheets/            # at the repo root, gitignored
    missing_<code>.json       # the app round-trip file
    site/missing_<code>.json  # the same, under --site
```

**`Resources/Locales/*.json` is translation-owned and
generated: edit it via the scripts below, never by hand, and
AI agents must not hand-edit it either** (see `AGENTS.md` §5).
`en.json` in particular is fully regenerated by
`scripts/extract-keys` on every run — it is not a place to
type a translation, and it is not something the running app
ever reads (see "Why `en.json` is generated" below).

The locale directory lives inside `KiwiDeskCore` (not the
`KiwiDesk` executable target) because `LocalizationManager`
lives there too — it is shared by both the SwiftUI Settings
window and the AppKit quick menu, so its resources have to be
reachable from that target's `Bundle.module`.

A locale file is discovered automatically the moment it exists
under `Resources/Locales/<code>.json` (any code other than
`en`) and the project is rebuilt — `Package.swift` copies the
whole directory (`.copy("Resources/Locales")`), so nothing needs
registering for the app to *use* it. It then appears in
Settings ▸ General ▸ Language, listed by its own native name
(e.g. "Deutsch", not "German").

The **content guards** are the one exception: they key their
policy by locale, so a new code has to be added to `_STUB_TAGS`
in `scripts/localization_guards.py`, **and** declare its script —
`SCRIPTS` for a non-Latin language, `LATIN_LOCALES` otherwise.
Both are required, and the script declaration is not optional the
way it once was: the feature-name guard holds Latin-script locales
to keeping "App Bar" verbatim, so a non-Latin locale that forgot
its `SCRIPTS` row would be read as Latin and *demanded* to carry
an ASCII phrase inside its own sentences. Forget either and a
guard goes quiet — or worse, loudly wrong — for that locale, which
is why `extract-keys --check` refuses an unregistered locale
outright and says where to add it; `LocalizationRegistryTests`
pins the same relation.

These language names are **endonyms** — each language shown in its
own name, the same regardless of the active UI language (so the
German UI still shows "English", "Français", "日本語", not
"Englisch"). This is intentional: a user stranded in a language
they cannot read must still recognise their own in the list, the
same convention macOS System Settings uses. The names are derived
automatically from macOS (`Locale.localizedString(forIdentifier:)`)
— they are **not** translation keys, never appear in the locale
JSON files, and must not be added there. There is nothing to
translate for language names.

## Adding a new language

1. Pick the locale's ISO code (e.g. `fr`, `ja`, `pt-BR`).
2. Run the extractor against that code:

   ```
   scripts/extract-keys fr
   ```

   This does two things: it rebuilds `en.json` from every
   `L(key, english[, args...])` call site in `Sources/KiwiDesk`
   and `Sources/KiwiDeskCore` (the canonical key list), then
   writes `locale-worksheets/missing_fr.json` with every key
   `fr.json` doesn't have yet (all of them, the first time).

   Worksheets live in `locale-worksheets/` at the repo root —
   never beside the catalogs in `Resources/Locales`. A worksheet
   is a *nested* `{key: {source, translation}}` map, and
   everything that reads the catalog directory expects a flat
   one; a worksheet sitting there is read as a broken catalog or
   as a language called `missing_fr`, and it would be copied
   into the app bundle. The directory is gitignored, and
   `scripts/extract-keys --check` fails if a worksheet turns up
   among the catalogs.
3. Fill in the translations. `missing_fr.json` maps each pending
   key to a `source`/`translation` pair:

   ```json
   {
     "monitor_chip.move_to": {
       "source": "Move to %1$@",
       "translation": ""
     }
   }
   ```

   `source` is the English text to translate FROM — read it for
   meaning, not as a template to mirror word for word (see
   "Translating well" below) — and is not yours to edit. Fill in
   `"translation"` with the target-language text; leave the key
   itself untouched. A template with `%1$@`/`%1$d` placeholders
   keeps them, repositioned wherever your language's grammar
   wants them (see "Interpolating a value into a sentence"
   above). Leave `"translation"` empty (`""`) for any key you
   want to skip for now — it will simply reappear next time you
   run `extract-keys fr`.

   > **Re-running `extract-keys fr` mid-translation is safe.**
   > It rebuilds the worksheet, but reads the one already there
   > first and carries every filled-in `"translation"` across —
   > so picking up English that landed while you were working
   > costs you nothing. It says how many it carried.
   >
   > One kind of entry it cannot carry: one whose English has
   > **changed** since you started. Your text translates a
   > sentence the app no longer shows, so that slot is emptied
   > and refilled with the new `"source"`, and the translation
   > you had is printed to the terminal so you can copy it back
   > if it still fits. `merge-keys` would refuse the same entry
   > for the same reason — this just tells you a round earlier.
   > A worksheet that has been damaged into invalid JSON is
   > refused outright rather than overwritten; fix or move it,
   > then run again.
4. Fold the finished translations back in:

   ```
   scripts/merge-keys fr
   ```

   This reads every entry with a non-empty `"translation"`,
   writes it into the flat `fr.json` (creating the file if it
   didn't exist), and deletes the temp file. Entries you left
   empty are skipped — not merged as blanks — and printed so you
   know what's still pending.

   An entry is **also skipped when its `"source"` no longer
   matches that key's current English** in `en.json` — the
   English changed in code while the worksheet was out, so the
   translation you have is of the old text. Same for an entry
   with no usable `"source"`, or a key that has left `en.json`
   entirely: nothing to verify against, so nothing is merged.
   Those keys are listed on stderr **with the discarded text**,
   and the summary line reports how many were dropped. This is
   the guard that keeps a worksheet from silently resurrecting
   exactly what `scripts/drop-key` retired. `--site` behaves
   identically against the site's own `en.json`.

   Two caveats worth knowing before relying on it:

   - It compares **text**, not meaning, so a typo fix in the
     English also invalidates a finished entry — stricter than
     the convention below, deliberately, since a script cannot
     tell a typo from a rewrite.
   - Re-running `scripts/extract-keys fr` gets a skipped key
     back **only if `fr.json` does not already have it**, since
     that is when a key is re-minted. Every worksheet
     `extract-keys` itself produces satisfies that; a
     hand-written entry for an already-translated key does not,
     and its text is gone once merge-keys has reported it. To
     revise an existing translation, edit `fr.json` directly
     (see below) rather than hand-writing a worksheet.
5. Rebuild (`swift build`) and open Settings ▸ General ▸
   Language — the new locale should appear, listed by its
   native name, with every translated string live and every
   untranslated one still readable in English.

## Fixing or completing an existing translation

Same round-trip, scoped to whatever the target locale is still
missing — running `extract-keys <locale>` again after new
English strings have been added elsewhere in the code only
pulls in the delta:

```
scripts/extract-keys de      # writes locale-worksheets/
                              # missing_de.json with only what
                              # de.json doesn't cover yet
# fill in each entry's "translation" field in the worksheet
scripts/merge-keys de        # folds the non-empty ones into de.json
```

The delta is computed against `de.json`, so the worksheet only
ever lists what the catalog still lacks. Running that first line
on top of a part-filled worksheet is fine — anything you have
already typed is carried over (see step 3 above).

To fix a wrong, awkward, or overly literal existing
translation, edit the value directly in `<locale>.json` — that
is the one case that doesn't go through
`missing_<locale>.json` (the round-trip file only ever lists
what's *absent*, never text you're revising). Small, targeted
hand-edits to an already-shipped `<locale>.json` are fine and
welcome; do not touch `en.json` (see below).

## The marketing site

The website under `site/` (the landing page, and the `/learn/`
guide once it's externalized) keeps its strings in flat
`{key: string}` manifests under **`site/src/i18n/`** —
`en.json`, `de.json`, one file per language — exactly the shape
the app uses, and the Astro components read them as `t.<key>`.

The one difference from the app: **the site's `en.json` is the
source of truth, authored by hand**, not generated from code.
There is no Swift to scan — the English copy lives in `en.json`
itself, and the components reference it by key. So the tooling
takes a `--site` flag that points it at `site/src/i18n/` and,
for `extract-keys`, loads `en.json` directly as the key list
instead of scanning Swift (and never rewrites it — re-emitting
it sorted would wreck its deliberate grouping).

Everything else is the identical round-trip:

```
# add a new language (e.g. French) — writes
# locale-worksheets/site/missing_fr.json with all keys to fill:
scripts/extract-keys --site fr

# top up an existing one after new English keys were added to
# en.json — writes only the delta de.json is still missing:
scripts/extract-keys --site de

# ...fill each entry's "translation" in the worksheet
# (locale-worksheets/site/missing_<locale>.json)...

# fold the finished translations into <locale>.json:
scripts/merge-keys --site de
```

The other maintenance verbs take `--site` too:

- `scripts/extract-keys --site --check` — validates every
  shipped `site/src/i18n/<locale>.json` decodes as a flat
  `{string: string}` map, runs every *Content guard* below except
  the English-residue heuristic over its values, and warns on
  orphan keys (present in a locale, absent from `en.json`). It
  does **not** check
  `en.json` freshness — there's no code to derive it from; it
  *is* the source — and the residue heuristic is the one skipped
  because site copy legitimately keeps third-party
  product names and inline HTML. The `Site` workflow runs this on
  every PR that touches `site/**` or `docs/**`.
- `scripts/extract-keys --site --prune` — drops orphan keys
  from the site locale files (without rewriting the hand-authored
  `en.json`).
- `scripts/rename-key --site <old> <new>` — renames a key across
  every `site/src/i18n/*.json`, preserving each translation. As
  with the app, update the `t.<old>` use sites in the Astro
  components/pages yourself afterward.
- `scripts/drop-key --site <key> [...]` — drops stale
  translations of a meaning-changed site string from every
  `site/src/i18n/<locale>.json`, leaving the hand-authored
  `en.json` untouched.

To add a new English string to the site: add the key to
`site/src/i18n/en.json`, reference it as `t.<key>` in the
component, then run `scripts/extract-keys --site <locale>` for
each language so it surfaces as missing to translate.

### Adding a whole new site language

Routes are one file per locale, but a dozen places inside the
components **hand-enumerate** the locale set, and a language added
everywhere else still ships with those omitting it — a language
switcher missing an option, a stored-locale redirect that cannot
reach the new path, an `og:locale` naming the wrong one, and a 404
that leaves the new language out of its own list.

There is no single list to update, so find them mechanically:

```bash
grep -rn '"ja"\|/ja/\|ja_JP\|(de|ja)' site/src
```

Every hit is a decision to extend. The shapes to expect are locale
→ path maps (`{ en: "/", de: "/de/", ja: "/ja/" }`), display-name
and `og:locale` maps, `en|de|ja` predicates and route regexes, the
`Lang` union in `site/src/i18n/legal.ts`, the language-switcher
markup in `Landing.astro` and `Guide.astro`, and the `alts` array
in `site/src/pages/404.astro` — that last one because static
hosting serves one 404 for every unmatched path, so it cannot pick
a locale from the URL and renders them all together instead.

### Key naming keeps the file structured

The site manifests (`en.json`, `de.json`) are stored **sorted by
key** — the round-trip tooling (`rename-key --site`) rewrites
them that way, and a flat sorted list stays diffable and
merge-friendly. That is fine *because* the keys carry the
structure themselves: every key is prefixed by the area it
belongs to (`nav_*`, `hero_*`, `feat_*`, `layout_*`, `footer_*`
for the landing; `guide_*` for the guide page, sub-grouped like
`guide_faq_*`, `guide_scenario_*`, `guide_tour_*`). Because the
files sort by key, a consistent prefix makes every group cluster
together on its own automatically. **When you add a string,
follow the existing area prefix** rather than inventing a bare
name — that is what keeps the manifest navigable as it grows,
and it means the sorted order and the logical grouping are the
same thing. A new area gets a new prefix; don't scatter related
strings under unrelated names.

## Translating well

The `source` field in `missing_<locale>.json` is a reference
for *meaning*, not a structural template — read the key's name
and, where possible, open the app and see where the string
actually appears (a menu item, a tooltip, a section title) before
translating it. A translation that's technically accurate but
built by mirroring the English sentence word for word often
reads as stiff or foreign to a native speaker, even when every
individual word is "correct." We'd love it if translations read
the way a native speaker would naturally phrase that exact spot
in the UI — matching the language's tone (see *Tone & voice*
below) — rather than a literal transcription of the English.

Some of the seed translations shipped today (`de.json`'s
initial entries, and whatever a first pass at a new locale
produces) may well be a little rough or too literal in places —
that's expected for a first pass, not a problem. Smoothing
those out over time is exactly what "fixing an existing
translation" above is for, and improvements toward more natural
phrasing are always welcome.

### One concept, one word

The failure that reads worst is not a stiff sentence — it is your
language's two perfectly good words for the same idea, used on
two pages. The user learns the word once and does not recognise
it on the next screen, and search finds one surface and not the
other. It shows up between *adjacent* surfaces most of the time:
a tab bar and the help text under it, a card title and the menu
item that opens it.

So before you settle on a word for an ordinary noun — layout,
gap, profile, shortcut, preset — grep your own catalog for the
candidates and take the one already carrying the concept. Two
rules on top of that count, both in the [feature name
policy](localization-naming.md) ▸ Family C, which is where this
is decided:

- A word that already names **another** KiwiDesk thing in your
  file loses, however common it is. That is the worst version of
  this defect: the label is not merely inconsistent, it is true
  about the wrong feature.
- The rival is usually still correct *somewhere* in your file, so
  never search-and-replace. Change the keys that name the
  concept, and leave the ones where the word means something
  else.

Nothing checks any of this — it cannot be checked, for reasons
that page argues — so it is yours to hold.

## Tone & voice

Keep translations concise and match the register of the
English source (plain, direct, no marketing voice). For
locales with a formal/informal address distinction (German
"Sie" vs. "du", French "vous" vs. "tu", etc.), the suggested
default is the informal register — KiwiDesk is a personal
developer tool, not enterprise software — but the first
translator to ship a locale has the final call for that
language, and later translators should follow their
precedent rather than re-litigating it string by string.

## Why `en.json` is generated, not hand-edited

English lives at the call site (`L("key", "English text")`) so
a developer reading the Swift source always sees the real
English copy, never a bare key that requires a lookup to
understand. `en.json` is a **build-time translator manifest**,
not a runtime resource — it exists purely so the extractor has
a canonical key list to diff other locales against, and so a
Python (or any external) tool can enumerate every key without
parsing Swift; the running app never loads it (there is no
`en` entry in the bundled locale list — see `LocaleCatalog`'s
`!= "en"` filter, which is intentional). Never add or edit a
key only in `en.json`; it will be silently overwritten by the
next `extract-keys` run. If a string's English text needs to
change, edit it at the `L(...)` call site in Swift and re-run
`extract-keys`.

### Drift guard

Because the English text lives at every call site rather than
in one place, the same key could in principle be called with
two different English strings by mistake. `extract-keys` fails
loudly instead of silently picking whichever occurrence it
scanned last: it prints the offending key and every conflicting
string it found, with a non-zero exit code, and refuses to
write `en.json` until every call site for a key agrees. This
also runs as a Swift test (`LocalizationDriftGuardTests`), so a
regression fails `swift test` / CI even if nobody happens to
run the script by hand.

### Freshness check (`--check`)

`scripts/extract-keys --check` re-scans both source trees and
compares the result to the committed `en.json` **without
writing anything**. It HARD-FAILS (non-zero exit) on:

- **drift** — the same key called with two different English
  strings;
- a **stale `en.json`** — a key was added, removed, or had its
  English text edited since the last `extract-keys` run;
- a **malformed locale file** — any shipped `<locale>.json`
  that doesn't decode as a flat `{string: string}` map (bad
  JSON, a nested object, a non-string value). This one is a
  hard-fail rather than a warning on purpose: `LocaleCatalog`
  soft-fails a broken file to an empty dictionary at runtime, so
  a malformed `de.json` doesn't crash anything — it just makes
  German silently revert to all-English. That's a feature dying
  quietly, and quiet is exactly what this check exists to
  prevent.
- **broken content** in any translated value — the checks
  described in *Content guards* below.

It only *warns* (prints, does not fail) about **orphan keys** —
see *Maintaining the key set* below.

`scripts/lint.sh` runs `--check` unconditionally as part of the
verify gate, so both CI (which always runs `lint.sh`) and the
local pre-commit hook enforce it. The pre-commit hook
additionally fires on locale-only changes: staging just
`Resources/Locales/de.json` (no Swift file) still runs
`extract-keys --check` before the commit completes, so a
translator gets instant local feedback instead of waiting for
CI to reject a broken or stale file.

### Content guards

Everything above reads *keys*. Nothing there ever looks at a
translated value, so a bad worksheet used to land silently and
render live — a reviewer skimming a language they do not read
sees plausible text. Nine checks read the copy itself
(`scripts/localization_guards.py`), each a hard failure. Six are
exact contracts. `english_residue` is a heuristic scoped to
non-Latin locales; the two feature-name checks are scoped by what
the catalogs ship rather than by script:

- **Wrong writing system.** Every locale value must use only the
  scripts that locale actually writes in: Cyrillic belongs to
  `ru`, kana to `ja`, Han to `ja`/`zh-Hans`/`zh-Hant`, Hangul to
  `ko`, and Greek, Arabic and Hebrew to none of them. Latin is
  deliberately *not* in the table — every locale uses it for
  `KiwiDesk`, URLs and `%1$@`, so its presence proves nothing.
  Note that Han cannot separate Japanese from Chinese, while kana
  can; that is why the table maps each script to the locales
  allowed to use it rather than giving each locale one expected
  script. `en.json` is checked too: it is generated, so a stray
  non-Latin glyph there is a pasted literal in Swift.
- **Tagged stubs.** Untranslated English carrying its own locale
  code — `"Icon & name (ES)"`, `"Testo Global colors (IT)"`, and
  with full-width parens `"Group adjacent…（JA）"`. The full-width
  pair matters: an ASCII-only regex once reported a 45%-complete
  Japanese file as 98% complete. A value naming a *different*
  language (`"Alemán (DE)"` in Spanish) is legitimate and passes.
- **Interpolation-specifier drift.** The `%1$@`/`%1$d` set must
  match the English as a multiset — the one check here that
  guards a *runtime* path rather than the copy, since these values
  reach `String(format:)`. Order is deliberately not checked: the
  numbering exists so a translation can reorder the arguments, and
  many languages must. A literal `%%` is ignored, because it
  carries no argument and several locales legitimately write
  `"%1$d%%"` where the English spells out "percent".
- **A withheld argument moved off the end.** The exception to the
  freedom above, and the tooling knows which keys it applies to,
  so you do not have to. A handful of frames end on a placeholder
  the app fills only *sometimes* — the Scrolling preview's caption
  names its `+` mark, and says nothing at all about it when the
  row puts the mark off the frame. The app drops the space in
  front of such a clause along with the clause, which it can only
  do at the end of the sentence; anywhere else, the empty case
  leaves a hole and any punctuation you wrapped it in is stranded.
  Keep that placeholder last. Every other placeholder in every
  other key stays free to move.
- **A collapsed translation** — one filler standing in for many
  unrelated keys. This is the check that caught the worst defect
  in the corpus: `it.json` and `pt-BR.json` had *every*
  interpolated string replaced with a bare `"Opzione %1$@"` /
  `"Opção %1$@"`, 48 keys each. Every other check passes such a
  value — it is fluent, in the right script, free of English, with
  the right placeholders. The bar is five distinct English strings
  on one value, or three when the value carries a specifier.
  Near-synonyms sharing one target word are normal and pass
  (`de` "Standard" covers "default"/"Default"/"standard").
- **English left in a translated sentence.** The shape a
  word-swapping machine translation produces: `"追加 Window"` for
  "Add Window", `"保存 as New Profile…"`. A detector requiring
  several source words in a row misses these entirely, and ~90 of
  them once survived two review passes. **Non-Latin-script
  locales only** — see the gap below.
- **A dropped feature name.** (Both families, and the rule
  that sorts a new name into one: [Feature name
  policy](localization-naming.md).) The GUI shows "App Bar" and
  "Space Bar" untranslated, so a translation that renames them
  ("Die App-Leiste", "Barra delle app") describes something the
  interface does not call that. Keep the name verbatim and
  translate around it: "Mostra la App Bar", "Couleurs de la
  Space Bar". Capitalization is yours ("App bar" is fine), and so
  is compounding — German's "Space-Bar-Farben" keeps the name,
  because separators are flattened before the comparison.
  **One mention is enough.** The check asks whether the name
  survives, never how often: if the English names a bar twice and
  your sentence reads better naming it once, that passes. Keep
  each name the English carries, though — a string contrasting
  the two bars needs both, or the contrast collapses.
  **Every locale, whatever its script** — the interface shows
  those two names in Latin in all eleven catalogs, so this is not
  the mirror of the rule above. In Japanese and Korean adapting
  them is actively worse: スペースバー and 스페이스바 are the
  everyday words for the *spacebar key*, and neither script has
  capitals to mark a name, so the feature becomes
  indistinguishable from the key. The list is `PRODUCT_NAMES`;
  adding to it is a product decision about what the GUI leaves in
  English, not a way to quiet a hit.
- **Layout mode names follow your picker — and only the CJK
  locales translate them.** Floating, Grid, Monocle, Scrolling,
  Stack and Track are values the user types verbatim
  (`set_mode(1, "stack")`), so the seven Latin-script locales keep
  them English and `LocalizationModeNamePolicyTests` enforces
  that. The three CJK locales render them natively: `ja` uses モノクル, `zh-Hans` 单窗,
  `ko` 트랙 — while the seven Latin-script locales keep them
  English, so the picker matches the value you type into Lua or
  the CLI (`set_mode(1, "stack")`). The one rule is **match your
  own picker**: if `layout.monocle.name` in your file says
  モノクル, the prose around it says モノクル too, never
  "Monocle".
- **Cross-language overlap.** Two locales of *different*
  languages sharing too many byte-identical values — the shape
  that caught ~360 entries of French sitting in `it.json`. The
  threshold is 5% of the keys they share, floored at 20: sibling
  languages genuinely coincide on short labels (`es` and `pt-BR`
  sit at 11 with the corpus clean), while a whole file pasted
  into the wrong locale lands near 45%. Pairs of the same base
  language are skipped — `zh-Hans` and `zh-Hant` are one language
  in two scripts and agree on a great deal legitimately.

There is **no baseline or exemption file**. The corpus is clean,
so any hit is a real defect. What the guards do carry is a
**glossary** — the terms that stay English in every locale
(`KiwiDesk`, `Lua`, `macOS`, Apple's `Mission Control` and
`Bundle identifier`, and every layout-mode name, because
`layout.<mode>.name` ships each one untranslated). Interpolation
specifiers, dotted identifiers like `init.lua`, and a key name
following a modifier glyph (`⌘ Command`) are stripped before any
word is judged. If you add a term that must stay English, add it
to `GLOSSARY` in the same change set — the guard will tell you, by
rejecting an otherwise-correct translation.

`scripts/merge-keys` runs the first three of these per worksheet
entry, so a bad translation is **skipped rather than written**.
The clean entries in the same worksheet still merge, and each
skipped one is echoed to stderr with the reason — the worksheet
is deleted either way, so that transcript is the only copy of the
discarded text. Re-run `scripts/extract-keys <locale>` to get the
skipped keys back with the current English.

**Two scopes, stated plainly rather than papered over.**

The residue check runs only on **non-Latin-script locales** (`ja`,
`ko`, `zh-Hans`, `zh-Hant`, `ru`). In a Latin-script locale a
retained English word is indistinguishable from a cognate or a
loanword — `"Item ativo"`, `"Mein Setup"`, `"Limite del track"`
are all correct — so the rule would flag dozens of good
translations. Latin locales are covered by the other five checks;
word-swap residue there is caught by review, not by the gate.

An earlier version of this rule kept one sub-rule that ran
everywhere: an English `-ing` welded onto a translated stem
(`"Modifiering"`), on the claim that no target language forms a
word that way. German falsifies that outright — `fing`, `ging`,
`Ring`, and the whole `-ling` class (`Frühling`, `Lehrling`) — and
this repo's own site copy contains `fing`. Scoping it to non-Latin
locales did not rescue it either: a weld there has a *non-Latin*
stem (`"編集ing"`), so tokenizing leaves a bare suffix with
nothing to match. It is gone. The values it aimed at still fail —
`"編集ing init.lua directly."` on `directly` — and a bare weld
with no English beside it is simply not caught.

The residue check also runs on the **app catalogs only**, not the
marketing site's (`--site`). Site copy is prose carrying
third-party product names (`Homebrew`, `SketchyBar`,
`JankyBorders`, `Ko-fi`) and embedded HTML, where a retained
English token is normal; the app's glossary has no business
listing the site's vocabulary. The other five checks run on both.

All of this is backed by Swift tests —
`LocalizationContentGuardTests` (the exact per-value contracts),
`LocalizationResidueGuardTests`, `LocalizationOverlapGuardTests`,
`LocalizationCollapseGuardTests` and
`MergeKeysContentGuardTests` — which exercise the predicates
against strings the tests write themselves, never the shipped
catalogs. `LocalizationRegistryTests` is the one deliberate
exception: it walks the shipped files to assert every one of them
is registered in the guards' locale tables, because a locale
missing from those tables loses two checks *silently*, and that
relation has no meaning against invented locales. Asserting against the real corpus would tie the guard's
coverage to the corpus staying dirty: each assertion would pass
only while a bug was live and fail the moment it was fixed.

## Maintaining the key set (for maintainers)

A key's life cycle spans five operations. Four are built on
the code-derived key set `extract-keys` already scans;
`drop-key` deliberately isn't — it validates against the
shipped translation files themselves, since its job is pruning
their stale values, not deriving keys:

- **Add or refresh.** Add a new `L(key, english[, args...])`
  call site (or edit an existing one's English text), then run
  `scripts/extract-keys` and commit the updated `en.json`. This
  is the everyday path covered above.
- **Check.** `scripts/extract-keys --check` is the read-only
  gate described above: hard-fails on drift, a stale `en.json`,
  or a malformed locale file; *warns* — printing the locale
  file and the orphaned key(s), without failing — when a
  shipped `<locale>.json` still has a key no code call site
  defines anymore. An orphan is cruft, not a correctness bug
  (the app just never looks it up), so it must never block an
  otherwise-clean translator PR; a maintainer decides when to
  clean it up.
- **Prune orphans.** `scripts/extract-keys --prune` removes
  every orphan key from every shipped `<locale>.json` (and
  rewrites `en.json` as usual), printing what it removed per
  locale. Run this once a key's removal has actually landed and
  you're ready to drop the dead translations.
- **Rename a key.** `scripts/rename-key <old_key> <new_key>`
  renames a key across `en.json` and every shipped
  `<locale>.json`, **preserving each file's existing value** —
  translations survive the rename instead of being force-emptied
  and re-requested. It refuses to run if `<old_key>` is absent
  everywhere or `<new_key>` already exists (so it can't silently
  clobber a real translation), and only touches locale files that
  actually had the old key. It edits JSON only — update the
  `L("<old_key>", ...)` call site(s) in Swift yourself, then
  `scripts/extract-keys --check` should pass again.
- **Drop stale translations.** `scripts/drop-key <key>
  [<key> ...]` removes the key(s) from every shipped
  `<locale>.json` — never from `en.json`, which is generated.
  Use it in the same change set as a **meaning-changing**
  English edit (see below): the dropped key falls back to the
  new English at runtime and reappears on every locale's
  to-translate list, so the pipeline itself tracks the debt —
  no side notes or issue comments needed. It fails without
  touching anything if a key exists in no translation (typo
  guard). `--site` targets the site manifests instead.
- **Retire one locale's bad translation.**
  `scripts/drop-key --locale <locale> [--locale <locale>] <key>…`
  narrows the drop to the named locales. This is the *other*
  reason a translation gets retired: the English is fine and the
  **translation** is defective — which is exactly what the
  content guards report, per locale. Dropping every locale's copy
  would discard good translations of the same key, so the fix
  path has to be per locale too. The typo guard still applies
  inside the narrowed scope: a key present elsewhere but not in
  the named locales fails rather than silently dropping nothing.

**Rename vs. drop vs. deprecate — pick based on whether the
*meaning* changed, and where it changed.** If a key is just
getting a tidier name for the exact same English text and the
exact same UI spot, that's a rename: use `scripts/rename-key`
so every existing translation carries over untouched. If the
string's *meaning* changed but the key rightly stays (the same
field, re-explained — the common case), run `scripts/drop-key`
on it in the same change set: a stale translation is
fluent-but-wrong, and correct-but-English beats that until the
retranslation lands. Purely cosmetic English edits (typo,
punctuation, capitalization) keep translations — don't churn
translators for them. And if the call site itself is going
away or getting a new identity, delete it in code and let the
new key surface as missing the normal way. Never reuse
`rename-key` for a meaning change — it would silently carry a
translation of the *old* meaning forward under a name that no
longer matches it, and nothing would flag that for review.

## Extraction limitations

`scripts/extract-keys` is a regex-based scanner tuned to this
repo's `.swift-format` house style — it recognizes `L(` call
sites whose first two arguments (key and English template) are
string literals (or several literals joined by `+`, including
Swift's triple-quoted `"""..."""` multi-line strings), across
any number of lines; any trailing interpolation arguments after
the English template are read as part of the call but never
inspected. It does **not** evaluate arbitrary Swift expressions:
a key or English string built any other way (string
interpolation, computed values, anything not a literal or
literal concatenation) will not be picked up. Keep call sites
written in that literal-concatenation style and the extractor
keeps working; anything more dynamic needs a manual `en.json`
review after the fact (and the change should be flagged in
review).

## Review & CI

Translations land like any other change: branch, commit, and
open a PR through the normal review flow (AGENTS.md §3).
`extract-keys --check` is enforced at two points, both running
the exact same checks:

- **Locally, at commit time** — `scripts/pre-commit` (installed
  via `scripts/install-hooks.sh`) runs it whenever a Swift file
  or a `Resources/Locales/*.json` file is staged, so a broken or
  stale locale file is caught before the commit even completes.
- **In CI** — `scripts/lint.sh` (which `--check` is part of)
  runs on every push and PR.

Both enforce the same policy: drift, a stale `en.json`, or a
malformed locale file hard-fails; an orphan key only warns (see
*Maintaining the key set* above for the reasoning and the
cleanup path).
