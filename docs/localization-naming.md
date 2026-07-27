---
title: Feature Name Policy
description: Which KiwiDesk names stay English in every language, which each locale renders in its own words, and the rule that decides.
---

# Feature name policy

Some KiwiDesk names are the same in every language — "App Bar",
"Space Bar". Others are different in almost all of them — the
layout modes. This page is the one place that says which is which,
what each family requires of a translation, and why the two are
enforced by opposite-shaped guards.

It exists because getting this wrong is invisible: prose naming a
feature the interface does not call that reads perfectly to
anyone who does not have both the string and the screen in front
of them, and search made it worse — a destination name is now a
breadcrumb segment, so an invented name appears on every hit
inside that pane.

If you are translating, the rules are the two **What it requires**
sections. If you are changing the policy or adding a name, read
the rest.

## The question that sorts a name

> **Does this thing's own label key ship untranslated in all
> eleven catalogs?**

**Yes → Family A.** The name is the same everywhere. Add it to
`PRODUCT_NAMES` in `scripts/localization_guards.py`.

**No → Family B.** Each locale decides, and only consistency with
its own picker is enforced.

The test is about the **catalogs**, not about the word. The
tempting alternative — *does this name already have a
domain-standard translation people know from other software?* —
reads well and mis-sorts both families:

| name | vocabulary test says | catalogs say | correct |
|---|---|---|---|
| Space Bar | **B** — スペースバー is standard… for the *spacebar key* | A | **A** |
| Track | **A** — no domain-standard "Track layout" exists | B | **B** |
| `drag.ghost` | **A** — reads like a coinage | B (nine locales translate it: Silueta, Sagoma, ゴースト) | **B** |

Coinage-vs-borrowed is the *explanation* for how the catalogs came
out that way. It is not the test, because it is arguable and the
catalog question is checkable.

## Family A — the same name everywhere

Currently **App Bar** and **Space Bar**. `bars.switch.app_bar` and
`bars.switch.space_bar` are Latin in all eleven catalogs, so the
control every user taps says "Space Bar" whatever their language.

### What it requires

Keep the name verbatim wherever the English carries it, and
translate around it: "Mostra la App Bar", "Couleurs de la Space
Bar".

- **One mention is enough.** The check asks whether the name
  survives, never how often. If the English names a bar twice and
  your sentence reads better naming it once, that passes.
- **Keep each name the English carries.** A string contrasting the
  two bars needs both, or the contrast collapses.
- **Capitalization is yours** — "App bar" is fine.
- **Compounding is fine.** German's "Space-Bar-Farben" keeps the
  name; separators are flattened before comparison, so correct
  compounding is never punished.

Enforced by `dropped_product_names`, in every locale.

### Why script does not matter here

The natural reading is that this mirrors the English-residue
guard, which is non-Latin-only. The two ask different questions.
Residue asks whether a word was *forgotten* — a judgment about the
sentence around it, and therefore script-sensitive. This asks
whether a name the interface never translates was translated
anyway, which is script-independent in the same way "KiwiDesk",
"Lua" and "BSP" are. `_is_partly_translated` already lists "App
Bar" beside them as correctly all-English in a non-Latin catalog.

Adapting is **worse** in Japanese and Korean, not better:
スペースバー and 스페이스바 are the ordinary words for the
*spacebar key*, and neither script has capitalization to mark a
proper noun, so the feature name would be indistinguishable from
the key. English does not have that collision.

### Presence, not parity

The check requires the name to be **present**, never to appear as
often as in the English. Tightening it to parity reads like a
strengthening and is a regression: dropping a redundant repetition
of a proper noun is ordinary translation practice, so parity
rejects correct work and pushes the translator toward a literal,
worse sentence. The defect this guards against is a locale
*renaming* the feature; a locale naming it fewer times has not
renamed anything.

`LocalizationProductNameGuardTests` pins the distinction — a
parity implementation fails two of its arguments.

### No per-key opt-out

There is no exemption file, and none is needed. The escape
hatches, in order:

1. **Reword around the name.** What every current translation
   does.
