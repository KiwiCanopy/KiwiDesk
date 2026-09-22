---
title: Translating KiwiDesk
description: The localization workflow — how to add or fix a translation.
---

# Translating KiwiDesk

KiwiDesk's GUI — the Settings window, the dashboard, the menu-bar
quick menu, tooltips and the first-launch onboarding — is
localizable. This page is the contributor workflow for adding or
fixing a translation. Lua- and CLI-facing strings stay
English-only and are not covered.

The **marketing website** (the landing page and, soon, the
`/learn/` guide) takes the same `extract-keys` / `merge-keys`
round-trip with a `--site` flag — see [The marketing
site](#the-marketing-site). The rest of this page is about the
app.

## How it works, in one paragraph

Every user-facing string in `Sources/KiwiDesk`, and the shared
strings in `Sources/KiwiDeskCore`, is looked up through
`L("some.key", "The English text")` — a free function in
`KiwiDeskCore`
(`Sources/KiwiDeskCore/Localization/LocalizationManager.swift`).
**English is the source of truth**, inlined at the call site. A
locale translates only the keys it wants: any key a locale file
omits falls back to that call site's English argument (per-key
fallback), so a half-translated locale shows English rather than
blanks.

The GUI language pick (Settings ▸ General ▸ Language) persists in
app preferences (`UserDefaults`, key `"language"`), never in
`gui.json`.

