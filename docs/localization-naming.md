---
title: Feature Name Policy
description: Which KiwiDesk names stay English in every language, which each locale renders in its own words, and the rule that decides.
---

# Feature name policy

Some KiwiDesk names are the same in every language — "App Bar",
"Space Bar". Others are different in almost all of them — the
layout modes. A third group is not a name at all, but an ordinary
word a language may have two of — *layout*, *gap*, *profile*.
This page is the one place that says which is which, what each
family requires of a translation, and why the first two are
enforced by opposite-shaped guards while the third is enforced by
nothing.

It exists because getting this wrong is invisible: prose naming a
feature the interface does not call that reads perfectly to
anyone who does not have both the string and the screen in front
of them, and search made it worse — a destination name is now a
breadcrumb segment, so an invented name appears on every hit
inside that pane.

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
*gap*, *profile*, *shortcut* — has no label key of its own, so
the question has nothing to read. That absence is what defines
the third family, and it is checkable the same way: if you cannot
name the key whose value is the name, you are in Family C.

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

**App Bar**, **Space Bar**, and **Sticky**. `bars.switch.app_bar`
and `bars.switch.space_bar` are Latin in all eleven catalogs, so the
control every user taps says "Space Bar" whatever their language.

**Sticky** (#579) is the first **single-word** and the first
*added* member — it did not arrive here by the sort question (`de`,
`ru`, `zh-Hant` had translated it to "Fixierung"/"Закреплённое"/
"常駐", so the catalog test read Family B), but by the product
decision to coin it verbatim the way the bars were, which Core
already reflects (`design-decisions.md` calls it "the settled
user-facing term"). Before admitting a single word, the
descriptive-occurrence check below was run: all 17 keys (21
`sticky`/`Sticky` occurrences) in `en.json` name this exact
feature — there
is no incidental "sticky" in ordinary prose to false-positive on
(unlike `app`/`space`/`bar`, which are common words and needed the
per-token glossary carve-outs). Its display tier is **"Display
Sticky"** (German **"Display-Sticky"**), "display" being an ordinary
qualifier that compounds per locale around the fixed "Sticky" atom.

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

Descriptive use is not naming, and case is how the guard tells
them apart: it matches the capitalised form alone. This is a
**heuristic, not a rule the English follows** — `en.json`
capitalises in labels that name no picker entry ("Stack
position", "Track limit") and lower-cases some referential uses
("the track layout"). It is cheap and right on the corpus today;
it is not a guarantee, and a name whose English is lower-cased
everywhere would slip past it. So "la modalità floating"
describes behaviour and is free, while "la disposizione Floating"
names a picker entry that reads "Fluttuante" and is not.

**Known blind spot: the check runs in one direction only.** It
fires where a picker is translated, which today means the three
CJK locales. The seven that keep the English names skip
themselves — which is what removes the need for an exemption
list, and equally means nothing checks *their* prose against
their own picker. The mirror defect is therefore invisible: a
German caption reading "Schwebend" beside a picker reading
"Floating" passes. Those locales are held by review, and by
`LocalizationModeNamePolicyTests` only at the label level.

**And that blind spot shipped, which is what added the rule
below.** `de` carried "IDE-Stapel" and "scrollende
Dokumentation" in three preset summaries beside pickers reading
"Stack" and "Scrolling" — while keeping "Monocle" in the very
next key, so one file translated one mode word and not the next.
Ten catalogs each reconciled it alone. Review had not caught it
in the time it existed.

**So English prose does not name a layout mode either.** The
remedy is not a better predicate over the translations — the
polarity above is why none can exist — it is that the source
stops handing translators a mode word to decide about. A
sentence that needs to name a layout interpolates
`layout.<mode>.name`, which every catalog already renders under
the policy this section pins; prose that merely describes what a
Space is *for* names no mode at all.

This is a Family B sub-rule rather than a section of its own,
because it is the same fact from the authoring end: mode names
are values, and a value belongs in a slot rather than in a
sentence. It binds the **English** author first, which is the
general form of it — one concept, one word, decided in `en`
before any catalog can disagree.
`PresetSummaryVocabularyTests` holds the one corpus where it has
bitten (`presets.*.summary`), deriving its ban list from
`layout.*.name` so a renamed or added mode cannot slip past it;
a second family of prose that names layouts owes its own guard,
that one being scoped to preset summaries.

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
screen — and the two words land on the *same card*, since the
picker entry and the help text under it are adjacent surfaces.

**Do not sort it with Family C's ladder.** Family C is the family
with no label key to read (*The question that sorts a name*);
this concept has one, so the sort is already answered and Family
B governs. Running the ladder anyway decides it against the name
every time: rule 2 counts occurrences, and the unit outnumbers
the picker entry by construction — the owner ruling of
2026-08-29 settled **Track** after `fr`, `es`, `pt-BR`, `ru` and
`zh-Hant` had each reached for a noun of their own that
outnumbered the "Track" their pickers already shipped.

**Where the derived name will not go into your sentence, say so
rather than smoothing it over.** An indeclinable Latin noun in an
inflecting language can leave a construction the grammar cannot
build — Russian lost the genitive that disambiguated "the size of
the window's Track", and had to gain a plural verb to carry a
number the noun could no longer mark. Rewording around that is
part of the obligation, not licence to bring the second word
back. If nothing rewords, the escape is Family B's own and is a
ruling rather than a translator's call: your picker may translate
the mode name, after which the unit follows it there instead.

**One half of this is guarded, and it is the same half as the
rest of Family B.** `untranslated_mode_names` fires when a
catalog whose picker translates the mode keeps the English name
anyway, which catches a translated-picker locale writing "Track"
for the unit — capitalised only, since that is how the predicate
tells naming from description. The mirror — a locale whose picker
keeps English writing its own word for the unit — is invisible to
it for the polarity reason *Known blind spot* gives above, and no
predicate can be built for it, because the unit's rival word is
correct prose somewhere. That half is review's, and it is where
every case ruled so far was found.

**A new mode joins no register for this.** The rule reads
`layout.<mode>.name`, which `MODE_NAME_KEYS` already carries.
What a new mode owes is the sweep: settle the unit's word in
every catalog in the change that names the unit, rather than
leaving ten translators to reach for ten nouns.

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

## Family C — the common nouns

*Layout*, *gap*, *profile*, *shortcut*, *preset*, *slot*. Words
KiwiDesk did not coin and does not display as a name of their
own — they only ever appear inside a sentence about something
else.

Families A and B are about what a *feature* is called. Family C
is about what happens when one language has two ordinary words
for the same idea and a translation reaches for both. The user
learns the word on one page and does not recognise it on the
next; search finds one surface and not the other. It falls
between adjacent surfaces most of the time — a tab bar and the
help text under it, a destination label and the menu item that
opens it — which is exactly where it is noticed.

### What it requires

**One concept, one word, per catalog.** When you meet a concept
this file does not name, decide it with the ladder below and
apply your answer everywhere in your file, not only in the key
you were editing.

1. **A word that already names another KiwiDesk concept in your
   catalog loses, whatever its count.** This outranks everything
   else, because a label that reuses another feature's noun does
   not read as inconsistent — it reads as *true about the wrong
   thing*. `zh-Hans` labelled a Profile 配置文件, which is what
   `general.advanced.config_file` renders, so searching for a
   profile returned a result whose kind line said *configuration
   file*. `es`, `it` and `pt-BR` each labelled a bar gap with
   their word for a **Space**. `ko` labelled a bound key with its
   word for *connected*, beside a card counting connected
   displays. `ja` had no word of its own for a Space at all: the
   majority reading was Apple's own 操作スペース, the term for
   the macOS Desktop that KiwiDesk's Spaces are deliberately not.
2. **Otherwise your catalog's own occurrence count decides.**
   Grep your file for both candidates; the one already carrying
   the concept wins and the other is swept to it.
3. **Within about ten percent, the destination label or picker
   entry decides.** That string is a card title, a back-chip
   heading and a search kind-line at once, so it is the name the
   user actually learns.
4. **Your ear does not override 1–3.** Awkwardness is an argument
   for a different winner under rule 2, never for keeping a second
   word.
5. **Where the rivals are verbs for different OBJECTS, the one
   that names the right object wins — ahead of count** (owner
   ruling, 2026-08-29). `es` split *aumentar* (increase a
   quantity) against *agrandar* (enlarge a window), and `fr`
   *augmenter* against *agrandir*, with the quantity verb ahead
   2–1 only because it sat on two keybinding rows. Counting
   picked the word for the wrong kind of thing, and a tie-break
   is the wrong tool for a distinction that is not a tie.

   Rule 2 still governs where both rivals name the same object —
   that is most splits, and it is why the register stays the
   catalog rather than a table.

   **Its residue is an ENGLISH problem, and the sweep does not
   fix it here.** These labels' grammatical object is a dimension
   (*Agrandar la altura*), so the winning verb reads a shade
   less naturally at the very sites it was chosen for. The fix is
   a label whose object is the window, not a second verb —
   which is exactly what rule 1's escape says about nouns, one
   part of speech over.

A rival word is usually still *correct somewhere else in the same
file* — `it`'s «disposizione» renders English *arrangement* in ten
keys, `ru`'s «раскладка» is also a keyboard layout, `es`'s
«espacio» is a Space in a hundred keys. So this is never a
search-and-replace, and a sweep that changes a concept ships with
the list of keys it deliberately left alone.

### When rule 1 takes the word you needed

Rule 1 says a word naming another KiwiDesk concept loses. That
leaves a real question it does not answer: what does the *losing*
site call the thing now? The tempting answer — reach for a second
ordinary noun — is the exact defect this family exists to stop,
so the escape is ranked too. Take the first that fits.

1. **Check the destination label is faithful before working
   around it.** Where the English destination carries a
   qualifier and your catalog rendered it bare, the collision is
   the *destination's* defect, not a shortage at the ordinary
   site. Restore the qualifier and the bare noun is free again.
   `destination.layout` is the worked case: English is "Layout
   **Defaults**", and `fr` and `ru` had rendered it bare
   ("Dispositions", "Раскладки"), which left the preset card's
   own button reaching past the word it wanted — "Voir les
   dispositions", "Раскладки набора". Restoring the qualifier
   in both let each button collapse to the bare noun.
2. **Where English's own destination IS the bare noun** —
   Profiles, Spaces, Bars, Shortcuts — the shortage is real.
   Then **the ordinary site qualifies and the destination never
   moves.** The destination label is the name the user learns,
   which is rule 3's whole reason; moving it to make room for a
   body string spends the one string that has to stay stable.
3. **Prefer the shortest qualified NOUN phrase to a verb
   phrase** wherever the site is a control whose width is
   measured. A verb phrase can only grow; a qualified noun
   collapses back to the bare noun the moment step 1 frees it.
   `.claude/rules/localization.md` ▸ *an ACTION label must fit
   its control* owns the width half, including the obligation to
   re-measure a pair when a control joins a row.
4. **Never coin a second bare noun for the concept.** That is
   the defect the ladder exists to stop, and step 2 is where it
   is tempting.

`DestinationNameCollisionTests` holds only the byte-identical
case — it is what makes the collision *visible*, not what
resolves it. Steps 1–4 are review's, like the rest of this
family.

**One concept is ruled and deliberately unswept**: the physical
screen, where English carries three words. The winner is
`screen`, `display` is reserved for quoting Apple's own controls,
the English-side obligation is
`.claude/rules/config-vocabulary.md` ▸ noun glossary, and the
argument is `docs/design-decisions.md` ▸ Vocabulary: a screen is
a screen. The sweep —
including each catalog's own rule-2 run, which the English ruling
does **not** decide — is #865.

### Why there is no per-locale word list here

The obvious shape for this section is a table: eleven columns,
one row per concept, the winning word in each cell. It is the
wrong shape. That table would be a copy of facts the corpus
already holds, and a copy of the corpus rots against it on any
commit — while rule 2 makes the catalog **its own register**. A
translator settling *layout* in `pt-BR` greps `pt-BR.json` and
gets today's answer; a table would give them the answer as of
whenever someone last edited this page.

So what is written down is the **procedure**, which cannot go
stale, rather than its output, which can.

### What is guarded, and what is not

**No content-guard predicate can hold this family.** The natural
one is a banned-rival register — per locale, per concept, the
winner plus the words that must not appear — and the reason it
cannot be built is worth stating so nobody budgets for it twice:
**every ruling above produced a keep-list, and each entry is the
rival word, correctly used, in the same file.** `es`'s «espacio»,
`it`'s «spazio» and `pt-BR`'s «espaço» name a Space in roughly a
hundred keys each; `ko`'s 연결 means *connected* in eleven;
`zh-Hans`'s 配置文件 is right in exactly the key the ruling exists
to protect. A ban would fire on all of them. This page's own rule
about single-word Family A members applies with more force here:
*a guard failing on correct copy is the one failure that makes an
exemption file look necessary*, and
`scripts/localization_guards.py` has no exemption file by policy.

**One sub-class is exactly checkable, and is checked.** Where the
collision is byte-identity rather than near-synonymy, no
vocabulary is needed at all — you compare two strings the same
catalog already ships, which is what `SidebarCrossReferenceTests`
does for breadcrumbs. `DestinationNameCollisionTests` reds when a
`destination.*` title equals some other key's value in any
catalog and the two English strings differ. That is ladder rule 1
in its sharpest form, and it is the shape that shipped
`zh-Hans`'s Profile as the words for *configuration file*. It
lives in `Tests/` rather than in the guards script for a reason
that matters: a Swift suite may carry a reasoned `allowed` map,
the standing idiom across a dozen AGENTS.md §5 rows, so the one
legitimate pair (`Shortcuts` / `Your shortcuts`, which `ja` and
`ko` rightly render alike) is excused in writing instead of
forcing the guard off.

It covers only exact equality against a destination. `es`
labelling a bar gap "Espacio" against a Space of "Espacios" is
the same defect and is invisible to it — near-equality cannot be
judged without per-language morphology, which is the vocabulary
the suite refuses to carry. Do not read a green run as more.

The shape argument, stated once so the gap does not read as an
oversight: Family A can demand the English name be **present**,
because it has no correct translation. Family B can demand the
English name be **absent**, because the picker key is a
per-locale declaration a predicate can read. A common noun
supplies neither declaration — having no label key is what put it
in Family C — so there is nothing in the file to compare against.

Two of the three defect classes are nevertheless machine-held,
by making them unwritable rather than by scanning for them:

- **A `▸` breadcrumb** must equal what each segment's own key
  renders to (`SidebarCrossReferenceTests`). No vocabulary list,
  no false positives — both sides are strings the same catalog
  ships.
- **Prose that names a pane, a button or a role** interpolates
  that label's key rather than quoting it as text (#818), so
  `placeholder_drift` — an exact contract that already runs —
  holds the anchor in every locale. `it` had drifted to «sezione
  Abbreviazioni» while the pane read "Scorciatoie", and
  `spaces.delete_confirm.message` quoted a "Main" role that had
  no label key at all, so three locales invented one each.

What is left — one language's two ordinary words for one idea —
stays with review. The ladder above is what makes that review
cheap: once the winner is named, auditing a catalog is one grep
per concept, and a reviewer who does not speak the language can
check it, because the keep-list names the English each rival is
correctly rendering.

## Why the guards are opposite shapes

It is forced, not stylistic:

| | Family A | Family B | Family C |
|---|---|---|---|
| the name is | a coinage with no correct translation | a word with a different correct form per locale | not a name — an ordinary word of the language |
| it declares itself | by shipping untranslated everywhere | in its own picker key, per locale | nowhere; it has no key |
| so the guard can demand | the English be **present** | only that the English be **absent** | nothing — see Family C |
| exemptions needed | none | none — locales keeping English skip themselves | an exemption per correct use, which is why there is no guard |

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
- **Family C** — add nothing. There is no register to join and no
  guard to arm; the ladder in that section is the whole policy,
  and it reads the catalogs rather than a list. What a Family C
  concept *does* owe is a sweep: settle its word per locale and
  apply it across that whole file, in the change that introduces
  the concept, rather than leaving a second word for the next
  round to find.

A **product-coinage decision may override a Family-B catalog
reading** — the catalog question sorts what *already exists*, but a
name can be coined into Family A even when some locales had
translated it, provided (i) the descriptive-occurrence check below
passes and (ii) those locales are reharmonized to keep it verbatim
in the same change, so the catalog question agrees *afterward*. That
is exactly what #579 did for **Sticky** (`de`/`ru`/`zh-Hant` had
translated it). The override is one-time, not a standing exception:
once reharmonized, the catalogs are the test again.

**A name that can occur for a _different_ thing does not belong in
Family A.** The check is case-insensitive substring, so it cannot
tell a referential mention from an unrelated one — and the
substring reach means morphological variants inherit the obligation
automatically (`keybinding.make_unsticky` "Make unsticky" already
demands verbatim "Sticky", which every locale honors). The two bar
names are two-word coinages that only ever occur referentially, so
the question never arises for them. **Sticky** is the single word
where it had to be asked: a grep found all 17 keys (21 occurrences)
carrying `sticky`/`Sticky` name *this* feature, none a different
one. The real collision to keep re-checking is not "sticky note" —
it is macOS's own **Sticky Keys** accessibility feature: if a
`system_shortcut.*` conflict string ever surfaces "Sticky Keys",
this guard would demand KiwiDesk's "Sticky" be kept verbatim inside
a correctly-localized *Apple* name (`de` "Einrastfunktion"), a false
positive with no signpost back here. The corpus is clean today; when
system-shortcut strings are added, re-grep `system_shortcut.*` for
"Sticky Keys" specifically. That re-check is the price of a
single-word Family A member — run it before adding one, and again
when the shortcut corpus grows. A name built from *ordinary* words
would fire on copy that was never naming the feature; a guard
failing on correct copy is the one failure that makes an exemption
file look necessary, so the rule holds: argue a name in, never add
one to silence a hit.

## The Settings-mode pair: Simple / Power User

Neither family covers the Settings window's depth switch
(#678 turn 9), so its policy is stated here directly (owner
ruling 2026-08-04): the English pair is **"Simple" / "Power
User"**, and **both names translate by meaning** — each locale
picks natural words for an "easy" versus "power-user"
register; neither is a verbatim coinage. No content guard
enforces this pair (nothing to hold verbatim, nothing to hold
absent); this ruling is what keeps ten translators from
diverging.

The marketing site's slider is a **different surface with its
own flair** — it says "Nerd" (`site/src/i18n/<locale>.json`,
keys `mode_simple` / `mode_dev`) and keeps it; do not
"harmonize" the app onto the site's register or vice versa.
The app's case name is `.powerUser`, matching the label; it is
never the site's word. A translator drafting `mode.simple` /
`mode.power_user` may still read the site's pair for their
locale as context, but translates the app's own English.

## See also

- [Translating](translating.md) — the full translator guide,
  including the other five content guards.
- [Design Decisions](design-decisions.md) — the rest of the
  settled product and UX decisions.