2. **If the name is redundant under its section header, delete it
   from the English.** That lifts the obligation in every locale at
   once and improves the English — the GUI already works this way
   (`SpaceBarGroups`' caption omits the name its header supplies),
   so the obligation is *authored*, not imposed. An opt-out would
   invert this, letting locales quietly diverge from an English
   redundancy nobody fixed.
3. **`scripts/drop-key --locale <locale> <key>`** retires one
   locale's value to the English fallback. A loud escape, which is
   the point.

Trade-off: a translator who wants the name gone entirely must
change the English or drop the key. Accepted — the multi-mention
strings *contrast* the two bars ("Space Bar sits at the screen
edge, App Bar sits next to the windows"), where dropping one makes
the sentence wrong rather than tighter. That is why presence is
per-name.

## Family B — the layout modes

Floating, Grid, Monocle, Scrolling, Stack, Track. (BSP is an
initialism every locale keeps.)

The three CJK locales render them natively — `ja` モノクル, `ko`
트랙, `zh-Hans` 单窗. The seven Latin-script locales keep them
English.

### What it requires

**Match your own picker.** If `layout.monocle.name` in your file
says モノクル, the prose beside it says モノクル too, never
"Monocle". If your file keeps "Monocle", so does your prose.

No name is required — there is no single right word to demand.
Enforced by `untranslated_mode_names`, which requires the
*English* name to be **absent** once your picker translates it,
and skips your locale entirely when your picker is the English
word.

Descriptive use is not naming. English writes the mode names
lower-case in running prose ("in the bsp, stack, scrolling, and
track layouts") and capitalises only when naming the picker entry,
so the guard matches the capitalised form alone. "La modalità
floating" describes behaviour and is free; "la disposizione
Floating" names a picker entry that reads "Fluttuante" and is not.

### Why the Latin-script locales keep English

A mode name is not an ordinary label. It is a value the user types
verbatim:

```lua
KiwiDesk.set_mode(1, "stack")
```

```json
{"command":"set_mode","args":["1","grid"]}
```

A Spanish picker reading "Pila" above a config that only accepts
`"stack"` breaks the link between what is shown and what is
written. No other setting has that property, which is why
translating mode names reads as helpful and is not.

The CJK locales are the exception for the same reason Family A has
none: between two Latin-script languages the English word carries
fine, but in a CJK sentence it is a foreign body.

`LocalizationModeNamePolicyTests` pins which locales are on which
side, against the shipped catalogs.

## Why the guards are opposite shapes

It is forced, not stylistic:

| | Family A | Family B |
|---|---|---|
| the name is | a coinage with no correct translation | a word with a different correct form per locale |
| so the guard can demand | the English be **present** | only that the English be **absent** |
| exemptions needed | none | none — locales keeping English skip themselves |

The symmetric form for Family B — demand the locale's *own*
translation be present — genuinely cannot work: a correct Spanish
inflection like "las ventanas… flotarán" carries no noun
"Flotante", so it would flag correct copy.

Rejecting that shape is right. Concluding from it that **no** guard
is possible does not follow, and is the expensive mistake here.
This defect is invisible to a reviewer reading a language they do
not speak, so a family left to review alone accumulates precisely
the errors a guard would have named.

## Adding a name

Apply the catalog question, then:

- **Family A** — add it to `PRODUCT_NAMES`. Obligation scales with
  *authored English mentions*, not list length, so it binds only
  the keys whose English already contains it.
- **Family B** — add its `layout.<mode>.name` key to
  `MODE_NAME_KEYS`.

**A name that can occur descriptively does not belong in Family
A.** The check is case-insensitive there, so it cannot tell a
referential mention from a descriptive one. Both current Family A
names are two-word coinages that only ever occur referentially, so
the question never arises. A name built from ordinary words would
fire on incidental prose that was never naming the feature —
demanding a verbatim keep for a sentence with nothing to keep. A
guard failing on correct copy is the one failure that makes an
exemption file look necessary, so the existing rule holds: argue a
name in, never add one to silence a hit.

## See also

- [Translating](translating.md) — the full translator guide,
  including the other five content guards.
- [Design Decisions](design-decisions.md) — the rest of the
  settled product and UX decisions.