Some strings a user reads originate in `KiwiDeskCore` — a
keybinding conflict, a config-load problem, the built-in layout
presets. Core returns the **structure** (a `Conflict` naming a
`SystemShortcut`, a `ConfigIssue.Kind`, a preset's stable
`name`) and the GUI renders the sentence, so a translator sees
ordinary keys (`system_shortcut.*`, `keybinding.conflict.*`,
`config_issues.*`, `presets.*`). If you add such a string in
Core, name a case rather than writing English prose — a
hardcoded English literal there, one outside `L(...)`, never
reaches `extract-keys`, so no locale can translate it.
`.claude/rules/localization.md` ▸ *Core names, the GUI narrates*
carries the argument (#96, #601).

**The `system_shortcut.*` keys are Apple's own feature names** —
Spotlight, Mission Control, Force Quit, App Windows — and macOS
already ships a name for each in your language. Use the name a
user sees in System Settings › Keyboard › Shortcuts, not a
literal translation of the English.

## Key convention

Keys are dot-namespaced, lowercase and area-first, mirroring the
UI structure: `general.language.title`, `menu.quit`,
`shortcuts.section.focus`, `app_bar.color.hover`. A new string
follows the existing area prefix of the file it lands in
(`menu.*` for the quick menu, `general.*` for the General tab,
`shortcuts.*` for the Shortcuts tab, and so on).

## Interpolating a value into a sentence

Never build a sentence by concatenating a localized fragment with
a raw value (`L("x.prefix", "Move to ") + name`): a translation
cannot reorder pieces stitched together in Swift, and many
languages need to. Use the interpolating overload:

```swift
L("monitor_chip.move_to", "Move to %1$@", display.name)
```

The template uses **positional** specifiers — `%1$@` for a
string, `%1$d` for an integer, `%2$@` for a second argument, and
so on — never bare `%@`/`%d`. A translation may place `%1$@`
wherever its grammar wants it: German writes
`"Nach %1$@ verschieben"`, and the argument does not change.

**What goes in the slot must not have to AGREE with the
sentence.** A name or a number never does. A word that would —
an adjective, a participle, a noun in a case the frame sets —
takes a key of its own per resulting sentence and is never shared
between frames. If you are handed a key whose whole value is a
bare adjective or participle, that is this defect, not a
translation problem: leave it empty and report it.
`.claude/rules/localization.md` carries the argument and #1110
the worked case.

## Help texts: bold markers and line breaks

Keys ending in `.help` hold the contextual-help popover copy
(#94). Some values contain inline Markdown bold and literal `\n`
line breaks — one line per option, with the option's name bold:

```json
"layout_params.overflow.stack.help":
  "**Cascade overflow** — Keeps as many windows fully tiled
   as fit…\n**Cascade all** — Cascades the whole stack…"
```

Preserve both in a translation: keep each `**…**` pair balanced
around the translated option name (an unbalanced pair renders
literal asterisks), keep the option names matching the field's
option labels (the sibling keys without `.help`), and keep the
`\n` between option lines. The sentence around them is yours to
reshape.

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

**`Resources/Locales/*.json` is translation-owned and generated:
edit it via the scripts below, never by hand, and AI agents must
not hand-edit it either** (see `AGENTS.md` §5). `en.json` is
regenerated wholesale by `scripts/extract-keys` on every run and
is not a place to type a translation (see [Why `en.json` is
generated](#why-enjson-is-generated-not-hand-edited)).

The locale directory sits in `KiwiDeskCore`, not the `KiwiDesk`
executable target, because `LocalizationManager` lives there —
shared by the SwiftUI Settings window and the AppKit quick menu —
and its resources must be reachable from that target's
`Bundle.module`.

A locale file is discovered the moment it exists under
`Resources/Locales/<code>.json` (any code other than `en`) and
the project is rebuilt — `Package.swift` copies the whole
directory (`.copy("Resources/Locales")`). It then appears in
Settings ▸ General ▸ Language, listed by its own native name
("Deutsch", not "German").

The **content guards** are the one registration step: they key
their policy by locale, so a new code joins `_STUB_TAGS` in
`scripts/localization_guards.py` **and** declares its script —
`SCRIPTS` for a non-Latin language, `LATIN_LOCALES` otherwise.
`extract-keys --check` refuses an unregistered locale outright
and says where to add it; `LocalizationRegistryTests` pins the
same relation.

The language names in that list are **endonyms** — each language
in its own name, whatever the active UI language (a German UI
still shows "English", "Français", "日本語", not "Englisch"),
the convention macOS System Settings uses. They come from macOS
(`Locale.localizedString(forIdentifier:)`), are **not**
translation keys, and must not be added to a locale file.

## Adding a new language

1. Pick the locale's ISO code (e.g. `fr`, `ja`, `pt-BR`).
2. Run the extractor against that code:

   ```
   scripts/extract-keys fr
   ```

   This rebuilds `en.json` from every `L(key, english[, args...])`
   call site in `Sources/KiwiDesk` and `Sources/KiwiDeskCore`,
   then writes `locale-worksheets/missing_fr.json` with every key
   `fr.json` does not have yet (all of them, the first time).

   Worksheets live in `locale-worksheets/` at the repo root,
   gitignored — never beside the catalogs in `Resources/Locales`.
   A worksheet is a *nested* `{key: {source, translation}}` map
   and every reader of the catalog directory expects a flat one,
   so a worksheet sitting there is read as a broken catalog or as
   a language called `missing_fr` and copied into the app bundle;
   `scripts/extract-keys --check` fails if one turns up among the
   catalogs.
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

   `source` is the English to translate FROM — read it for
   meaning, not as a template to mirror (see [Translating
   well](#translating-well)) — and is not yours to edit. Fill in
   `"translation"` and leave the key untouched. A template with
   `%1$@`/`%1$d` placeholders keeps them, repositioned wherever
   your grammar wants them (see [Interpolating a value into a
   sentence](#interpolating-a-value-into-a-sentence)). Leave
   `"translation"` empty (`""`)
   for a key you want to skip; it reappears the next time you run
   `extract-keys fr`.

   > **Re-running `extract-keys fr` mid-translation is safe.**
   > It rebuilds the worksheet, but reads the one already there
   > first and carries every filled-in `"translation"` across,
   > and says how many it carried.
   >
   > **Every entry it cannot carry is printed to the terminal
   > with the text you had**, so you can copy it back if it still
   > fits — once the worksheet is rewritten, that output is the
   > only copy. There are three:
   >
   > - **The English changed** since you started. The slot is
   >   emptied and refilled with the new `"source"`; `merge-keys`
   >   would refuse the same entry for the same reason.
   > - **The key is no longer missing** — either this locale
   >   already translates it, or it has left the app. The two are
   >   reported under different messages, because only the first
   >   means your work is safe in `<locale>.json`.
   > - **The entry is malformed** — most often a hand-written
   >   `"key": "text"` instead of the `{"source", "translation"}`
   >   shape. It cannot be verified, so it is not carried.
   >
   > A worksheet damaged into invalid JSON, or saved in an
   > encoding other than UTF-8, is refused rather than
   > overwritten; fix or move it, then run again.
4. Fold the finished translations back in:

   ```
   scripts/merge-keys fr
   ```

   This reads every entry with a non-empty `"translation"`,
   writes it into the flat `fr.json` (creating the file if
   needed), and deletes the worksheet. Entries you left empty are
   skipped — not merged as blanks — and printed as still pending.

   An entry is **also skipped when its `"source"` no longer
   matches that key's current English** in `en.json`, when it
   has no usable `"source"`, or when the key has left `en.json`:
   nothing to verify against, so nothing is merged. Those keys
   are listed on stderr **with the discarded text**, and the
   summary line reports how many were dropped. This is what keeps
   a worksheet from resurrecting what `scripts/drop-key <key>`
   retired — the meaning-changed form, which moves the English.
   It cannot see a `drop-key --locale <locale> <key>`, which
   retires one locale's text while the English stays put; neither
   can the carry-over in step 3. `--site` behaves identically
   against the site's own `en.json`.

   Two caveats:

   - It compares **text**, not meaning, so a typo fix in the
     English also invalidates a finished entry — stricter than
     the convention under [Maintaining the key
     set](#maintaining-the-key-set-for-maintainers), since a
     script cannot tell a typo from a rewrite.
   - Re-running `scripts/extract-keys fr` gets a skipped key back
     **only if `fr.json` does not already have it**. Every
     worksheet `extract-keys` itself produces satisfies that; a
     hand-written entry for an already-translated key does not,
     and its text is gone once `merge-keys` has reported it. To
     revise an existing translation, edit `fr.json` directly
     (next section) rather than hand-writing a worksheet.
5. Rebuild (`swift build`) and open Settings ▸ General ▸
   Language — the new locale appears under its native name, with
   every translated string live and every untranslated one still
   readable in English.

## Fixing or completing an existing translation

Same round-trip, scoped to what the target locale still lacks —
running `extract-keys <locale>` again after new English strings
were added pulls in only the delta:

```
scripts/extract-keys de      # writes locale-worksheets/
                              # missing_de.json with only what
                              # de.json doesn't cover yet
# fill in each entry's "translation" field in the worksheet
scripts/merge-keys de        # folds the non-empty ones into de.json
```

Running that first line on top of a part-filled worksheet is
fine — step 3 above says what is carried and what is printed.

To fix a wrong, awkward or overly literal existing translation,
edit the value directly in `<locale>.json` — the one case that
does not go through `missing_<locale>.json`, which only ever
lists what is *absent*. Small, targeted hand-edits to a shipped
`<locale>.json` are welcome; do not touch `en.json`.

That permission is for **people**. An AI agent never hand-edits a
catalog (`.claude/rules/localization.md`); its route to the same
end is `scripts/drop-key --locale <locale> <key>`, which retires
the defective value and puts the key back in scope for the
round-trip above. Its docstring names this case.

## The marketing site

The website under `site/` (the landing page, and the `/learn/`
guide once it is externalized) keeps its strings in flat
`{key: string}` manifests under **`site/src/i18n/`** —
`en.json`, `de.json`, one file per language — the shape the app
uses, read by the Astro components as `t.<key>`.

The one difference from the app: **the site's `en.json` is the
source of truth, authored by hand.** There is no Swift to scan,
so the tooling takes a `--site` flag that points it at
`site/src/i18n/` and, for `extract-keys`, loads `en.json` as the
key list instead of scanning Swift — and never rewrites it, since
re-emitting it sorted would wreck its deliberate grouping.

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

- `scripts/extract-keys --site --check` — validates that every
  shipped `site/src/i18n/<locale>.json` decodes as a flat
  `{string: string}` map, runs every [content
  guard](#content-guards) except the English-residue heuristic
  over its values, and warns on orphan keys (present in a locale,
  absent from `en.json`). It does **not** check `en.json`
  freshness — there is no code to derive it from. The `Site`
  workflow runs it on every PR that touches `site/**` or
  `docs/**`.
- `scripts/extract-keys --site --prune` — drops orphan keys from
  the site locale files, leaving the hand-authored `en.json`
  alone.
- `scripts/rename-key --site <old> <new>` — renames a key across
  every `site/src/i18n/*.json`, preserving each translation.
  Update the `t.<old>` use sites in the Astro components yourself
  afterward.
- `scripts/drop-key --site <key> [...]` — drops stale
  translations of a meaning-changed site string from every
  `site/src/i18n/<locale>.json`, leaving `en.json` untouched.

To add a new English string to the site: add the key to
`site/src/i18n/en.json`, reference it as `t.<key>` in the
component, then run `scripts/extract-keys --site <locale>` for
each language so it surfaces as missing.

### Adding a whole new site language

Routes are one file per locale, but a dozen places inside the
components **hand-enumerate** the locale set, and a language
added everywhere else still ships with those omitting it — a
language switcher missing an option, a stored-locale redirect
that cannot reach the new path, an `og:locale` naming the wrong
one, a 404 that leaves the language out of its list. There is no
single list to update, so find them mechanically:

```bash
grep -rn '"ja"\|/ja/\|ja_JP\|(de|ja)' site/src
```

Every hit is a decision to extend. The shapes to expect: locale →
path maps (`{ en: "/", de: "/de/", ja: "/ja/" }`), display-name
and `og:locale` maps, `en|de|ja` predicates and route regexes,
the `Lang` union in `site/src/i18n/legal.ts`, the
language-switcher markup in `Landing.astro` and `Guide.astro`,
and the `alts` array in `site/src/pages/404.astro` — static
hosting serves one 404 for every unmatched path, so that page
cannot pick a locale from the URL and renders them all.

### Key naming keeps the file structured

The site manifests (`en.json`, `de.json`) are stored **sorted by
key**; the round-trip tooling (`rename-key --site`) rewrites them
that way. The keys carry the structure: every key is prefixed by
its area (`nav_*`, `hero_*`, `feat_*`, `layout_*`, `footer_*` for
the landing; `guide_*` for the guide page, sub-grouped like
`guide_faq_*`, `guide_scenario_*`, `guide_tour_*`), so each group
clusters in the sorted order. **When you add a string, follow the
existing area prefix** rather than inventing a bare name; a new
area gets a new prefix.

## Translating well

The `source` field in `missing_<locale>.json` is a reference for
*meaning*, not a structural template. Read the key's name and,
where possible, open the app and see where the string appears (a
menu item, a tooltip, a section title) before translating it. A
sentence mirrored word for word reads stiff to a native speaker
even when every word is "correct"; write what a native speaker
would naturally say at that exact spot in the UI, in the
language's register (see [Tone & voice](#tone--voice)).

A first pass at a locale is often a little rough or literal in
places. Smoothing that out later is what [Fixing or completing an
existing
translation](#fixing-or-completing-an-existing-translation) is
for, and improvements toward natural phrasing are always welcome.

### One concept, one word

The failure that reads worst is your language's two good words
for one idea, used on two pages: the user learns the word once
and does not recognise it on the next screen, and search finds
one surface and not the other. It shows up between *adjacent*
surfaces most of the time — a tab bar and the help text under
it, a card title and the menu item that opens it.

Before you settle on a word for an ordinary noun — layout, gap,
profile, shortcut, preset — grep your own catalog for the
candidates and take the one already carrying the concept. Two
rules on top of that, both decided in the [feature name
policy](localization-naming.md) ▸ Family C:

- A word that already names **another** KiwiDesk thing in your
  file loses, however common it is: the label would be true about
  the wrong feature.
- The rival is usually still correct *somewhere* in your file,
  so never search-and-replace. Change the keys that name the
  concept and leave the ones where the word means something else.

Nothing checks any of this — that page argues why it cannot be
checked — so it is yours to hold.

### The tour's modifier abbreviations are not translated

The tour's shortcuts screen draws `ctrl`, `opt`, `shift` and
`cmd` under `⌃ ⌥ ⇧ ⌘`. Those four are **not catalog keys** and
never appear in a worksheet — they are language-neutral tokens
like the glyphs above them — so their appearing in English is
not a missed translation. The full names *are* translated, in
`key_recorder.help_press`: that key carries your language's word
for each of the four, and anything else naming a modifier should
match it.

## Tone & voice

Keep translations concise and match the register of the English
source (plain, direct, no marketing voice). For locales with a
formal/informal address distinction (German "Sie" vs. "du",
French "vous" vs. "tu", etc.), the suggested default is the
informal register — KiwiDesk is a personal developer tool — but
the first translator to ship a locale has the final call for
that language, and later translators follow that precedent
rather than re-litigating it string by string.

## Why `en.json` is generated, not hand-edited

English lives at the call site (`L("key", "English text")`) so a
developer reading the Swift source sees the real copy, never a
bare key. `en.json` is a **build-time translator manifest**, not
a runtime resource: it gives the extractor a canonical key list
to diff other locales against, and lets a Python (or any
external) tool enumerate every key without parsing Swift. The
running app never loads it — there is no `en` entry in the
bundled locale list (`LocaleCatalog`'s `!= "en"` filter). Never
add or edit a key only in `en.json`; the next `extract-keys` run
overwrites it. To change a string's English, edit the `L(...)`
call site in Swift and re-run `extract-keys`.

### Drift guard

The same key could in principle be called with two different
English strings by mistake. `extract-keys` fails loudly rather
than picking whichever it scanned last: it prints the offending
key and every conflicting string, exits non-zero, and refuses to
write `en.json` until every call site for the key agrees. The
same check runs as a Swift test (`LocalizationDriftGuardTests`),
so a regression fails `swift test` / CI without anyone running
the script.

### Freshness check (`--check`)

`scripts/extract-keys --check` re-scans both source trees and
compares the result to the committed `en.json` **without writing
anything**. It HARD-FAILS (non-zero exit) on:

- **drift** — the same key called with two different English
  strings;
- a **stale `en.json`** — a key was added, removed, or had its
  English edited since the last `extract-keys` run;
- a **malformed locale file** — any shipped `<locale>.json` that
  does not decode as a flat `{string: string}` map (bad JSON, a
  nested object, a non-string value). A hard failure because
  `LocaleCatalog` soft-fails a broken file to an empty dictionary
  at runtime: a malformed `de.json` crashes nothing and silently
  reverts German to all-English.
- **broken content** in any translated value — the [content
  guards](#content-guards) below.

It only *warns* (prints, does not fail) about **orphan keys** —
see [Maintaining the key
set](#maintaining-the-key-set-for-maintainers).

Where it is enforced — the pre-commit hook and CI — is under
[Review & CI](#review--ci).

### Content guards

Everything above reads *keys*. Nine checks read the copy itself
(`scripts/localization_guards.py`), each a hard failure. Six are
exact contracts; `english_residue` is a heuristic scoped to
non-Latin locales; the two feature-name checks are scoped by what
the catalogs ship rather than by script:

- **Wrong writing system.** Every locale value uses only the
  scripts that locale writes in: Cyrillic belongs to `ru`, kana
  to `ja`, Han to `ja`/`zh-Hans`/`zh-Hant`, Hangul to `ko`, and
  Greek, Arabic and Hebrew to none of them. Latin is not in the
  table — every locale uses it for `KiwiDesk`, URLs and `%1$@`,
  so its presence proves nothing. The table maps each script to
  the locales allowed to use it rather than each locale to one
  script, since Han cannot separate Japanese from Chinese while
  kana can. `en.json` is checked too: a stray non-Latin glyph
  there is a pasted literal in Swift.
- **Tagged stubs.** Untranslated English carrying its own locale
  code — `"Icon & name (ES)"`, `"Testo Global colors (IT)"`, and
  with full-width parens `"Group adjacent…（JA）"`. A value naming
  a *different* language (`"Alemán (DE)"` in Spanish) passes.
- **Interpolation-specifier drift.** The `%1$@`/`%1$d` set must
  match the English as a multiset — the one check guarding a
  *runtime* path, since these values reach `String(format:)`.
  Order is not checked: the numbering exists so a translation
  can reorder the arguments. A literal `%%` is ignored, since it
  carries no argument and several locales write `"%1$d%%"` where
  the English spells out "percent".
- **A withheld argument moved off the end.** The exception to
  the freedom above; the tooling knows which keys it applies to.
  A handful of frames end on a placeholder the app fills only
  *sometimes* — the Scrolling preview's caption names its `+`
  mark and says nothing about it when the row puts the mark off
  the frame. The app drops the space in front of such a clause
  along with the clause, which it can only do at the end of the
  sentence; anywhere else the empty case leaves a hole and
  strands any punctuation around it. Keep that placeholder last;
  every other placeholder in every other key stays free to move.
- **A collapsed translation** — one filler standing in for many
  unrelated keys (`"Opzione %1$@"` / `"Opção %1$@"` on every
  interpolated string).
  Every other check passes such a value: fluent, right script,
  no English, right placeholders. The bar is five distinct
  English strings on one value, or three when the value carries
  a specifier. Near-synonyms sharing one target word pass (`de`
  "Standard" covers "default"/"Default"/"standard").
- **English left in a translated sentence.** The shape a
  word-swapping machine translation produces: `"追加 Window"` for
  "Add Window", `"保存 as New Profile…"`. Two scopes. It runs on
  **non-Latin-script locales only** (`ja`, `ko`, `zh-Hans`,
  `zh-Hant`, `ru`): in a Latin-script locale a retained English
  word is indistinguishable from a cognate or loanword —
  `"Item ativo"`, `"Mein Setup"`, `"Limite del track"` are all
  correct — so there the other five checks apply and word-swap
  residue is review's, not the gate's. And it runs on the **app
  catalogs only**, not the site's (`--site`): site copy carries
  third-party names (`Homebrew`, `SketchyBar`, `JankyBorders`,
  `Ko-fi`) and embedded HTML, and the app's glossary does not
  list the site's vocabulary; the other five checks run on both.
  There is no `-ing`-weld sub-rule — German `fing` and
  `Frühling` are why (`.claude/rules/localization.md`) — so a
  bare weld with no English beside it (`"編集ing"`) is not
  caught, while `"編集ing init.lua directly."` still fails on
  `directly`.
- **A dropped feature name.** (Both families, and the rule that
  sorts a new name into one: [Feature name
  policy](localization-naming.md).) The GUI shows "App Bar" and
  "Space Bar" untranslated, so a translation that renames them
  ("Die App-Leiste", "Barra delle app") describes something the
  interface does not call that. Keep the name verbatim and
  translate around it: "Mostra la App Bar", "Couleurs de la
  Space Bar". Capitalization is yours ("App bar" is fine), and
  so is compounding — German's "Space-Bar-Farben" keeps the
  name, because separators are flattened before the comparison.
  **One mention is enough**: the check asks whether the name
  survives, never how often, so naming a bar once where the
  English names it twice passes — but a string contrasting the
  two bars needs both. **Every locale, whatever its script** —
  the interface shows those two names in Latin in all eleven
  catalogs. In Japanese and Korean adapting them is actively
  worse: スペースバー and 스페이스바 are the everyday words for
  the *spacebar key*, and neither script has capitals to mark a
  name. The list is `PRODUCT_NAMES`; adding to it is a product
  decision about what the GUI leaves in English, not a way to
  quiet a hit.
- **Layout mode names follow your picker — and only the CJK
  locales translate them.** Floating, Grid, Monocle, Scrolling,
  Stack and Track are values the user types verbatim
  (`set_mode(1, "stack")`), so the seven Latin-script locales
  keep them English and the picker matches the value typed into
  Lua or the CLI; `LocalizationModeNamePolicyTests` enforces
  that. The three CJK locales render them natively — `ja`
  モノクル, `zh-Hans` 单窗, `ko` 트랙. The one rule is **match
  your own picker**: if `layout.monocle.name` in your file says
  モノクル, the prose around it says モノクル too, never
  "Monocle".
- **Cross-language overlap.** Two locales of *different*
  languages sharing too many byte-identical values — a whole
  file pasted into the wrong locale. The threshold is 5% of the
  keys they share, floored at 20: sibling languages coincide on
  short labels (`es` and `pt-BR` sit well under the floor with
  the corpus clean), while a pasted file lands near 45%. Pairs of
  the same
  base language are skipped — `zh-Hans` and `zh-Hant` are one
  language in two scripts.

There is **no baseline or exemption file**: any hit is a real
defect. What the guards carry is a **glossary** — the terms that
stay English in every locale (`KiwiDesk`, `Lua`, `macOS`, Apple's
`Mission Control` and `Bundle identifier`, and every layout-mode
name, because `layout.<mode>.name` ships each one untranslated).
Interpolation specifiers, dotted identifiers like `init.lua`, and
a key name following a modifier glyph (`⌘ Command`) are stripped
before any word is judged. A term that must stay English joins
`GLOSSARY` in the same change set — the guard tells you, by
rejecting an otherwise-correct translation.

`scripts/merge-keys` runs all but the two corpus-level checks
(collapsed translation, cross-language overlap) per worksheet
entry, so a bad translation is **skipped rather than written**.
The clean entries in the same worksheet still merge, and each
skipped one is echoed to stderr with the reason — the worksheet
is deleted either way, so that transcript is the only copy of the
discarded text. Re-run `scripts/extract-keys <locale>` to get the
skipped keys back with the current English.

The guards are backed by Swift tests —
`LocalizationContentGuardTests` (the exact per-value contracts),
`LocalizationResidueGuardTests`, `LocalizationOverlapGuardTests`,
`LocalizationCollapseGuardTests` and
`MergeKeysContentGuardTests` — which exercise the predicates
against strings the tests write themselves, never the shipped
catalogs. `LocalizationRegistryTests` is the one exception: it
walks the shipped files to assert every one is registered in the
guards' locale tables.

## Maintaining the key set (for maintainers)

A key's life cycle spans five operations. Four are built on the
code-derived key set `extract-keys` scans; `drop-key` is not — it
validates against the shipped translation files, since its job
is pruning their stale values:

- **Add or refresh.** Add a new `L(key, english[, args...])`
  call site (or edit an existing one's English), run
  `scripts/extract-keys` and commit the updated `en.json`.
- **Check.** `scripts/extract-keys --check` is the read-only
  gate above: it hard-fails on drift, a stale `en.json` or a
  malformed locale file, and *warns* — printing the locale file
  and the orphaned key(s) — when a shipped `<locale>.json` still
  has a key no call site defines. An orphan is cruft, not a
  correctness bug (the app never looks it up), so it never blocks
  an otherwise-clean translator PR; a maintainer decides when to
  clean it up.
- **Prune orphans.** `scripts/extract-keys --prune` removes every
  orphan key from every shipped `<locale>.json` (and rewrites
  `en.json` as usual), printing what it removed per locale. Run
  it once a key's removal has landed.
- **Rename a key.** `scripts/rename-key <old_key> <new_key>`
  renames a key across `en.json` and every shipped
  `<locale>.json`, **preserving each file's existing value**. It
  refuses to run if `<old_key>` is absent everywhere or
  `<new_key>` already exists, and only touches locale files that
  had the old key. It edits JSON only — update the
  `L("<old_key>", ...)` call site(s) in Swift yourself, after
  which `scripts/extract-keys --check` passes again.
- **Drop stale translations.** `scripts/drop-key <key>
  [<key> ...]` removes the key(s) from every shipped
  `<locale>.json` — never from `en.json`, which is generated.
  Use it in the same change set as a **meaning-changing** English
  edit (below): the dropped key falls back to the new English at
  runtime and reappears on every locale's to-translate list, so
  the pipeline tracks the debt. It fails without touching
  anything if a key exists in no translation (typo guard).
  `--site` targets the site manifests instead.
- **Retire one locale's bad translation.**
  `scripts/drop-key --locale <locale> [--locale <locale>] <key>…`
  narrows the drop to the named locales — for the case where the
  English is fine and the **translation** is defective, which is
  what the content guards report, per locale. The typo guard
  still applies inside the narrowed scope: a key present
  elsewhere but not in the named locales fails rather than
  silently dropping nothing.

**Rename vs. drop vs. deprecate — pick by whether the *meaning*
changed, and where.** A tidier name for the same English in the
same UI spot is a rename: `scripts/rename-key`, so every
translation carries over. A string whose *meaning* changed while
the key rightly stays (the same field, re-explained — the common
case) takes `scripts/drop-key` in the same change set: a stale
translation is fluent-but-wrong, and correct-but-English beats
that until the retranslation lands. Purely cosmetic English
edits (typo, punctuation, capitalization) keep translations. A
call site going away or getting a new identity is deleted in
code, and the new key surfaces as missing the normal way. Never
use `rename-key` for a meaning change — it would carry a
translation of the *old* meaning forward under a name that no
longer matches it, and nothing would flag that for review.

## Extraction limitations

`scripts/extract-keys` is a regex-based scanner tuned to this
repo's `.swift-format` house style. It recognizes `L(` call sites
whose first two arguments (key and English template) are string
literals — or several literals joined by `+`, including Swift's
triple-quoted `"""..."""` multi-line strings — across any number
of lines; trailing interpolation arguments are read as part of
the call but never inspected. It does **not** evaluate arbitrary
Swift expressions: a key or English string built any other way
(string interpolation, computed values) is not picked up. Keep
call sites in that literal-concatenation style; anything more
dynamic needs a manual `en.json` review afterward, flagged in
review.

## Review & CI

Translations land like any other change: branch, commit, and
open a PR through the normal review flow (AGENTS.md §3).
`extract-keys --check` is enforced at two points, running the
same checks:

- **Locally, at commit time** — `scripts/pre-commit` (installed
  via `scripts/install-hooks.sh`) runs it whenever a Swift file
  or a `Resources/Locales/*.json` file is staged. Staging only
  `Resources/Locales/de.json` still runs it, so a broken or stale
  locale file is caught before the commit completes.
- **In CI** — `scripts/lint.sh`, the verify gate, runs `--check`
  unconditionally on every push and PR.

Both enforce the same policy: drift, a stale `en.json` or a
malformed locale file hard-fails; an orphan key only warns (see
[Maintaining the key set](#maintaining-the-key-set-for-maintainers)
for the cleanup path).
