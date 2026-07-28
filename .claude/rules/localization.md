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
doc-comment example can't leak a phantom key). AI agents must not
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

`extract-keys --check` runs unconditionally in `scripts/lint.sh`
(so: verify gate, CI, and `pre-commit` whenever a Swift or locale
file is staged). It hard-fails if `en.json` is stale, or if any
shipped `<locale>.json` doesn't decode as a flat
`{string: string}` map — a broken file would otherwise make
`LocaleCatalog` soft-fail to `[:]` and silently revert that
locale to English. An orphan key (in a locale file, absent from
code) only warns.

## The eight content guards (#95)

Everything above reads *keys*; `scripts/localization_guards.py`
reads the *copy*, and `--check` hard-fails on each. There is **no
baseline / exemption file** — a hit is a real defect. What the
guards carry instead is a grouped `GLOSSARY` of terms that stay
English; a new such term joins it, in the group that justifies
it, in the same change set.

Five are exact contracts:

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

The sixth, **English residue** in a translated sentence, is a
heuristic and the only one with a scope: non-Latin-script locales,
and the app catalogs only (not `--site`, whose prose keeps
third-party names and inline HTML). In a Latin-script locale a
retained English word is indistinguishable from a cognate
(`"Item ativo"`, `"Mein Setup"`), so widening it would flag dozens
of good translations. Don't re-add a rule claiming to be precise
everywhere, as an `-ing`-weld sub-rule once did — German
`fing` / `Frühling` falsifies it.

The last two are the **feature-name pair**, and
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
`MergeKeysContentGuardTests` — future scripts follow suit, so a
regression in the tooling is covered by `swift test`, not only by
running the script.

A guard suite exercises its predicate against strings the test
writes itself, **never the shipped corpus** — asserting against
the real catalogs would make the guard's coverage depend on the
corpus staying dirty, passing only while a bug was live.

## Core names, the GUI narrates (#96)

`L()` is `@MainActor` and much of Core is deliberately actor-free,
so a user-facing condition detected in Core returns **structure** —
a case, an enum, a value type — and the GUI renders the sentence
at its own boundary (`Conflict.Target.systemShortcut(…)` →
`ConflictText`). Never a pre-rendered English string across that
seam: it cannot be translated where it was written, and routing
`L()` into actor-free code to fix that would make the manager's
isolation a special case to buy one file's convenience.

Core currently holds **no** `L()` call site outside
`Localization/` — keep it that way. CLI/IPC error strings are the
deliberate exception and stay English: they are a machine
contract, not UI copy.
