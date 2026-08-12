---
title: Settings UI Patterns
description: The shared control conventions every Settings surface follows.
---

# Settings UI patterns

The cross-cutting control conventions of KiwiDesk's Settings
app — extracted from [Design decisions](design-decisions.md)
so feature pages stay about features. Audience: anyone building
or reviewing a Settings surface. The GUI north-star these serve
(simplicity, intuitiveness, Apple-native feeling, in that
order) is defined in `AGENTS.md` §2. Entries are cross-cutting
conventions; the layout-editor entries are included because
they span all seven layout editors, not one pane.

## Help & cross-references

**Per-field help is a click popover behind a `?` right after
the label, not a hover tooltip (#94).** Rows that warrant a
sentence of explanation carry a small `questionmark.circle`
button **immediately after the field's label text, inside
the shared `settingsLabelColumn`**. The question is born at
the label ("what is *Width split ratio*?"), so the
affordance sits where the confusion starts — not past a
control the user has already scanned in confusion.
Owner-tested twice: the first cut (far trailing edge) and
the second (snug after the control) were both anchored to
the wrong end of the row. This is also System Settings' own
info-glyph convention (Focus/Siri panes put it beside the
label). `labelColumn` grew 128 → 150 pt to hold the longest
label plus the glyph; a long label + glyph truncates visibly
(`lineLimit(1)`) — the accepted fallback, and long German
labels on help rows are shortening candidates for the de
review pass. An *unlabeled* `SegmentedPicker` (icon tabs)
has no label to sit beside, so its `?` trails the track.
The button wears the shared `hoverHighlight` chip like
every other icon-only borderless control, so the eye has
something to catch.
Clicking opens a fixed-width popover; `.help()` rides along
as a hover fallback carrying the full text, while the
VoiceOver hint stays a short action phrase ("Shows an
explanation of this setting") — the content is read inside
the popover after activation, so a full-text hint would
announce it twice. A popover, not hover-only `.help()`, because that is
what System Settings does for explanations: a visible,
discoverable glyph; a real focusable button (keyboard and
VoiceOver reach it); dismissible and re-readable — while
hover tooltips are single-line-biased, keyboard-inaccessible
and invisible to anyone who never rests the pointer.
`.help()` remains the idiom for one-line hints on ambiguous
*icon-only controls*. A field with 2–3 named options folds
per-option text into the ONE field-level popover (option
name bold, one line each) — never a `?` per segment. Two
scope guards: help is optional reading (a label must stay
understandable without it — must-know info never lives only
in the popover), and a field already taught by its live
preview or schematic (App Bar colors, a layout card's
geometry) gets no `?` at all.

**A concept goes in the `?`; a live fact goes in the flow.**
The split is what each surface can promise. A popover's copy
is fixed for every reader, so it holds what is always true of
the setting — what the thing *is*, what turning it off costs.
A statement that turns on the current value of something else
("the Space Bar is off right now") would be wrong for half
the readers, so it belongs in a caption or a
`CrossReferenceRow` that re-renders with the state. The
corollary is the one that bites: delete a live cue and its
fact does not fall back into the `?` — check whether the
timeless half of it was ever written there.

Copy is a normal `L()` string
under the `<key>.help` suffix convention; when a *label* key
is shared by fields with divergent semantics (Stack's and
Track's Overflow both use `layout_params.overflow`), the
help key scopes itself (`layout_params.overflow.stack.help`)
so each field can carry its own text. Shared help copy —
one string rendered on two surfaces, like a Layout Defaults
layout card and the per-space override editor — is authored
once in a per-domain namespace (`LayoutHelp`); single-call-site
copy stays inline at its call site (namespace membership =
2+ call sites, or an override pair like
`newWindowPlacement`/`trackPosition` — not "it felt
shared"). In the per-space override editor the `?` is rendered
by `OverrideChrome` itself, not the wrapped row, so it stays
clickable while the row inherits — help must work exactly
while the user decides whether to override. Accepted
consequence: there the `?` sits at the chrome row's
trailing edge (past the inner row's spacer, a small
distance in the bounded rows column), consistently for every
override row — the deliberate exception to label-adjacent
placement, since the label lives inside the disable-able
content, the checkbox-narrowed column has no width to
spare, and the user already met the field (with its
label-adjacent `?`) on the global surface. Do not "fix" it
back inside the row: that re-enters the disabled scope.

**"Lives elsewhere" pointers are links, and the link sits
where the sentence puts it.** Prose that names another tab
("configured in the App Bar tab") is a dead end; those
pointers are `CrossReferenceRow`s, jumping the pushed-area
selection through an injected `settingsNavigate` environment
action.

The destination's name is a **positional specifier** in the
prose key, filled with `CrossReferenceRow.linkSlot`, so a
translation may place it wherever its own word order wants.
It is not appended after the sentence: a row that renders
`Text(prose)` and then a link as siblings can only ever park
the name at the end, which forces every key to be authored
dangling ("… — edit them in") and is the same defect as a
`+`-concatenated fragment, with a view doing the stitching.
Five locales had already ended these captions on a colon or
a bare preposition before this was fixed.

Resting style is an underline in the caption's own secondary
grey — never the system link blue, since these are prose the
reader may follow rather than calls to action — lifting to
primary under the pointer, which is `linkHover()`'s treatment
for the tree's other inline links (the make-default link, the
rename pencil). One idiom, two implementations: a
`CrossReferenceRow` renders through `LinkedCaption`, an
`NSTextView` bridge, because SwiftUI's `Text` gives a `.link`
run no pointing-hand cursor and because `NSLayoutManager` is
what breaks lines correctly around a name sitting mid-sentence
in a language that does not break on spaces. That view owes
its own keyboard activation, focus ring and accessibility
child — a `Button` gave those away free and an `NSTextView`
gives none of them.

A pointer whose sentence names a **location** takes a
breadcrumb headed by the destination's own title
("Bars ▸ App Bar"), not the section name alone: a link
reading "App Bar" names no card Home shows, and only a
`▸`-shaped value enters `SidebarCrossReferenceTests`. A
pointer whose sentence names the **feature itself** rather
than where to find it — a sentence turning on whether the
Space Bar is on, say — links that mention instead and stays
one segment. No shipped row takes that form today; all three
`CrossReferenceRow` call sites name a location. It is kept as
a convention because the choice is the sentence's to make: a
pointer forced into a breadcrumb when its prose already names
the thing reads as a second, redundant mention.

## Choosing a control

**Segmented vs. menu is decided by a rule, not per row
(#291).** A pick-one control is a `SegmentedPicker` when the
choices are a *fixed set of 2–4 peers*, every label stays
short and untruncated at the minimum Settings width **and**
in the longest shipped localization, and seeing all choices
at once helps the decision. It is a **menu** (`DropdownRow`)
when any of: five or more choices; dynamic or user-generated
choices; long, explanatory, or localization-risk labels; or
a constrained repeated surface where showing every choice
would crowd or truncate. A binary is a **toggle**, never two
segments. Fixed editor-navigation tabs (the icon picker's
Emoji / Symbol / Glyph strip) may exceed four — they switch the
visible editor rather than edit a value, so the count cap
doesn't apply. Layout Defaults' layout selector used to be the
other instance and is no longer a segmented control at all: it
became a strip of live schematic thumbnails, on the argument
that seven layout NAMES are the one label a beginner cannot
read (#678 turn 10, argued in
[Design decisions](design-decisions.md)). The exemption is
about editor navigation, not about that surface — a future
navigation strip past four segments still qualifies.
The *same semantic field uses the same control on comparable
full-width surfaces*: the two bar cards both render Position /
Background style / Active indicator as segments, so the
two never sit adjacent showing one field two ways. The #291
audit applied the rule across every editor — converting the
App Bar fields, Stack's Master
orientation / Stack position / Overflow, Track's Overflow,
Drag's Border alignment (which itself left the GUI in #754,
GUI_REMOVED_2026-08), and Corners (which #754 lifted out of
the Focus border card to drive all three strokes) — and
kept menus where the rule keeps them:
new-window placement (comparative labels), the seven-option
Space layout mode, and the dynamic Language and
Desktop→Profile lists.

*Verified against all ten locales when #95 landed.* Every
shipped segmented strip fits the ~650 pt a full-width row has
at the 840 pt minimum: the widest is Mouse resize action at
~503 pt (`es`, "Redimensionar las ventanas contiguas"),
followed by App Bar active indicator at ~408 pt (`fr`). So the
rule's "longest shipped localization" clause holds as written,
with real headroom. Re-measure a strip before adding a fourth
segment to one of those two — they are the ones with the least
room left.

**The per-Space override rows keep menus, not segmented
controls (#291).** The override editor is now a full pushed
pane (#678 8b, no longer the #205 popover), but its rows still
sit in a **bounded ~520 pt column** with a trailing OVERRIDE
checkbox column (`overrideStateColumn`, 64 pt) and the
`OverrideChrome` accent bar eating horizontal width, so a
2–4-peer field has no room for a segmented render.
`OverridePickerRow` renders `.menu` for that reason — since the
per-layout bar overrides left the GUI (GUI_REMOVED_2026-08) the
per-space editor is the only override surface, so the row's old
`.segmented` branch went with them. The bounded column, not the
old popover width, is now the constraint; restore the
required-style parameter only if a genuinely *full-width*
override surface later arrives. The inherited (unchecked) state
collapses to a quiet "follows `<Layout>` defaults · `<value>`"
readout (the slot-size pair keeps its live control instead,
dimmed via the chrome's `.disabled` + `.opacity(0.5)`). App Bar
Content
("Icon &amp; name" → German "Symbol &amp; Name") is the one
segmented label tight enough to warrant a real render at
minimum width; kept segmented by width headroom, it is a
truncation candidate to re-check when each new locale ships
(#95), the same recurring de-review discipline the help-glyph
labels already carry.

**Numeric controls pick one of three idioms by a single
test.** So Settings reads consistently, a numeric setting's
control is chosen by *would a user say a specific number out
loud?* — not by which pane it lives in:

- **`StepperRow`** (typeable field + arrows) for discrete,
  exact values a user names: counts, ms durations, pt
  thresholds — master count, columns/rows, track limit,
  minimum window size, animation duration.
- **Slider + readout** (no typing) for a continuous feel or
  proportion tuned by eye: split ratios, master ratio, gaps.
- **Segmented / toggle** for a non-numeric choice.

Minimum window size migrated slider → `StepperRow` on this
rule (#204): it is a precise pt threshold, not a feel knob.
**Layout Defaults picks one layout at a time, and picks it by
its picture (#204, #678 turn 10).** The layout modes are a
fixed, small, mutually-exclusive set (`LayoutMode` minus
Floating), so one mode's editor is visible at a time instead of
every mode stacked in one `ScrollView`. What selects it is a
strip of **live schematic thumbnails**, not a segmented strip of
words: the words are ones only a tiler user knows, so on the
page where a beginner is most lost the drawing is the label —
each tile also carrying the count of spaces using it, so an
unused layout is visibly not worth tuning. The strip lands on
the profile's most-used layout. The global minimum window size
is pinned *above* the strip because it feeds every layout (and
gates the `OverlapStack` overflow cascade), so it belongs to
none of them. The formerly bundled `LayoutParamsEditor`
(BSP+Stack) and `ScrollGridEditor` (Scrolling+Grid) were split
at the mode boundary; since turn 10 the rows come from the
settings census and one `LayoutCard` renders whichever layout
is selected.

## Shared visual language

**A section or disclosure title is sentence case** — "On quit",
"Drag & drop", "Move windows", not "On Quit" or "Drag & Drop"
(R5, #406). It was already the large majority, and it is what
macOS System Settings uses for its own in-pane headers; the
alternative (normalizing *up* to Title Case) would have touched
~25 strings instead of 6. This is a policy choice rather than a
fix, which is why it is written down: the next header follows the
rule instead of re-deciding it.

Three boundaries, because System Settings itself draws them:

- **The rule is scoped to headers** — `SettingsSection` titles
  and the `.headline` labels of an "Advanced" disclosure. The
  **`SettingsDestination` titles (Home cards, back-chip
  headings) stay Title Case**
  ("Layout Defaults", "App Rules"): they name a destination, as
  System Settings names its panes. So do **action labels**
  ("Open New", "Set Gap Values") — a verb-phrase command follows
  the menu-item convention, not this one.
- **`&` does not start a new sentence**: "Size & float", "Drag &
  drop". The word after the ampersand is the one a sweep will
  miss, and did (#406 review).
- **Capitalize only what a sentence would.** A proper noun stays
  ("Lua bindings"); an acronym stays an acronym ("BSP").
  KiwiDesk's own **named surfaces keep their caps** — the App Bar
  and the Space Bar are things ("Space Bar colors") — while a
  feature that is just its noun does not ("Focus border").

**"Advanced" prefixes a disclosure's noun only when a basic tier
of that same noun is visible above it; otherwise the drawer is
named for what it holds** (R3, #406). So **"Lua bindings"** and
**"Monitor fingerprints"**, because there is no such thing as a
basic Lua binding or a basic fingerprint. The catalog above
Shortcuts' drawer is a different noun (*actions*), and Monitors
has no lesser fingerprint anywhere.

**A second condition joined the rule when the colour drawers
moved onto a page called Advanced Colors (#678):** the qualifier
also has to be unclaimed by the surface AROUND the drawer. The
bars' colour drawers used to satisfy the tier test — Fill and
Highlight sat one grid up, so "the advanced ones" was literally
what it meant — and the same drawers on the new page do not,
because the adjective now reads as the page's own name rather
than as a tier inside it. And a row tier and a mode depth must never
be spelled with one word: Advanced Colors is the deep-mode twin
of Colours & Motion (`SettingsArea.minimumMode` is `.powerUser`
there), so on that page "advanced" already means *which mode
you are in* and no drawer may re-use it to mean *which rows are
hidden*. They are **"More
colors"**, with the collapsed summary doing the naming the
adjective used to ("Plate, highlight, hover, badges"). "More"
cannot be misread as a mode.

The four had drifted onto four formats (bare, `Advanced: …`,
`Advanced — …`, and the unqualified "Advanced colors"), and the
first attempt at converging them — `Advanced <noun phrase>`, no
connector — only moved the drift: with no basic tier to contrast
against, the adjective re-scopes onto the noun and the title
promises a distinction the app does not make. A connector
(`Advanced: Lua bindings`) restores the tier reading but
re-splits the format, and cannot be stated in one sentence, so
it drifts again. Dropping the qualifier is the version that both
reads true and states itself.

**Nothing is lost by dropping it.** "Advanced" was standing in
for cues these drawers already carry: collapsed by default,
boxed, at the bottom of the page, under the thing a normal user
came for — and Shortcuts' own caption says it in prose ("the
power-user escape hatch"). The word was duplicating the caption
one line below it.

The bare "Advanced" (General) is untouched by the rule: no noun,
nothing to misparse, and it is the only advanced thing on its
page.

**An inline disclosure row leads with a hairline rule, and its
drawer opens into one sunken well.** The thin top rule is the
"different kind of row" signal that sets an accordion off from
the plain rows around it without promoting the drawer to a
card, and whatever the drawer reveals sits in a single well —
never one well per child. `SettingsDisclosure` draws both; the
ruling is in `docs/design-decisions.md`.

**Weigh every title edit against the search index.** Search
indexes destination titles, every census-labelled setting row
(`SettingsSearchIndex`, one row per `SettingKey`) and the
catalog's own controls — drawer titles, mode tabs — plus a
sparse English synonym table (`SettingsSearchSynonyms`,
match-only, never displayed). A word that appears in no other
indexed string still lives or dies with its title — a title
that reads better but drops such a word makes its own drawer
unfindable by the word a user would type. "Fingerprint" is in
that position today: "Monitor fingerprints" is the one indexed
string carrying it, which is part of why that title wins.
("Lua" no longer is — the init.lua rows in General and
Shortcuts carry it too — though results are per row now, so
the raw-Lua drawer still needs its own title's words to be
found at all.)
Per-instance rows (a space's own binding row) stay out by
design: their FAMILY is the setting, and the **Made by you**
group is how a named thing is found.

Localization splits here, and the split is the rule from §5:
R5's capitalization and R3's connector were **cosmetic**, so
German keeps its own typography ("Erweitert: …"). Dropping
"Advanced" changed the English **meaning**, so those two keys
took `scripts/drop-key` and re-queue for translation — see
`docs/translating.md`.

**A section title labels its rows visually; it does not label
them to VoiceOver.** A diagnostic readout row (Monitors'
fingerprint hashes) needs no visible per-row label when the
drawer above it is named for exactly that value — repeating the
word on every row was tried and read as noise. But the title is
spoken once while rows are stepped one at a time, so a bare hash
or id arrives with no context: give such a row a combined
`accessibilityElement` with an explicit `accessibilityLabel`
naming the value. Keep `textSelection` scoped to the value
itself, so copying for a support ticket yields the value alone.

Two things decide how far the combined element reaches:

- **Does the title name the value at all?** Monitors' drawer is
  titled "Monitor fingerprints", so its rows speak the display
  and the hash. The orphan-pin rows sit under "Pinned to
  disconnected monitors", which never says *fingerprint*, so
  their label carries both halves — the row's own sentence plus
  the monitor it is waiting for.
- **Does the row hold a control?** Combine the **readout only**,
  never the whole row. `children: .combine` folds interactive
  children in too, so wrapping a row that ends in a clear or
  edit button costs that button its own element — scope the
  combined element to the static run and leave the control a
  sibling.

**Option tabs are a solid sliding-pill segment control.**
Every pick-one-of-few chooser (layout parameters, mouse
resize, icon picker tabs) uses `SegmentedPicker`
instead of the native segmented picker: a capsule track
where the selection is a solid **accent** pill carrying the
on-accent ink — the accent-marks-control-fills convention.
The earlier white pill (light gray in dark) needed the
slider thumb's crisp shadow to lift off a same-luminance
track, its black shadow was dead in dark anyway, and in dark
its label was the worst text pairing in the control set; the
accent separates from the track by hue and luminance in both
modes with no shadow at all, and the selected state never
rides colour alone — the font step below carries it too.
The selected label is larger and semibold
— a real font-size step, because `scaleEffect` rasterizes
the text and reads as blur. Liquid Glass was tried in three
variants (bare, accent-tinted, clear + specular rim) and
dropped: bare glass over the flat settings background reads
as washed-out, tint reads as "blue, not glass", and the
glass layer blurs content near it. ONE persistent pill
slides between segments via matched geometry; styling
conditionally attached to the selected label proved to
crossfade on selection change (the view is destroyed and
recreated), so the pill is a single view that adopts the
selected segment's anchored frame. Segments are equal-width
across the track (full-bleed, like a native window-toolbar
switcher), a deliberate trade against content-sized
segments. One control, one look — a chooser reads as "pick
a tab" everywhere in the settings.

**Sliders share the pill design.** Every value adjuster
(ratios, gaps, sizes) is a `SettingsSlider`: the same capsule
track as the segmented picker, a native-style solid white
thumb that overhangs the track by 2 pt per edge, and a
full-strength accent fill up to the knob — the earlier
translucent fill read as disabled. A clear Liquid Glass
knob was tried and dropped: it refracted the accent fill
beneath it and turned blue. Accessibility is delegated to a
native `Slider` representation, so assistive tech sees
exactly the control it replaces.

**Buttons stay native; semantic role chooses their class.** No
gradients, borders, or shadows on buttons — the crisp shadow
is the slider thumb's alone, now that the segment pill is a
solid accent fill that needs no lift.
Class is expressed through native style + control size:
`.borderedProminent` regular for the one surface commit
(the save pill's Save, popover confirms); `.bordered` large for row
actions (Load, Apply, Customize, Set Gap Values), level with
large dropdowns; `.bordered` regular for stateful input
triggers (the shortcut recorder); and `.borderless` regular
for icon-only row actions (trash, ×-clear, rename). List-add
actions stay `.bordered`; `.plain` + underline is reserved
for inline prose links. Small controls are subordinate inline
or popover utilities (Shortcuts import, override resets), never
a normal row action. Native macOS shape differences between
these classes are intentional — choose by semantic role, not
by a desired silhouette.

**A recording shortcut field wears an accent halo.** The
armed recorder among dozens of identical rows gets an accent
fill + ring extending slightly past the button — the same
accent-layer vocabulary as `OverrideChrome`'s active rows —
because a tinted border plus a label swap alone was too
quiet to spot at list speed.

**Status badges stay flat.** The thumb's shadow is the
settings' vocabulary for "interactive, movable"; putting it
on a passive `BadgeChip` would promise interaction the chip
doesn't have. One mark sits outside both vocabularies: the
Monitors picture's main-display card wears a soft accent
bloom — decoration stating a fact, promising neither
interaction nor an armed input, and always beside the
textual "main" badge that carries the answer. Depth comes
from the hairline stroke both chip
types now share, matching the flat capsule language of
native tags. A non-interactive value state in a control row
(the slot size's "Default — orientation standard") renders in
the same capsule language rather than as bare gray prose,
which read as skippable filler.

**An "Automatic" color well shows adaptivity as a shape, not
an absence.** (#429, ui-designer consult.) Almost every color
setting stores a concrete hex, but a few default to an
*adaptive* system color (the sticky/floating marks use the
label color, which flips black/white with appearance and has
no fixed hex). A `HexColorField` opts into this with an
`automatic` flag: an empty hex is then a valid value meaning
"Automatic," and the swatch draws a diagonal light/dark split
(the macOS "Auto appearance" idiom) with an "Automatic"
placeholder in the hex field — so the adaptive state reads as
a deliberate shape, never as an empty/broken dot. Clearing back
to Automatic has two paths: right-click the swatch (a checked
"Automatic" menu item) or empty the hex field and commit.
Resolve empty through the mark fallback, never the generic hex
parser — an unset adaptive color means "adapt," not "broken,"
so it must land on the adaptive fallback, not the accent color
the parser falls back to. The flag stays off for the ~14 wells
whose color has a concrete default and no adaptive concept.

## Row layout & alignment

**Row order within a section is fixed-tier, not
usage-frequency.** A field's vertical position is decided by
what *kind* of decision it represents, not by how often a
user reaches for it — a canonical tier order is what lets the
eye learn one shape across every editor. Natural adjust-order
("what you'd tune right before/after this") only breaks ties
*within* a tier, once the tier is fixed. A contributor
placing a new field first asks **which tier**, then **where
in it**. The tiers, top to bottom:

1. **Preview / schematic** — in an area without a detail
   panel, leads unconditionally, *unless* the section has one
   master on/off toggle whose own state the preview depicts
   (Focus border's dimmed-when-off preview): then the toggle
   sits directly above the preview, the gate-above-gated rule
   extended to treat the preview as a gated control. In a
   panel area the preview lives in the panel column instead,
   and this tier is empty.
2. **Defining / structural fields** the schematic takes as
   params — counts, ratios, axis / arrangement, positions —
   ordered coarse-to-fine (what fixes the shape before what
   refines it). A *numeric-threshold* gate needs no strict
   adjacency to what it greys (Stack's Master count gates
   Master orientation, yet the unconditionally-relevant
   Master ratio sits between them): unconditional-before-
   conditional outranks adjacency, because the greyed state
   already signals the gating. Strict adjacency stays
   mandatory only for a boolean-toggle-controls-one-row pair.
3. **Standing placement / overflow policy** — New-window
   placement and Overflow style, steady-state behaviour
   rather than static geometry, cluster together and sit last
   among the schematic-tied fields.
4. **Secondary, occasional-use toggles** with their own
   captions (auto-derivation, wrap-focus), each still
   gate-above-gated internally.
5. **Escape-hatch buttons / actions** ("Fit layout gaps")
   — always last.

An escape hatch that transforms other staged settings must expose
the transaction locally: label transient inputs as action parameters,
preview the resulting values before activation, warn when structure
will be flattened, and confirm that the draft changed while the
save pill's Save is still required. Focus Border's **Fit layout
gaps** group is
the reference pattern; its action remains opt-in and one-shot rather
than introducing automatic border-to-gap coupling.

Dividers mark tier boundaries, not just breathing room, so a
new field's tier decides which divider-bounded cluster it
joins — never wedge a field mid-cluster to dodge adding a
divider. The audit that set this rule (#291) moved Track's
New-window mode + Position out of tier 2 (it had sat right
after Arrange) down to tier 3 after Overflow, so all five
layout editors now place new-window placement last among
their schematic-tied rows.

**Rows share one label axis and one readout column.** Every
labeled control row (slider, segmented picker, dropdown)
puts its label in the same fixed-width column
(`SettingsMetrics.labelColumn`), so controls start on one
imaginary line across sections instead of each row picking
its own label width; slider readouts share one trailing
column the same way. The rows read the column from the
environment (`\.settingsLabelColumn`), and `OverrideChrome`
narrows it once (`overrideLabelColumn`, paying for its
checkbox prefix) — so a shared row dropped into override
chrome lands on the plain rows' control axis by
construction, not by remembering a width parameter. Numeric steppers are the
deliberate exception: label leading, then an **editable
monospaced field** plus arrows trailing (the native
System-Settings numeric layout) — a value embedded in the
label string ("Columns: 3") read as static text, and even a
plain readout beside arrows read as passive, so the value is
a real `TextField` (type a number, or use the arrows) that
commits and clamps on Return / focus loss. An optional unit
`suffix` ("ms") sits between the field and the arrows. The
color grid is the other exception: its two-column
`HexColorField` layout keeps its own label width
(`colorLabelColumn`), because the shared axis would misalign
the grid's second column. Dropdowns ride the axis via
`DropdownRow` and take `.controlSize(.large)` so a menu
button's height sits with the capsule tracks around it.
Within a section, a `Divider` separates geometry controls
from the behavior dropdowns (overflow, new-window placement)
— eight-point uniform spacing alone let unrelated rows read
as one group.

The readout column is the one sized by a **word**, not a number
(R6/#406): an Auto-gated slider prints "Automatic" there, so
"2000 pt" is no longer the widest string it holds. The readouts
render in the **proportional** system font with
`monospacedDigit()` — System Settings' own idiom — so digit runs
stay tabular while letters take their natural width; that is
what keeps the column at 72 pt rather than the 84 a monospaced
face would need. It is still 8 pt wider than before the word
arrived — a cost the per-space override rows, the app's
narrowest editing surface, absorb in their own bounded column,
whose label column (`overrideLabelColumn`) is already narrowed
to pay for the trailing OVERRIDE checkbox. Alignment
stays **trailing**: the readout's outer edge is also the pane's
right margin, so trailing is the only choice that pins it to
one line down the whole pane (ui-designer, 2026-07-26) —
centring pins neither edge, and leading would trade a gap you
see while dragging for a ragged margin you see always. See
`docs/design-decisions.md` before narrowing it again.

**Preview alignment splits on standalone-vs-paired, not by
tab.** (ui-designer consult 2026-07-14.) A settings preview is
aligned one of two ways, and which one is decided by whether
controls sit right next to it — never by which tab it's on:

- **Standalone illustration** (a Layout schematic, the App Bar
  mock strip) — centered in its card with a caption below.
  Nothing is edited *on* it and no control column shares its
  row, so there is no leading edge to line up against; it reads
  as a figure, the way macOS System Settings centers a
  wallpaper thumbnail or screen-saver preview over its label.
- **Preview paired with the exact controls in the same card**
  (the Gaps diagram + its outer/inner legend, the Drag Ghost /
  Drop-zone columns) — left-aligned, flush with the control
  rows it drives, so preview and controls read as one stack
  (the accent-swatch / Displays-arrangement pattern).

So Layout schematics and the App Bar strip are *both* centered
(they are the same kind of thing); Gaps and Drag are left —
an inconsistency that looks like one between two *pages* is
really this one correct rule. The colour pages show both in one
change: Colours & Motion's "Current colors" scene is centered
with its caption below (nothing is edited on it), while each
Advanced Colours group's preview leads the swatches it drives
and sits flush with them. A new preview picks its bucket by
asking "are its controls right here beside it," not by copying
its page.

## Previews & schematics

**Five areas watch their draft in a fixed detail panel; the
rest keep full width.** Gaps & Borders, Bars, Colours & Motion,
Layout Defaults and Shortcuts (its keyboard board, pass 5)
open as two columns: the controls, then a
fixed 392 pt right panel headed "Live preview · <area>" that
redraws the area's preview from the *staged* draft, with a
"Changed in this draft" list of old → new rows underneath,
each a jump to the control that changed. Which areas offer a
panel is data (`SettingsDetailPanelOffer.offering`), consulted
by the two-column mount, the save pill's centring offset and
the guards alike — an area with nothing to show hides the
panel and takes the full width, so absence is a stated
verdict, never a missing branch. The panel mounts the area's
*one* renderer — a migrated card preview, or (Shortcuts) a
panel-first drawing with no card twin — and that area's cards
carry no duplicate preview; a new drawing beside a renderer is
the duplication
the migration removed (`DetailPanelTests` holds the offer set
and the removed in-card mounts; the ruling is in
`docs/design-decisions.md` ▸ two columns).

**The panel keeps its column only above 1200 pt** (turn 17a).
Between 900 and 1200 it detaches into a card floating over
the content — draggable by its grab bar, closable, and always
landing whole inside the window; below 900 the same card
waits behind a "Show preview" button. So an area that offers
a preview always has exactly one way to it at every width,
and the pill's centring offset answers to the docked form
alone. The card's close is per-mount, never a stored
preference: navigating clears the answer, and above 1200 the
panel takes its column back whatever the answer was.

**Layout schematics draw staged values, never live windows
(#125).** Each layout has one `GapsDiagram`-family schematic
(`LayoutSchematicKit` / `LayoutSchematicCanvas` hold the shared
canvas, tile, and ghost language) that redraws from the *staged*
config as the user edits — never from live window state, no AX
calls. This is the one non-negotiable: it upholds the #123
never-live-apply principle (a preview answers "what would this
look like" without mutating the session). No hover, no
tap-to-inspect, no drag-to-preview, and **no animation** — a
looping animation would be architecturally legal (canned,
config-driven) but was rejected on cost: a timer/reduce-motion
state machine in every tile for a pane open seconds at a time.
*Every tunable layout gets a schematic, Monocle included* — it
draws the **navigation model** (a fan of full-screen cards +
`orientation` cycle chevrons), not geometry, which both honours
its one real knob and removes the "why is this the one blank
layout" inconsistency.

One schematic serves two surfaces at two scales
(`SchematicScale`): a thumbnail in the "Choose a layout" strip
and the full-width drawing in the Live preview card, which is
the one that carries the caption. Both take a **window count**
the reader drives from that card's slider, so the drawing
simulates the layout at a count rather than illustrating it at a
baked-in one. Why the count is an input, and why it is view
state rather than a setting, is ruled in
`docs/design-decisions.md`; what it still does *not* buy — a
render of the reader's real windows — is in
[accepted limitations](accepted-limitations.md). Tile counts
are still capped for legibility with a "+N" chip.

**"+N" means the same thing wherever it appears: there are N
more, and here is how to see them.** The schematics' legibility
cap above and a Monitors card too small to draw all its chips
set the grammar; the Home cards' overflow chips and space fan
reuse it, and a new surface must not invent a different one. It
counts the items NOT shown (never the
total), it takes a slot of its own so it never claims to hide
exactly one, and it is an affordance rather than a label
wherever the hidden items have their own controls: on the
Monitors card it opens a popover holding every chip, each
working as it does on the card, because a chip that is merely
counted has lost its clear button and its menu.

**One frame per layout, and the conditional facts ride a shared
ghost vocabulary (#125, #753).** Every schematic is a **single
frame** — see `docs/design-decisions.md` for why the two-frame
sequence retired rather than for how it was gated — and each
carries whatever is conditional about its layout with one of a
small shared vocabulary: a **spawn ghost** (dashed accent tile +
"+", "the next window lands here": BSP's incoming window, Track's
own-vs-focused track), an **off-monitor ghost** (solid gray,
straddling a drawn screen edge, "a real window scrolled
off-screen": Scrolling's side panel), and the pre-existing
**empty-cell gap** (dashed gray, "unused grid space": rigid
Grid). Stack's overflow is a small iconic fanned-pile badge, not
a permanently cascading column. A fact the reader can reach by
dragging the window-count slider — a grid rebalancing as a fifth
window opens — is expressible in that one frame; a fact about
*motion* is the caption's to state, in words, and a caption that
carries one **switches with the control that changes it** rather
than stating it under every setting. Where a ghost needs more
room than a thumbnail has, the thumbnail leaves it undrawn
rather than shrinking the frame around it — undrawn, not merely
clipped, the frame's clip being no substitute for skipping the
drawing (`SchematicCanvas.screen` says why).
The app bar shown in Scrolling/Monocle is
**not** drawn into their schematics (one preview, one job); its
presence surfaces as live On/Off state in the `CrossReferenceRow`
that points at the App Bar destination (#229), keeping app-bar
ownership whole.

## Labels & wire names

**A GUI label may diverge from the Lua/JSON wire name when the
label alone is ambiguous (#217).** The Grid picker shows
"Arrange: Columns first / Rows first"; the wire vocabulary
stays `split_direction: horizontal | vertical` (`horizontal` =
Columns first). "Split direction" collided with two opposed
real-world conventions (divider-axis vs stack-axis); the
row/column labels are unambiguous under both. Only the display
label changes — churning the documented verb would widen the
blast radius (override commands, existing configs, testers'
mental model) for no gain. The label locale key was moved with
`scripts/rename-key` (German preserved); the two option labels
are new keys.

**Geometric wire, presentational label — the rule for every
two-axis layout.** #217 generalizes past Grid: the **Track**
picker had the same collision ("horizontal/vertical" reads two
ways for a subdivided layout — do the tracks run horizontally, or
do windows stack horizontally?), so it takes the same fix — the
GUI relabels to **"Arrange: Columns / Rows"** (reusing Grid's
`scroll_grid.arrange` label; Track's options are bare
`Columns`/`Rows`, no fill-order "first" since Track has no growth
semantic). The Lua/JSON **wire stays geometric** for both
(`grid.split_direction`, `track.axis` = `horizontal | vertical`):
a wire value describes orientation, which is unambiguous in a
scripting context where nothing is visually parsed, and it keeps
Grid, Track, and scrolling on one axis vocabulary. Renaming the
wire to `columns/rows` was **considered and rejected on gain, not
churn cost** (pre-release makes churn cheap, but cheap is not a
reason): Grid's value carries fill-order (`columns_first`) and
Track's carries pure orientation (`columns`), so no single
key/value shape unifies them — a rename would relocate the
inconsistency (GUI↔wire becomes Grid-wire↔Track-wire, plus a
`columns_first`-vs-`columns` shape mismatch) instead of removing
it, and turn a precise geometric term into a category-error
presentational one (an "axis" whose value is `columns`).
Single-axis layouts (Scrolling, Monocle) stay plain
"Horizontal/Vertical" — one axis, no ambiguity, nothing to
disambiguate. Fix the label, never the wire — **when the wire
term is accurate; see the next entry for when it isn't**. §5's
one-vocabulary rule (Lua == JSON) holds either way and is
orthogonal to this GUI↔wire question.

**When the wire is the outlier, rename the wire instead (R6,
#406).** The rule above answers a narrower question than its
closing line suggests: there the wire term is *correct* and the
label alone is ambiguous, so only the label moves. When the
**wire** term is factually wrong for what it names, the same
reasoning points the other way — the accurate side stays and the
outlier moves. Three R6 renames are that case:
`drag.set_ghost_border_thickness` → `…_border_width` (the GUI
already said "Width"; a stroke has a width, a bar has a
thickness), `track.set_count` → `track.set_limit` (the GUI
already said "Track limit"; the value is a cap that
`auto_tracks` overrides, not a count of what exists), and
`tab_background` → `background_style` on both bars (the entries
are not browser tabs, and under Plain no item draws a box of
its own in steady state). The discriminator is never churn cost —
pre-release makes churn cheap on both sides (§5) — but which
side misdescribes the thing: relabel when the label is
ambiguous, rename the wire when the wire term is wrong.

**An override stepper's range must exclude any value that
carries a separate meaning on the wire (audit finding 20,
#406).** In a per-space override row `nil` is the inherit
sentinel (`OverrideChrome`), so every value *inside* the
stepper's range is a stored value with one meaning. The
per-space Track-limit stepper ran `0...10` while its global twin
ran `1...10`: a stored 0 resolved to `max(1, 0)` = one track,
while the Lua setter's `0` means *automatic* and is never
persisted (it flips `auto_tracks` instead). One stored number,
two meanings, decided by which surface wrote it. Override
steppers are 1-based wherever 0 carries a separate Lua meaning;
"automatic" belongs to its own field rather than hiding inside
the range. Track has no per-space automatic row, so the grey
there keys on the RESOLVED `auto_tracks` (#171) — the value the
space actually gets, never the global.

**"Automatic" is the word for a value; "Auto" is the adjective
in a toggle label (R6/#406).** A value the user *reads* or
*picks* takes macOS's own full word — the empty-hex colour
sentinel, an app rule's target, a monitor chip's placement, and
`PtSlider`'s readout, which prints **Automatic** in place of
`0 pt` while the Auto sentinel is set. A toggle that turns
automation on takes "Auto" as an adjective, because "Automatic
item size" is needlessly long for a label whose noun is already
on the next row. Two shapes, picked by **how many fields the
toggle gates**:

- **One gated field → `Auto <Field>`**, naming it exactly:
  "Auto item size" over **Item size**, "Auto track limit" over
  **Track limit**. The pair reads top-to-bottom.
- **A gate over a *set* of fields → verb + object** naming the
  composite: **"Auto-size grid"** gates Columns *and* Rows, so
  no single field name exists — "Auto grid size" would name a
  field that appears on no row. Verb+object is forced by the
  multi-field gate, not chosen; do not "fix" it into the first
  shape.

Either shape must name **what** is decided automatically:
"Automatic tracks" was retired because no track is itself
automatic, only how many of them exist (ui-designer,
2026-07-25). And "Automatic" is for a value the system
*computes* — a fixed built-in default stays **"Default"**.

**A boolean mode flag names the MODE on the wire, even when its
label names the field it gates (R6/#406).** "Auto track limit"
ships against wire `track.set_auto_tracks` /
`layout.track.auto_tracks`, and that divergence is decided, not
an oversight. The reason is not "the wire is geometric" — a
boolean is not geometric — but that the two names describe
different true things. With the flag ON, `limit` is not
computed automatically, it is **ignored entirely**
(`TrackParams.trackCap` returns 0, meaning unlimited, and the
count falls out of geometry). So the wire names a *mode* —
"the partition manages itself; the limit field is dead" — which
is accurate, while `auto_limit` would name an automatic limit
that does not exist. The label may still say "Auto track limit"
because a label is read **beside** the field it gates, and a
wire name is read alone. This is the third clause of the
rename discriminator above: relabel when the label is
ambiguous, rename the wire when the wire term is wrong, and
expect a mode flag to diverge from its own label by design.

## Interaction states

**Hover confirms custom hit areas; it never creates the only
affordance.** Native bordered/prominent buttons, sidebars,
toggles, sliders, and fields keep system hover. Ambiguous
icon-only borderless actions use the shared adaptive chip
(`0.06` rest → `0.12` hover); custom full-row picker entries
use a hover-only `0.06` fill; unselected custom segments and
mode chips lift their existing fill by about `0.05`. No scale,
movement, shadow, or pointing-hand cursor on ordinary buttons
(the hand remains link-only). Disabled controls never react;
under Reduce Motion the color change is immediate. Every such
control also needs an explicit accessibility label (and concise
hint when the action is not obvious), a visible keyboard-focus
state, and a recognizable rest treatment or list context —
`.help()` and hover alone do not make a control discoverable.

**Inapplicable controls are greyed, not hidden.** When a
setting makes another control inert — Auto-size grid overrides
the Columns/Rows steppers (#171), Auto track limit overrides the
Track limit stepper (#178), Fill empty cells does nothing in a
rigid grid, the scroll-speed row is dead when Animate focus
shifts is off, the bars' Content picker is inert on a vertical
edge and their Background color inert under Plain — the
dependent control stays
visible and `.disabled`, never removed. Hiding it would jump
the list layout every time the governing toggle flips, and a
vanished control loses the cue that its stored value is
*preserved* (turn Auto-size back off and the old counts
return). Greying reads as "not right now"; hiding reads as
"gone". Precedent: `scrollSpeedRow` disabled by `onScrolling`.

**One deliberate exception: the floating save pill vanishes at
zero.** Save and Revert live in a dark pill floating over the
content column — the unsaved count with the edit target's name
("3 unsaved changes to Desk"), then **Revert**, **Save a
copy…** and **Save** — shown only while there is something to
act on, and offset left of a panel holding its own column.
The count line
is the draft list's opener: while the draft has attributed
rows, clicking it pops the old → new change list, each row a
jump to the control that changed — the one such count in the
window, the header deliberately carrying none. Once the
draft is clean the pill disappears rather than greys: it is
not an inapplicable control whose stored value greying would
preserve, it is the narration of a draft, and with no draft it
has no subject. `GreyOutHidingTests` carries the exemption;
the ruling is in `docs/design-decisions.md` ▸ the floating
pill. Below 900 pt the same three verbs and the same count
dock into a full-width bar at the foot of the window (turn
17a) — one view, two containers, because at that width the
floating form covers the rows it is about. The vanishing rule
crosses with it: no draft, no bar.

**Rows go two-line below 900 pt.** A labelled row's control
normally hangs off the shared 210 pt label axis; below the row
breakpoint the label moves above it and the control starts at
the row's leading edge with the whole width in front of it,
every row in the window at once, so the alignment that makes a
section scannable is traded whole rather than per-row. Nothing
is removed and nothing shrinks — that is the point of trading
the axis instead. Home's card grid steps
4 · 3 · 2 on the same thresholds, and below 820 the header's
search field collapses to its glyph, opening in place when
clicked or with ⌘K.

**A revealed target gets a transient wash, never a ring.** When
search (or any later cross-reference) sends the user to a
specific place in a pane, the pane scrolls that place's *card* to
the top — a control landing without the heading that names it
reads as disembodied — and its **heading** takes a brief accent
wash: `SettingsTheme.accent` at `0.18`, a corner-6 rounded rect
bleeding 4 pt past the content, flat for 300 ms, then eased out
over 900 ms (`SettingsReveal` owns the numbers). Reduce Motion
drops the cross-fade only: the wash still shows for the same
≈1.2 s and then simply disappears, because a flat tint shown and
removed is not motion.

"That place's card" presupposes the place *has* a card. An
**inline drawer** does not — it lives below its section's heading,
inside that section's card — so its scroll target is its enclosing
section, hoisted to the section's top. Revealing an inline drawer
keeps the heading that names it on screen and washes the drawer's
own label below it, rather than scrolling the bare disclosure to
the top and the heading off (#610). The wash stays precise (the
searched label alone); only the scroll unit moves up a level.

Three things this must not become. **Not a ring or halo** — that
is this app's vocabulary for "this input is armed"
(`RecorderButtonChrome`, the search field's focus stroke), and
spending it here promises a keyboard focus state with no
`FocusState` behind it. **Not a pulse or scale** — the same
bouncy motion the layout schematics rejected. **Not nested inside
a `GreyOut`** — `GreyOut` multiplies opacity on its content, so a
wash under a dimmed block compounds to ~`0.09` and reads as a
rendering fault; a hit on a control some other switch has greyed
still deserves full strength, which is the whole point of "grey,
don't hide".

Sequencing matters more than the paint. Select the destination,
then the local surface that *renders* the target (a layout's
card, `SettingsSurface.layoutMode`),
then yield one layout pass before asking the scroll
proxy for the id — a `scrollTo` in the same synchronous pass as
the state change that mints the view will miss it.

**The mode flip answers twice: motion says what just changed,
the accent-tinted frame says what is mode-gated** (#760,
amended on device 2026-08-09). Flipping the header segment to
Power User washes the title band of every *container* the flip
inserted — the same transient accent wash as a search reveal,
same numbers, decaying to nothing — and the reflow animates as
pure insertion in both places the user can be standing: Home's
grid (Simple's card order is a subsequence of Power User's) and
the open area's pane. The durable half is the frame: a
container whose *presence* depends on the mode draws its border
at `SettingsTheme.containerStrokeModeGated` (1.5 pt) in the
accent at `modeGatedStrokeOpacity`, against the 1 pt hairline
rest. The first cut said "weight, hairline colour unchanged" and
failed on device — a weight step in a ~1.2:1 stroke is a step
in something invisible, and a stronger neutral said "different"
but not *which*. The frame borrows THE accent (the colour the
active Power User segment wears), never a second hue; hue still
never carries alone, because the weight step remains and the
strength is measured — `ModeGatedFrameSeparationTests` derives
the CVD floors against both neighbours on the same edge (the
hairline, and hover's full accent) from the shipped tokens. The
weight stays below the doubling the Monitors (1.5→3 pt) and
palette (1→2 pt) pairs spend on *selected/applied*, because a
mode-gated card is present, not picked; hover keeps the
full-strength accent as its own register.

Three boundaries. **Only the explicit segment flip washes** —
the implicit promotion (search or a cross-reference landing in a
Power-User-only area) already owns its arrival wash, and a
second one in the same landing would dilute the target the user
asked for. **The flag is the site's own offer predicate
evaluated at `.simple`** — never a hand-negated copy — so the
weight states the same fact as presence: Monitors is unmarked on
a multi-display machine, the Layers card is unmarked the moment
a layer exists, and when config presence changes the flag at
rest the weight steps with no wash (a bookkeeping fact, not a
reveal). **The way back to Simple is a plain fade** — drawing
attention to content that is leaving is noise. Reduce Motion
keeps the wash flat for the same ≈1.2 s and drops only the
reflow and the cross-fade. The vocabulary is
container-granular on purpose: a per-row *control* offer the
mode also unlocks (the Spaces "Customize…" cells) has no
container border to weight, and washing a dozen sibling rows
at once is the shouting the three-places-at-once reveal
exists to avoid — such an offer appears plainly, and which
offers stay unmarked is data in `ModeGatedChromeTests`'
`unmarked` map, not a skipped site. `ModeGatedChromeTests`
pins the chrome, `SettingsModeRevealTests` the timeline.

**An action that reloads must ask before it discards.** Any
Settings action whose tail is `model.reload()` re-seeds from
disk and clears `isDirty`, so it destroys whatever the user has
staged. Route it through `SettingsModel.discardingEdits`, which
runs it immediately when nothing is staged and otherwise parks
it behind the one dashboard-wide dialog. Supply the *specific*
consequence as the message ("Loading a profile replaces the
edits you haven't saved") and put the verb on the confirm
button, so Cancel is always the safe default; the title and
Cancel are shared and must not be re-stated per site.

Two rules that are easy to get wrong. **The parked action has
to genuinely discard** — flipping a flag without reloading
leaves the save pill up, still claiming unsaved changes, after
the user agreed to lose them, and prompts a second time on the
way back.
**Return early on a no-op** before calling the gate: it cannot
tell an inconsequential action from a destructive one and will
prompt for nothing. Do not solve this by hiding or disabling
the action while dirty — prompting keeps it visible, which is
what "grey, don't hide" asks for. A source-scanning guard
(`DiscardGateParityTests`) fails the build on an ungated path;
see `docs/design-decisions.md` for why the gate sits at the call
site and which exceptions are deliberate.
The rules that fall out of applying this across a whole editor
(#520, #527), each of which was got wrong somewhere before it
was written down:

- **Read the claim aloud before writing the gate.** Greying
  row A off setting B says *turn B on and I act*, so before
  writing one, say that sentence and ask whether A actually
  stops working without B. Where it does not, the intent was a
  FLOOR — "don't leave yourself with none of these" — and a
  greyed control is the wrong vocabulary for a floor: it
  states a dependency the app will contradict the first time
  the user turns B off and watches A keep working. Sticky's
  on-window mark shipped greyed off the Space Bar for that
  reason and is now ungated
  (`StickyMarkUngatedTests`; the ruling is in
  `docs/design-decisions.md` ▸ Overrides & appearance). The
  same reading applies to a census `gate:`, which records the
  dependency as data for whatever renders it.
- **Gate a whole editor off its own switch, not just the odd
  row.** When a switch turns off the thing an entire section
  configures — the Space Bar's own toggle, "no layout shows an
  App Bar", a drag visual's Enabled — dim the whole block.
  `FocusBorderEditor` is the reference shape.
- **Ask the value that is actually read, never the global.** A
  gate keyed on a global while a per-layout or per-space
  override is what renders will grey the only editor for a value
  in use — the worse failure, because the control is live and
  looks dead. Resolve first (`bar.resolved(with: global)`,
  `resolvedGrid(for: space)`), and ask whether *any* consumer
  still reads the field.
- **Conjoin an inner gate with its block gate.** `GreyOut`
  multiplies opacity, so a row dimmed by both its own rule and
  the block above it lands at `0.25` and reads as broken rather
  than disabled. Write the inner predicate as
  `blockIsOn && ownRule`.
- **Never gate a `DisclosureGroup` — gate its content.** A
  disabled disclosure refuses to toggle in **either** direction
  (owner-confirmed on device, #527): shut, it will not open, so
  the values inside are as hidden as if the rows had been
  removed — the one outcome greying exists to prevent; open, it
  will not close, so the user is stranded in a wall of dimmed
  controls. Put the `GreyOut` on the drawer's content and leave
  the label live. That also means a block gate must not wrap a
  section that *contains* a disclosure: push it down to the
  siblings, or pass the gate into the child view
  (`AdvancedColorRows(allows:gateHelp:)`, which the bar colour
  cards hand the same gate on both sides of their "More colors"
  drawer) so it can place it
  correctly. Expansion state is deliberately preserved across
  the toggle — with the label live, closing is one click, and
  auto-collapsing would lose a drawer the user opened on purpose.

- **A block gate's explanation lives on a live anchor, not
  inside the block.** SwiftUI's `.disabled` is cumulative and
  `.disabled(false)` is a no-op, so every `HelpButton` inside a
  greyed block is dead — exactly when "what is this, why is it
  off" matters most (#527). A *block* gate (a whole editor or
  multi-row group) therefore renders a live `?` outside the
  gated subtree, passed only while the gate is active and
  carrying the why-off and how-to-enable copy. Pick the anchor
  by scope: **the nearest live label that scopes exactly the
  gated content** — the `SettingsSection` header (its `help:`
  parameter) when the whole section body is gated, the drawer's
  live disclosure label when only the drawer's content is. A
  header `?` may scope a card whose census-exempt rows stay
  live (the App Bar card's Show-it-in switches) exactly when
  its copy points at them ("turn one on below"). When the gate
  must reach inside a child view to do this, pass it in
  (`NativeSpacesGroup(gatedOff:gateHelp:)`,
  `AdvancedColorRows(allows:gateHelp:)`) rather than wrapping
  the child
  from outside, which would disable the anchor too. A
  *control-scoped* gate — one row, its gating control directly
  adjacent (Background style over Background size, a toggle
  over its slider) — keeps just the `GreyOut` hover string: the
  adjacency answers "why", and a header `?` would gloss a
  single self-explaining row. A **master** control higher up
  the *same* page, driving rows in later cards, is not a fourth
  case to reach for: Gaps & Borders shipped one for a commit
  (#754) and it was the wrong shape twice over — the followers
  it dimmed were rows that should not have existed, and the
  master needed a stored pick and a runtime gate to express a
  choice nobody wanted. Where a shared control would need
  dimmed per-instance twins to explain itself, delete the twins
  instead ([Design decisions](design-decisions.md)). What a
  master owes once the twins are gone is not a gate but an
  **acknowledgement**: it is about to overwrite values a
  config can already have set three ways, so while they
  disagree it carries a `?` saying so ("The three strokes are
  set differently right now; choosing here sets all three")
  and stays live. Greying is the gap masters' answer to the
  same state and is only available to them because a per-edge
  drawer sits directly below to repair from; grey a master with
  no such drawer and the page names a problem it then offers no
  way to fix. Where the control can also show *no answer* — a
  segmented picker whose pill hides for an unmatched value —
  it does that too, rather than assert one of the values.
  A *remote* control-scoped gate
  (the gating field lives on another **destination**) has no
  adjacency to answer "why", so hover text alone is not enough:
  it takes a live `?` on the nearest live label above the dimmed
  rows, and **its sentence names the destination to go to**, not
  just the switch. Advanced Colours is the case that forced
  this — every gate on the page is remote — and it is why its
  Borders card and each Drag column carry a header `?` even
  though neither has a block gate at all
  (`AdvancedColorsHelp`). Where a live state-dependent cue
  exists in the flow, use that too — `LayoutCard`'s app-bar
  `CrossReferenceRow` is the model, naming the bar's current
  state in the sentence and linking where to change it
  ("The monocle App Bar (currently on) is configured in …").
  Per-control `?`s inside a gated block stay
  visible-but-dimmed like every other row member; their fine
  print matters once the block is live again, and the anchor
  covers the meantime. Guarded by `GreyOutAnchorTests`.

And one exemption worth stating: a control whose *only* consumer
is off may still have a second one. The App Bar's "App symbol
style" stays live even when no bar shows, because `iconSource`
also drives the shortcuts panel's Apps band — check for a second
reader before dimming.

The tree-wide half of the convention is guarded by suites that
scan for a *shape* rather than listing the greyed controls — a
list cannot see the next site, which is how a dozen surfaces
drifted while the rule sat unenforced. `GreyOutParityTests`
pins the gates that must be present; `GreyOutHidingTests` hunts
the conditional that removes a control instead of dimming it.
The absence side is necessarily per-row — no scan can know
which control *should* carry no gate — so a row that earns one
cites its own guard where the bullets above do.

**Sentinel values read as words, not numbers.** A slider gated
by an Auto toggle stores `0` as the sentinel but its readout
prints "Automatic" while gated — "0 pt" next to a greyed slider
reads like a broken value (QA 2026-07-19). The full word, not
"Auto": a readout is a value, and the column was widened to
hold it (see *"Automatic" is the word for a value*, below).
The slider itself stays floored at 1 so dragging can never write the sentinel
(#381).

**A control may relabel with the mode it serves.** One field,
one topic, but a mode-dependent role gets a mode-dependent
name: the scrolling layout's slot size is **Column width** on a
horizontal axis and **Row height** on a vertical one
(`SlotSizeRows`) — one stored field, two honest names. Prefer
relabeling an existing control over adding
a parallel enum value or a second field.
