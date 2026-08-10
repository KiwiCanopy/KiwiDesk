---
paths:
  - "Sources/KiwiDeskCore/Localization/**"
  - "Sources/KiwiDeskCore/Resources/Locales/**"
  - "scripts/extract-keys"
  - "scripts/merge-keys"
  - "scripts/rename-key"
  - "scripts/drop-key"
  - "scripts/localization_guards.py"
  - "docs/translating.md"
  - "docs/localization-naming.md"
---

# Localization (issue #9)

Canonical for this subsystem (AGENTS.md §5 indexes it).
`Resources/Locales/*.json` is **generated / translation-owned**.

## Call sites

Every GUI string routes through `L("key", "English")`
(`LocalizationManager.swift`). English is the source of truth,
inlined at the call site, with per-key fallback when a locale
omits a key.

A value interpolated into a sentence (a name, a count) MUST go
through the `L(key, english, args...)` overload with **positional**
`%1$@` / `%1$d` specifiers, never `+`-concatenated fragments — a
translation can't reorder pieces stitched together in Swift, and
many languages need to.

The GUI language pick persists in `UserDefaults`
(`LocalizationPreference`), never `gui.json` — it is documented as
side-effect-free and must never create a sidecar or flip
`KiwiCore.isGuiManaged`.

## Never hand-edit a catalog

