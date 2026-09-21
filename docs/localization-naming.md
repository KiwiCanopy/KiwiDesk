---
title: Feature Name Policy
description: Which KiwiDesk names stay English in every language, which each locale renders in its own words, and the rule that decides.
---

# Feature name policy

Some KiwiDesk names are the same in every language — "App Bar",
"Space Bar". The layout modes differ in almost all of them. A
third group is not a name at all, but an ordinary word a language
may have two of — *layout*, *gap*, *profile*. A wrong name reads
perfectly to anyone without both the string and the screen in
front of them, and a destination name is also a breadcrumb
segment, so an invented one appears on every search hit inside
its pane.

If you are translating, the rules are the three **What it
requires** sections. If you are changing the policy or adding a
name, read the rest.

## The question that sorts a name

> **Does this thing's own label key ship untranslated in all
> eleven catalogs?**

**Yes → Family A.** The name is the same everywhere. Add it to
`PRODUCT_NAMES` in `scripts/localization_guards.py`.

**No → Family B.** Each locale decides, and only consistency with
its own picker is enforced.

**No key to ask about → Family C.** A common noun — *layout*,
*gap*, *profile*, *shortcut* — has no label key of its own. If
you cannot name the key whose value is the name, you are in
Family C.

The test reads the **catalogs**, not the word. A vocabulary test
— *does this name have a domain-standard translation?* —
mis-sorts both families:

| name | vocabulary test says | catalogs say | correct |
|---|---|---|---|
| Space Bar | **B** — スペースバー is standard… for the *spacebar key* | A | **A** |
| Track | **A** — no domain-standard "Track layout" exists | B | **B** |
| `drag.ghost` | **A** — reads like a coinage | B (nine locales translate it: Silueta, Sagoma, ゴースト) | **B** |

Coinage-vs-borrowed explains how the catalogs came out; it is
arguable, and the catalog question is checkable.

## Family A — the same name everywhere

**App Bar**, **Space Bar**, and **Sticky**. `bars.switch.app_bar`
and `bars.switch.space_bar` are Latin in all eleven catalogs, so the
control every user taps says "Space Bar" whatever their language.