`en.json` is regenerated wholesale by `scripts/extract-keys` from
real call sites (it scans both `Sources/KiwiDesk` and
`Sources/KiwiDeskCore`, and ignores `//` / `///` comments so a
doc-comment example can't leak a phantom key). Since Phase 4 it
is ALSO read at runtime: **a surface that renders a
census-labelled key away from its owning row (diff rows, the
search index) routes through `SettingsCensusLabel`**, which
loads the manifest as its English fallback — never a second
`LocaleCatalog.load("en")` of its own, or two cached English
copies drift. `DetailPanelTests` pins the caller set; the
amendment is stated on `LocaleCatalog.load` and argued in
`docs/design-decisions.md`, and it changes nothing about
authoring: English still lives at the call sites, and a view
deleted in a restructure still re-authors its keys in the same
change. AI agents must not
hand-edit **any** `Resources/Locales/*.json`. Use the scripts:

| Task | Command |
|---|---|
| Translate a locale | `scripts/extract-keys <locale>` → `scripts/merge-keys <locale>` |
| Rename a key, keep translations | `scripts/rename-key <old> <new>` |
| English **meaning** changed | `scripts/drop-key <key>` (same change set) |
| One locale's translation is bad | `scripts/drop-key --locale <locale> <key>` |
| Remove orphans | `scripts/extract-keys --prune` |

`drop-key` in the same change set makes every locale fall back to
the new English and puts the key back on the to-translate list.
Cosmetic English edits (typo, punctuation) **keep** translations.
The per-locale form exists because the content guards report per
locale — dropping every copy would discard good work. See
`docs/translating.md`.

Because the same English text can in principle be authored at two
call sites for one key, `extract-keys` fails loudly on any such
drift rather than silently picking one.

## Only catalogs live in the catalog directory

Nothing but a flat `{key: string}` catalog may be added to
`Resources/Locales` (or `site/src/i18n`) under a `*.json` name —
that glob is how every reader of those directories finds its
input. A tool that mints a working file writes it under
`locale-worksheets/` — outside every tree a target ships from,
and `scripts/locale_paths.py` is the one definition of that path,
imported by both scripts that touch it rather than re-derived.
`LocaleWorksheetLocationTests` pins where `extract-keys` writes
and `LocaleWorksheetRejectionTests` pins that one found among the
catalogs is still *rejected*. Two rejections exist, deliberately:
`validate_locale_files` in `scripts/extract-keys` (reached by
`--check` and `--prune`) and the `CFBundleLocalizations` glob in
`scripts/build-app.sh`, which `AppPlistLocalizationTests` pins —
the packager needs its own because it is the path that produces a
signed artifact without running the gate.

**A reader that would *decode* a file must never skip one it
cannot** — name it instead, the way `SettingKeyLocaleTests` and
`LocalizationModeNamePolicyTests` do: skipping is how a misplaced
file survives, and the skip is invisible in a green run. A walker
that enumerates locale *codes* and decodes none of them is the
exception and filters `missing_` by name (`shipped_locale_files()`
is the authority the Swift one mirrors —
`LocalizationRegistryTests`); that filter exists so a walker
cannot rewrite or mis-report a stray worksheet before a rejection
has named it, and it must carry a comment saying so rather than
reading as an assumption about what lives there.

The cost of getting this wrong is spread across readers that have
no idea a translation pass is open: SwiftPM `.copy`s the whole
directory into the bundle, `LocaleCatalog.availableLocales()`
offers every `*.json` stem but `en` as a language,
`scripts/build-app.sh` globs the same directory for
`CFBundleLocalizations`, and the Swift guards decode all of it as
flat maps — which is how one `missing_de.json` read as a
`DecodingError` naming an innocent key.

`extract-keys --check` runs unconditionally in `scripts/lint.sh`
(so: verify gate, CI, and `pre-commit` whenever a Swift or locale
file is staged). It hard-fails if `en.json` is stale, or if any
shipped `<locale>.json` doesn't decode as a flat
`{string: string}` map — a broken file would otherwise make
`LocaleCatalog` soft-fail to `[:]` and silently revert that
locale to English. An orphan key (in a locale file, absent from
code) only warns.

## The content guards (#95)

Everything above reads *keys*; `scripts/localization_guards.py`
reads the *copy*, and `--check` hard-fails on each. **That
script's own docstring is the authority on how many there are** —
the list below is a reader's map, not a second register, so add a
guard there and let this follow. (The docstring contracts the
exact-and-heuristic ones individually; the feature-name pair is
described here and in `docs/localization-naming.md`.) There is **no
baseline / exemption file** — a hit is a real defect. What the
guards carry instead is a grouped `GLOSSARY` of terms that stay
English; a new such term joins it, in the group that justifies
it, in the same change set.

These are **exact contracts** and hold for any corpus:

- **wrong writing system** — Cyrillic→`ru`, Kana→`ja`,
  Han→`ja`/`zh-Hans`/`zh-Hant`, Hangul→`ko`. Latin is
  deliberately absent: every locale uses it, so its presence
  proves nothing.
- **tagged stub** — `"Icon & name (ES)"`, full-width `（JA）`
  included.
- **specifier drift** — the `%1$@` multiset must match the
  English. The only guard on a runtime path, since these reach
  `String(format:)`.
- **cross-language overlap** — two different languages sharing a
  file's worth of identical values.
- **collapsed translation** — one filler reused for many
  unrelated keys.
- **withheld-argument position** — a frame interpolating an
  argument the app may render EMPTY puts that specifier anywhere
  but last.

That last one carries an obligation on the Swift side, because
the catalog cannot show it: **a frame whose argument the GUI may
render empty registers that key in `WITHHELD_ARGUMENTS` in the
same change set.** The frame owns the space before the clause and
the caller trims it away with the clause — which only works at the
end, and every other key is told the opposite (the numbering
exists so a translation may move a specifier, and
`placeholder_drift` deliberately ignores order). Unregistered, the
failure is a doubled space and a stranded comma in a language
nobody reviewing the change reads.
`LocalizationWithheldArgumentTests` holds both directions and the
scope.

**English residue** in a translated sentence is instead a
heuristic, and the only one carrying a *corpus* scope as well as
a locale one: non-Latin-script locales, and the app catalogs only
(not `--site`, whose prose keeps third-party names and inline
HTML). In a Latin-script locale a retained English word is
indistinguishable from a cognate
(`"Item ativo"`, `"Mein Setup"`), so widening it would flag dozens
of good translations. Don't re-add a rule claiming to be precise
everywhere, as an `-ing`-weld sub-rule once did — German
`fing` / `Frühling` falsifies it.

The **feature-name pair** is the remaining group, and
`docs/localization-naming.md` is their one copy — read it before
touching either. In short: `dropped_product_names` requires
"App Bar" / "Space Bar" **present** in every locale, script
irrelevant (deliberately *not* the residue rule's mirror);
`untranslated_mode_names` requires the English mode name
**absent** in the three CJK locales, which render them natively,
and skips the seven that keep the English word. A new name joins
a family by one checkable question — *does its own label key ship
untranslated in all eleven catalogs?* — never by arguing whether
it is a coinage. Matched as a phrase, not as tokens: `GLOSSARY`
holds `app`, `bar` and `space` separately, so a word-level test
cannot tell "App Bar" from "App-Leiste".

`merge-keys` runs the per-value guards so contamination never
lands.

## A translated label still has to fit, and still has to match

Two obligations a translator meets while editing a catalog, which
is why they are here rather than beside the views:

- **A destination label wants to be a short noun in every
  language** — it is a card title, a back-chip heading and a
  search row all at once, drawn single-line (`HomeCard`'s
  title row owns the `lineLimit`; the metrics file keeps only
  the icon tile). Since #678
  turn 9 dropped the sidebar there is no fixed column to
  measure against (the label-width suite retired with it, as
  this bullet promised): a card flexes, so an over-long label
  truncates visibly rather than breaking a budget. Shorten with
  the whole meaning intact — the trimmed label is the only name
  the user ever reads. Ordinary *row* labels take the OPPOSITE
  line: the control is fixed and the label flexes and wraps.
- **A `▸` breadcrumb names on-screen labels, so every segment
  must equal what that segment's own key renders to in YOUR
  locale** — the destination label for the head, your own
  `layout.<mode>.name` for a tail naming a mode.
  `SidebarCrossReferenceTests` holds it, and four catalogs were
  already violating it when the guard landed.

## Registering a new locale

Locale policy is keyed by locale in **three** tables; a new locale
must be registered in all of them: `_STUB_TAGS`, plus a *script
declaration* — `SCRIPTS` for a non-Latin language,
`LATIN_LOCALES` otherwise.

Forgetting the tags makes a guard go silently quiet; forgetting
the script declaration used to do the same and now goes **loudly
wrong**, which is why it is a declaration rather than a default:
the feature-name guard holds Latin-script locales to keeping
"App Bar" verbatim, so a locale read as Latin by accident is
*demanded* to carry an ASCII phrase inside its own script.
`--check` refuses a locale missing from either, and
`LocalizationRegistryTests` pins both plus their disjointness.

## Every script has a sibling test suite

`LocalizationDriftGuardTests`, `LocalizationOrphanTests`,
`RenameKeyTests`, `DropKeyTests`,
`LocalizationContentGuardTests`, `LocalizationResidueGuardTests`,
`LocalizationProductNameGuardTests`,
`LocalizationOverlapGuardTests`,
`LocalizationCollapseGuardTests`, `LocalizationRegistryTests`,
`LocalizationWithheldArgumentTests`,
`MergeKeysContentGuardTests`, `LocaleWorksheetLocationTests`,
`LocaleWorksheetRejectionTests`
— future scripts follow suit, so a
regression in the tooling is covered by `swift test`, not only by
running the script.

A guard suite exercises its predicate against strings the test
writes itself, **never the shipped corpus** — asserting against
the real catalogs would make the guard's coverage depend on the
corpus staying dirty, passing only while a bug was live.

## Core names, the GUI narrates (#96)

A user-facing condition detected in Core returns **structure** —
a case, an enum, a value type — and the GUI renders the sentence
at its own boundary (`Conflict.Target.systemShortcut(…)` →
`ConflictText`, `ConfigIssue.Kind` → `ConfigIssueText`). Never a
pre-rendered user-facing string across that seam. The reason is
**ownership**, not actor isolation: copy authored in Core cannot
be re-rendered when the user switches language, and an English
literal there never reaches `extract-keys`, so it never becomes a
key and no locale can translate it. (Some of Core genuinely is
actor-free and so genuinely cannot call `L()` — `StandardProfiles`,
`KeybindingConflicts`. But `KiwiCore` is `@MainActor` and *could*;
that is why "cannot reach `L()`" is the wrong test.)

**The rule is about the seam, not about file paths.** Until #601
this said "Core holds no `L()` call site outside
`Localization/`", which was false — Core draws some of its own
UI (the Space Bar, the sticky mark) and that copy crosses no
seam, so `L()` is right there. Worse, the literal reading
pointed at the wrong defect: the
four `ConfigIssue` messages that actually violated the seam never
used `L()` at all. They were hardcoded English, so
`extract-keys` could not see them, they never entered a catalog,
and **no locale could translate them however complete it was** —
which a ban phrased around `L()` would never have caught.
`CoreLocalizationBoundaryTests` pins the file list. It covers
only the `L()`-shaped half; a sentence built *without* `L()` is
invisible to any string scan, so that half is prevented by
carrying structure and pinned per family by a renderer test —
`ConfigIssueTextTests`, and `PresetSummaryCoverageTests` after
the same defect turned up in the Presets list.

CLI/IPC error strings are the deliberate exception and stay
English: they are a machine contract, not UI copy. A Lua
interpreter message carried as an associated value is the same
class — `ConfigIssue.Kind.luaError` keeps it verbatim and
localizes only the frame around it.