**Sticky** (#579) is the one **single-word** member, admitted by
product decision rather than by the sort question: `de`, `ru` and
`zh-Hant` had rendered it "Fixierung"/"Закреплённое"/"常駐", so
the catalog test read Family B until they were reharmonized, and
`design-decisions.md` calls it "the settled user-facing term". It
passes the descriptive-occurrence check in *Adding a name*. Its
two scopes are **"Toggle sticky everywhere"** and **"Toggle
sticky on this screen"** (#1094) — the qualifier is an ordinary
phrase each locale renders in its own words around the fixed
"Sticky" atom. Render "screen" with the catalog's own SCREEN
word, never its *display* or *monitor* word: under Family C rule
1, a qualifier that is the word naming the **Monitors**
destination reads as a different destination, even where the
whole string differs.

**`zh-Hans` is the measured exception.** It splits the English
"screen" by countability — 屏幕 where the sense is mass, 显示器
for a countable one (`presets.screen_name.main` 主显示器,
`profiles.screens.many` %1$d 台显示器) — so 显示器 IS its screen
word here, and rule 2 is satisfied by the split. That it also
equals `destination.monitors` is a pre-existing overlap belonging
to #865: a locale whose own screen word collides with a
destination label needs the destination renamed, not the row.

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
  name; separators are flattened before comparison.

Enforced by `dropped_product_names`, in every locale.

### Why script does not matter here

This check is not the English-residue guard's mirror. Residue
asks whether a word was *forgotten* — a judgment about the
sentence around it, so script-sensitive. This asks whether a name
the interface never translates was translated anyway, which is
script-independent in the same way "KiwiDesk", "Lua" and "BSP"
are; `_is_partly_translated` already lists "App Bar" beside them
as correctly all-English in a non-Latin catalog.

Adapting is **worse** in Japanese and Korean: スペースバー and
스페이스바 are the ordinary words for the *spacebar key*, and
neither script has capitalization to mark a proper noun, so the
feature name would be indistinguishable from the key.

### Presence, not parity

The check requires the name to be **present**, never to appear as
often as in the English. Dropping a redundant repetition of a
proper noun is ordinary translation practice, so parity would
reject correct work; the defect guarded against is a locale
*renaming* the feature. `LocalizationProductNameGuardTests` pins
the distinction — a parity implementation fails two of its
arguments.

### No per-key opt-out

There is no exemption file. The escape hatches, in order:

1. **Reword around the name.** What every current translation
   does.
2. **If the name is redundant under its section header, delete it
   from the English.** That lifts the obligation in every locale
   at once; the GUI already works this way (`SpaceBarGroups`'
   caption omits the name its header supplies), so the obligation
   is *authored*, not imposed.
3. **`scripts/drop-key --locale <locale> <key>`** retires one
   locale's value to the English fallback — a loud escape.

A translator who wants the name gone entirely must change the
English or drop the key.

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

No name is required. Enforced by `untranslated_mode_names`, which
requires the *English* name to be **absent** once your picker
translates it, and skips your locale entirely when your picker is
the English word.

Descriptive use is not naming, and the guard tells them apart by
case: it matches the capitalised form alone. This is a
**heuristic, not a rule the English follows** — `en.json`
capitalises in labels that name no picker entry ("Stack
position", "Track limit") and lower-cases some referential uses
("the track layout") — so a name whose English is lower-cased
everywhere would slip past it. "La modalità floating" describes
behaviour and is free; "la disposizione Floating" names a picker
entry that reads "Fluttuante" and is not.

**Known blind spot: the check runs in one direction only.** It
fires where a picker is translated, which today means the three
CJK locales. The seven that keep the English names skip
themselves, so nothing checks *their* prose against their own
picker: a German caption reading "Schwebend" beside a picker
reading "Floating" passes. Those locales are held by review, and
by `LocalizationModeNamePolicyTests` only at the label level.

**So English prose does not name a layout mode either.** No
predicate over the translations can close the blind spot, so the
source stops handing translators a mode word to decide about. A
sentence that needs to name a layout interpolates
`layout.<mode>.name`; prose that merely describes what a Space
is *for* names no mode at all. This binds the **English** author
first — one concept, one word, decided in `en` before any catalog
can disagree. `PresetSummaryVocabularyTests` holds
`presets.*.summary`, deriving its ban list from `layout.*.name`
so a renamed or added mode cannot slip past it; a second family
of prose that names layouts owes its own guard.

### A mode's own structural unit is not a common noun

Some modes name the thing a window sits in after the mode
itself: a Track holds windows, a Stack has a zone the overflow
piles into. Read as ordinary vocabulary those look like Family C
— the English lower-cases them, they never appear alone as a
label, and every language has a good word of its own for each.

**Render such a unit with whatever your own `layout.<mode>.name`
says, and never with a word of your own.** A second word for it
is a second name for one KiwiDesk concept — the shape
`.claude/rules/config-vocabulary.md` bans for Space and for
screen — and the picker entry and the help text under it are
adjacent surfaces on the *same card*.

**Do not sort it with Family C's ladder.** Family C is the family
with no label key to read (*The question that sorts a name*);
this concept has one, so Family B governs. The ladder decides it
against the name every time, because rule 2 counts occurrences
and the unit outnumbers the picker entry by construction (owner
ruling 2026-08-29, which settled **Track**).

**Where the derived name will not go into your sentence, say so
rather than smoothing it over.** An indeclinable Latin noun in an
inflecting language can leave a construction the grammar cannot
build — Russian lost the genitive that disambiguated "the size of
the window's Track" and gained a plural verb to carry the number.
Rewording around that is part of the obligation, not licence to
bring the second word back. If nothing rewords, the escape is
Family B's own and is a ruling rather than a translator's call:
your picker may translate the mode name, after which the unit
follows it there instead.

**One half of this is guarded, and it is the same half as the
rest of Family B.** `untranslated_mode_names` catches a
translated-picker locale writing "Track" for the unit —
capitalised only. The mirror — a locale whose picker keeps
English writing its own word for the unit — is invisible to it
(*Known blind spot*), and no predicate can be built for it,
because the unit's rival word is correct prose somewhere. That
half is review's.

**A new mode joins no register for this.** The rule reads
`layout.<mode>.name`, which `MODE_NAME_KEYS` already carries.
What a new mode owes is the sweep: settle the unit's word in
every catalog in the change that names the unit.

### Why the Latin-script locales keep English

A mode name is a value the user types verbatim:

```lua
KiwiDesk.set_mode(1, "stack")
```

```json
{"command":"set_mode","args":["1","grid"]}
```

A Spanish picker reading "Pila" above a config that only accepts
`"stack"` breaks the link between what is shown and what is
written. The CJK locales are the exception because the English
word carries between two Latin-script languages and is a foreign
body in a CJK sentence.

`LocalizationModeNamePolicyTests` pins which locales are on which
side, against the shipped catalogs.

## Family C — the common nouns

*Layout*, *gap*, *profile*, *shortcut*, *preset*, *slot*. Words
KiwiDesk did not coin and does not display as a name of their
own — they only ever appear inside a sentence about something
else.

Families A and B are about what a *feature* is called. Family C
is about one language having two ordinary words for the same
idea and a translation reaching for both. It falls between
adjacent surfaces most of the time — a tab bar and the help text
under it, a destination label and the menu item that opens it.

### What it requires

**One concept, one word, per catalog.** When you meet a concept
this file does not name, decide it with the ladder below and
apply your answer everywhere in your file, not only in the key
you were editing.

1. **A word that already names another KiwiDesk concept in your
   catalog loses, whatever its count.** A label that reuses
   another feature's noun reads as *true about the wrong thing*:
   `zh-Hans` labelling a Profile 配置文件, which is what
   `general.advanced.config_file` renders, made a profile's
   search result say *configuration file*; `es`, `it` and `pt-BR`
   labelling a bar gap with their word for a **Space**; `ko`
   labelling a bound key with its word for *connected*, beside a
   card counting connected displays; `ja` reaching for Apple's
   own 操作スペース, the term for the macOS Desktop that
   KiwiDesk's Spaces are deliberately not.
2. **Otherwise your catalog's own occurrence count decides.**
   Grep your file for both candidates; the one already carrying
   the concept wins and the other is swept to it. **Your file is
   both of them** where your locale ships in the app and on the
   site — `Sources/KiwiDeskCore/Resources/Locales/<loc>.json` and
   `site/src/i18n/<loc>.json` are one register, so grep both and
   let the pair decide; a per-file count cannot see a split that
   runs *between* the files (`de` grepped site-only returns
   Desktop for macOS's Desktop, the answer #1337 had to undo).
3. **Within about ten percent, the destination label or picker
   entry decides.** That string is a card title, a back-chip
   heading and a search kind-line at once, so it is the name the
   user actually learns.
4. **Your ear does not override 1–3.** Awkwardness is an argument
   for a different winner under rule 2, never for keeping a second
   word.
5. **Where the rivals are verbs for different OBJECTS, the one
   that names the right object wins — ahead of count** (owner
   ruling, 2026-08-29). `es` splits *aumentar* (increase a
   quantity) against *agrandar* (enlarge a window), and `fr`
   *augmenter* against *agrandir*; a count led by two keybinding
   rows picks the word for the wrong kind of thing.

   Rule 2 still governs where both rivals name the same object —
   that is most splits, and it is why the register stays the
   catalog rather than a table.

   **Its residue is an ENGLISH problem, and the sweep does not
   fix it here.** These labels' grammatical object is a dimension
   (*Agrandar la altura*), so the winning verb reads a shade
   less naturally at the very sites it was chosen for. The fix is
   a label whose object is the window, not a second verb.

A rival word is usually still *correct somewhere else in the same
file* — `it`'s «disposizione» renders English *arrangement* in ten
keys, `ru`'s «раскладка» is also a keyboard layout, `es`'s
«espacio» is a Space in a hundred keys. So this is never a
search-and-replace, and a sweep that changes a concept ships with
the list of keys it deliberately left alone.

### When rule 1 takes the word you needed

Rule 1 does not say what the *losing* site calls the thing now,
and a second ordinary noun is the exact defect this family exists
to stop, so the escape is ranked too. Take the first that fits.

1. **Check the destination label is faithful before working
   around it.** Where the English destination carries a
   qualifier and your catalog rendered it bare, the collision is
   the *destination's* defect. Restore the qualifier and the bare
   noun is free again. `destination.layout` is the worked case:
   English is "Layout **Defaults**", and `fr` and `ru` had
   rendered it bare ("Dispositions", "Раскладки"), leaving the
   preset card's own button reaching past the word it wanted
   ("Voir les dispositions", "Раскладки набора"); restoring the
   qualifier let each button collapse to the bare noun.
2. **Where English's own destination IS the bare noun** —
   Profiles, Spaces, Bars, Shortcuts — the shortage is real.
   Then **the ordinary site qualifies and the destination never
   moves.** The destination label is the name the user learns
   (rule 3); moving it spends the one string that has to stay
   stable.
3. **Prefer the shortest qualified NOUN phrase to a verb
   phrase** wherever the site is a control whose width is
   measured. A verb phrase can only grow; a qualified noun
   collapses back to the bare noun the moment step 1 frees it.
   `.claude/rules/localization.md` ▸ *an ACTION label must fit
   its control* owns the width half, including the obligation to
   re-measure a pair when a control joins a row.
4. **Never coin a second bare noun for the concept.** Step 2 is
   where it is tempting.

`DestinationNameCollisionTests` holds only the byte-identical
case — it makes the collision *visible*, not resolved. Steps 1–4
are review's, like the rest of this family.

**One concept is ruled and deliberately unswept**: the physical
screen, where English carries three words. The winner is
`screen`, `display` is reserved for quoting Apple's own controls,
the English-side obligation is
`.claude/rules/config-vocabulary.md` ▸ noun glossary, and the
argument is `docs/design-decisions.md` ▸ Vocabulary: a screen is
a screen. The sweep — including each catalog's own rule-2 run,
which the English ruling does **not** decide — is #865.

### Why there is no per-locale word list here

A table of winning words per locale would be a copy of the
corpus, and a copy rots against it on any commit, while rule 2
makes the catalog **its own register**: a translator settling
*layout* in `pt-BR` greps `pt-BR.json` and gets today's answer.
So this page states the **procedure**, not its output.

### What is guarded, and what is not

**No content-guard predicate can hold this family.** A
banned-rival register — per locale, per concept, the winner plus
the words that must not appear — would fire on correct copy,
because **every ruling above produced a keep-list, and each entry
is the rival word, correctly used, in the same file**: `es`'s
«espacio», `it`'s «spazio» and `pt-BR`'s «espaço» name a Space in
roughly a hundred keys each; `ko`'s 연결 means *connected* in
eleven; `zh-Hans`'s 配置文件 is right in exactly the key the
ruling exists to protect. A guard failing on correct copy is the
one failure that makes an exemption file look necessary, and
`scripts/localization_guards.py` has no exemption file by policy.

**One sub-class is exactly checkable, and is checked.** Where the
collision is byte-identity rather than near-synonymy, you compare
two strings the same catalog already ships, which is what
`SidebarCrossReferenceTests` does for breadcrumbs.
`DestinationNameCollisionTests` reds when a `destination.*` title
equals some other key's value in any catalog and the two English
strings differ — ladder rule 1 in its sharpest form, and the
shape that shipped `zh-Hans`'s Profile as the words for
*configuration file*. It lives in `Tests/` rather than in the
guards script because a Swift suite may carry a reasoned
`allowed` map, so the one legitimate pair
(`Shortcuts` / `Your shortcuts`, which `ja` and `ko` rightly
render alike) is excused in writing instead of forcing the guard
off.

It covers only exact equality against a destination. `es`
labelling a bar gap "Espacio" against a Space of "Espacios" is
the same defect and is invisible to it — near-equality cannot be
judged without per-language morphology, which is the vocabulary
the suite refuses to carry. Do not read a green run as more.

Two of the three defect classes are nevertheless machine-held,
by making them unwritable rather than by scanning for them:

- **A `▸` breadcrumb** must equal what each segment's own key
  renders to (`SidebarCrossReferenceTests`). No vocabulary list,
  no false positives — both sides are strings the same catalog
  ships.
- **Prose that names a pane, a button or a role** interpolates
  that label's key rather than quoting it as text (#818), so
  `placeholder_drift` — an exact contract that already runs —
  holds the anchor in every locale. The shape it closes: `it`
  drifting to «sezione Abbreviazioni» while the pane reads
  "Scorciatoie", or `spaces.delete_confirm.message` quoting a
  "Main" role that has no label key, so that three locales invent
  one each.

What is left — one language's two ordinary words for one idea —
stays with review. The ladder makes that review cheap: once the
winner is named, auditing a catalog is one grep per concept, and
a reviewer who does not speak the language can check it, because
the keep-list names the English each rival is correctly
rendering.

## Why the guards are opposite shapes

It is forced, not stylistic:

| | Family A | Family B | Family C |
|---|---|---|---|
| the name is | a coinage with no correct translation | a word with a different correct form per locale | not a name — an ordinary word of the language |
| it declares itself | by shipping untranslated everywhere | in its own picker key, per locale | nowhere; it has no key |
| so the guard can demand | the English be **present** | only that the English be **absent** | nothing — see Family C |
| exemptions needed | none | none — locales keeping English skip themselves | an exemption per correct use, which is why there is no guard |

The symmetric form for Family B — demand the locale's *own*
translation be present — cannot work: a correct Spanish
inflection like "las ventanas… flotarán" carries no noun
"Flotante", so it would flag correct copy. That **no** guard is
possible does not follow from that: the defect is invisible to a
reviewer reading a language they do not speak, so a family left
to review alone accumulates the errors a guard would have named.

## Adding a name

Apply the catalog question, then:

- **Family A** — add it to `PRODUCT_NAMES`. Obligation scales with
  *authored English mentions*, not list length, so it binds only
  the keys whose English already contains it.
- **Family B** — add its `layout.<mode>.name` key to
  `MODE_NAME_KEYS`.
- **Family C** — add nothing. There is no register to join and no
  guard to arm; the ladder in that section is the whole policy.
  What a Family C concept *does* owe is a sweep: settle its word
  per locale and apply it across that whole file, in the change
  that introduces the concept.

A **product-coinage decision may override a Family-B catalog
reading** — the catalog question sorts what *already exists*, but
a name can be coined into Family A even when some locales had
translated it, provided (i) the descriptive-occurrence check
below passes and (ii) those locales are reharmonized to keep it
verbatim in the same change, so the catalog question agrees
*afterward* (#579, **Sticky**). The override is one-time: once
reharmonized, the catalogs are the test again.

**A name that can occur for a _different_ thing does not belong in
Family A.** The check is case-insensitive substring, so it cannot
tell a referential mention from an unrelated one — and the
substring reach means morphological variants inherit the
obligation automatically (`keybinding.make_unsticky` "Make
unsticky" already demands verbatim "Sticky", which every locale
honors). The two bar names are two-word coinages that only ever
occur referentially, so the question never arises for them.
**Sticky** is the single word where it had to be asked: all 17
keys (21 occurrences) in `en.json` carrying `sticky`/`Sticky`
name *this* feature, none a different one — unlike
`app`/`space`/`bar`, common words that needed the per-token
glossary carve-outs. The collision to keep re-checking is macOS's
own **Sticky Keys** accessibility feature: if a
`system_shortcut.*` conflict string ever surfaces "Sticky Keys",
this guard would demand KiwiDesk's "Sticky" be kept verbatim
inside a correctly-localized *Apple* name (`de`
"Einrastfunktion"), a false positive with no signpost back here.
Re-grep `system_shortcut.*` for "Sticky Keys" before adding a
single-word Family A member, and again when the shortcut corpus
grows. A name built from *ordinary* words would fire on copy that
was never naming the feature, so the rule holds: argue a name in,
never add one to silence a hit.

## The Settings-mode pair: Simple / Power User

Neither family covers the Settings window's depth switch
(#678 turn 9), so its policy is stated here (owner ruling
2026-08-04): the English pair is **"Simple" / "Power User"**, and
**both names translate by meaning** — each locale picks natural
words for an "easy" versus "power-user" register; neither is a
verbatim coinage. No content guard enforces this pair (nothing to
hold verbatim, nothing to hold absent).

The marketing site's slider is a **different surface with its
own flair** — it says "Nerd" (`site/src/i18n/<locale>.json`,
keys `mode_simple` / `mode_dev`) and keeps it; do not
"harmonize" the app onto the site's register or vice versa.
The app's case name is `.powerUser`, matching the label; it is
never the site's word. A translator drafting `mode.simple` /
`mode.power_user` may read the site's pair for their locale as
context, but translates the app's own English.

## See also

- [Translating](translating.md) — the full translator guide,
  including the other five content guards.
- [Design Decisions](design-decisions.md) — the rest of the
  settled product and UX decisions.
