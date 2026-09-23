---
title: Settings UI Patterns
description: The shared control conventions every Settings surface follows.
---

# Settings UI patterns

The cross-cutting control conventions of KiwiDesk's Settings
app, for anyone building or reviewing a Settings surface. The
rulings behind them are in
[Design decisions](design-decisions.md); the GUI north-star they
serve (simplicity, intuitiveness, Apple-native feeling, in that
order) is defined in `AGENTS.md` §2. The layout-editor entries
are here because they span all seven layout editors, not one
pane.

## Help & cross-references

**Per-field help is a click popover behind a `?` right after
the label, not a hover tooltip (#94).** A row that warrants a
sentence of explanation carries a small `questionmark.circle`
button **immediately after the field's label text, inside the
shared `settingsLabelColumn`** — where the question is born,
and where System Settings puts its own info glyph.
`labelColumn` holds the longest label plus the glyph; a long
label + glyph truncates visibly (`lineLimit(1)`), and long
German labels on help rows are shortening candidates for the de
review pass. An *unlabeled*
`SegmentedPicker` (icon tabs) has no label to sit beside, so
its `?` trails the track. The button wears the shared
`hoverHighlight` chip like every other icon-only borderless
control.

Clicking opens a fixed-width popover; `.help()` rides along as
a hover fallback carrying the full text, while the VoiceOver
hint stays a short action phrase ("Shows an explanation of this
setting"), since the content is read inside the popover after
activation. A popover is a real focusable button that keyboard
and VoiceOver reach; a hover tooltip is neither.
`.help()` remains the idiom for one-line hints on
ambiguous *icon-only controls*. A field with 2–3 named options
folds per-option text into the ONE field-level popover (option
name bold, one line each) — never a `?` per segment. Two scope
guards: help is optional reading (must-know information never
lives only in the popover), and a field already taught by its
live preview or schematic (App Bar colors, a layout card's
geometry) gets no `?` at all.

**A concept goes in the `?`; a live fact goes in the flow.** A
popover's copy is fixed for every reader, so it holds what is
always true of the setting — what the thing *is*, what turning
it off costs. A statement that turns on the current value of
something else ("the Space Bar is off right now") belongs in a
caption or a `CrossReferenceRow` that re-renders with the
state. Deleting a live cue does not move its fact into the
`?`: check whether the timeless half was ever written there.

Copy is a normal `L()` string under the `<key>.help` suffix
convention. When a *label* key is shared by fields with
divergent semantics (Stack's and Track's Overflow both use
`layout_params.overflow`), the help key scopes itself
(`layout_params.overflow.stack.help`). Help copy rendered on
two surfaces — a Layout Defaults layout card and the per-space
override editor — is authored once in a per-domain namespace
(`LayoutHelp`); membership means 2+ call sites or an override
pair like `newWindowPlacement`/`trackPosition`, and
single-call-site copy stays inline. In the per-space override
editor the `?` is rendered by `OverrideChrome` itself, not the
wrapped row, so it stays clickable while the row inherits; it
therefore sits at the chrome row's trailing edge, consistently
for every override row — the one exception to label-adjacent
placement. Do not move it back inside the row: that re-enters
the disabled scope.

**"Lives elsewhere" pointers are links, and the link sits
where the sentence puts it.** Prose that names another tab
("configured in the App Bar tab") is a dead end; such pointers
are `CrossReferenceRow`s, jumping the pushed-area selection
through an injected `settingsNavigate` environment action.

The destination's name is a **positional specifier** in the
prose key, filled with `CrossReferenceRow.linkSlot`, so a
translation may place it wherever its own word order wants;
`Text(prose)` followed by a sibling link parks the name at the
end and forces every key to be authored dangling ("… — edit
them in"), the same defect as a `+`-concatenated fragment.

Resting style is an underline in the caption's own secondary
grey — never the system link blue, since these are prose the
reader may follow rather than calls to action — lifting to
primary under the pointer, `linkHover()`'s treatment for the
tree's other inline links (the make-default link, the rename
pencil). A `CrossReferenceRow` renders through `LinkedCaption`,
an `NSTextView` bridge: SwiftUI's `Text` gives a `.link` run no
pointing-hand cursor, and `NSLayoutManager` breaks lines
correctly around a name mid-sentence in a language that does
not break on spaces. That view owes its own keyboard
activation, focus ring and accessibility child, which a
`Button` gives free and an `NSTextView` does not.

A pointer whose sentence names a **location** takes a
breadcrumb headed by the destination's own title
("Bars ▸ App Bar"), not the section name alone: a link reading
"App Bar" names no card Home shows, and only a `▸`-shaped value
enters `SidebarCrossReferenceTests`. A pointer whose sentence
names the **feature itself** — a sentence turning on whether
the Space Bar is on, say — links that mention and stays one
segment, since a breadcrumb there would be a second mention.
Every shipped `CrossReferenceRow` call site names a location.

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
visible editor rather than edit a value, and a future
navigation strip past four segments still qualifies. Layout
Defaults' layout selector is a strip of live schematic
thumbnails, not a segmented control (below). The *same
semantic field uses the same control on comparable full-width
surfaces*: the two bar cards both render Position / Background
style / Active indicator as segments. Segmented under the
rule: the App Bar fields, Stack's Master orientation / Stack
position / Overflow, Track's Overflow, and Corners (which
drives all three strokes, #754). Menus where the rule keeps
them: new-window placement (comparative labels), the
seven-option Space layout mode, and the dynamic Language and
Desktop→Profile lists.

Every shipped segmented strip fits a full-width row at the
720 pt minimum (`SettingsWidthClass.minimum`), measured against
all ten locales (#95): the widest is Mouse resize action at
~503 pt (`es`, "Redimensionar las ventanas contiguas"), then App
Bar active indicator at ~408 pt (`fr`). Re-measure a strip
before adding a fourth segment to either of those two.

**The per-Space override rows keep menus, not segmented
controls (#291).** The override editor is a full pushed pane
(#678 8b) whose rows sit in a **bounded ~700 pt column** with a
trailing OVERRIDE checkbox column (`overrideStateColumn`,
88 pt) and the `OverrideChrome` accent bar, so a 2–4-peer field
has no room for a segmented render; `OverridePickerRow`
renders `.menu` and has no `.segmented` branch, since the
per-space editor is the only override surface. Restore a
required-style parameter only if a genuinely *full-width*
override surface arrives. The inherited (unchecked) state
collapses to a quiet "follows `<Layout>` defaults · `<value>`"
readout (the slot-size pair keeps its live control instead,
dimmed via the chrome's `.disabled` + `.opacity(0.5)`). App
Bar Content ("Icon &amp; name" → German "Symbol &amp; Name") is
the one segmented label tight at minimum width; it stays
segmented by width headroom and is re-checked for truncation
when each new locale ships (#95), as the help-glyph labels
are.

**Numeric controls pick one of three idioms by a single
test:** *would a user say a specific number out loud?* — never
by which pane the setting lives in:

- **`StepperRow`** (typeable field + arrows) for discrete,
  exact values a user names: counts, ms durations, pt
  thresholds — master count, columns/rows, track limit,
  minimum window size, animation duration.
- **Slider + readout** (no typing) for a continuous feel or
  proportion tuned by eye: split ratios, master ratio, gaps.
- **Segmented / toggle** for a non-numeric choice.

Minimum window size is a `StepperRow` on this rule (#204): a
precise pt threshold, not a feel knob.

A stored SHARE keeps its slider and gains an exact chooser
beneath it where the share has a second reading a user names
(#1382): the scrolling slot's Percent slider carries a
**Windows on screen** stepper (the share is a count), and a
split ratio's slider carries fraction chips ¼ ⅓ ½ ⅔ ¾ (a
share is a share). Both write the one stored value; the slider
stays for feel. The stepper sits on the slider's control axis
rather than trailing, so the count reads as the slider's own
second reading; its `?` states the size rule alone, and what
the anchor makes of the count is the preview caption's. The
argument is in
[design decisions](design-decisions.md#a-repeating-slot-is-offered-as-a-count-a-split-as-a-share).

**Layout Defaults picks one layout at a time, and picks it by
its picture (#204, #678 turn 10).** The layout modes are a
fixed, small, mutually-exclusive set (`LayoutMode` minus
Floating), so one mode's editor is visible at a time instead of
every mode stacked in one `ScrollView`. What selects it is a
strip of **live schematic thumbnails**, not a segmented strip
of words: the layout names are ones only a tiler user knows,
so the drawing is the label — each tile also carrying the
count of spaces using it. The strip lands on the profile's
most-used layout. The global minimum window size is pinned
*above* the strip because it feeds every layout (and gates the
`OverlapStack` overflow cascade). The rows come from the
settings census and one `LayoutCard` renders whichever layout
is selected.

## Shared visual language

**A section or disclosure title is sentence case** — "On quit",
"Drag & drop", "Move windows", not "On Quit" or "Drag & Drop"
(R5, #406), which is what macOS System Settings uses for its
own in-pane headers. Three boundaries, because System Settings
itself draws them:

- **The rule is scoped to headers** — `SettingsSection` titles
  and the labels of an "Advanced" disclosure. The
  **`SettingsDestination` titles (Home cards, back-chip
  headings) stay Title Case** ("Layout Defaults", "App Rules"):
  they name a destination, as System Settings names its panes.
  So do **action labels** ("Open New", "Set Gap Values") — a
  verb-phrase command follows the menu-item convention, not
  this one.
- **An action may be a bare noun where the verb would collide**,
  and "Layouts" on a preset card is the one that exists (#859):
  its verb-phrase form is "Show layouts", and *show* is spoken
  for in this window by the detail panel's own chip ("Show
  preview") (`docs/localization-naming.md` ▸ Family C, rule 1).
  The clash is of *verbs*, not nouns: `fr` and `ru` both take
  the verb-phrase form, because in those catalogs the bare noun
  would be byte-identical to the Layout Defaults destination
  and `DestinationNameCollisionTests` would redden. Where both
  forms are free, take the verb.
- **`&` does not start a new sentence**: "Size & float", "Drag &
  drop". The word after the ampersand is the one a sweep
  misses.
- **Capitalize only what a sentence would.** A proper noun stays
  ("Lua bindings"); an acronym stays an acronym ("BSP").
  KiwiDesk's own **named surfaces keep their caps** — the App Bar
  and the Space Bar are things ("Space Bar colors") — while a
  feature that is just its noun does not ("Focus border").

**"Advanced" prefixes a disclosure's noun only when a basic tier
of that same noun is visible above it; otherwise the drawer is
named for what it holds** (R3, #406). So **"Lua bindings"** and
**"Monitor fingerprints"**: the catalog above Shortcuts' drawer
is a different noun (*actions*), and Monitors has no lesser
fingerprint anywhere.

**The qualifier must also be unclaimed by the surface AROUND
the drawer** (#678). A row tier and a mode depth are never
spelled with one word: Advanced Colors is the deep-mode twin of
Colours & Animations (`SettingsArea.minimumMode` is `.powerUser`
there), so on that page "advanced" already means *which mode
you are in* and no drawer may re-use it to mean *which rows are
hidden*. Its colour drawers are **"More colors"**, with the
collapsed summary doing the naming ("Plate, highlight, hover,
badges"); "More" cannot be misread as a mode.

A connector (`Advanced: Lua bindings`) is not the fix: it
restores the tier reading but re-splits the format. Dropping
the qualifier loses nothing — collapsed by default, boxed, at
the bottom of the page, and Shortcuts' own caption ("the
power-user escape hatch") already say it. The bare "Advanced"
(General) is untouched by the rule: no noun, nothing to
misparse, and it is the only advanced thing on its page.

**An inline disclosure row leads with a hairline rule, and its
drawer opens into one sunken well.** The thin top rule sets an
accordion off from the plain rows around it without promoting
the drawer to a card, and whatever the drawer reveals sits in a
single well — never one well per child. `SettingsDisclosure`
draws both; the ruling is in `docs/design-decisions.md`.

**A drawer header is the whole row: one button, a resting
cue, and its state in words.** Every accordion header — both
chromes, and the one drawer built outside the wrapper — takes
`SettingsDisclosureStyle`, which makes the row a full-width
`.plain` `Button`, rests it on a chevron that inherits the
header's size outright (bold, no `.font` and no scale step, so
it moves when the header does and never outgrows it), and
marks the row `.isHeader` for the headings rotor.

**The TITLE's tier is the wrapper's, not the style's.** A
drawer that goes through `SettingsDisclosure` draws its title
at `SettingsDrawerHeader.tier` — `.callout` at semibold,
carried on weight rather than size; a header drawn smaller
*and lighter* than the rows it heads is what #1021 was. The one
drawer built outside the wrapper takes the style (the button,
the chevron and the heading trait) but keeps a deliberately
quiet title of its own, so the tier claim is about wrapper
users, which is the scope `SettingsDisclosureSizeTests` reads.
The summary beside the title takes the same tier without the
weight.

The chevron rotates on expand. There is no resting fill — hover
confirms at `rowHoverHighlight`'s full-row ladder, never the
icon chip's, whose rest state is achromatic at row width — and
the row carries expanded / collapsed on `.accessibilityValue`,
because the button replaced the triangle that announced it.
Click anywhere on the row, Space on the focused one; the cursor
stays an arrow (the hand is link-only). A drawer's `accessory:`
may hold a control, so it is drawn BESIDE that button, at the
row's trailing edge — the row's hit shape stops where the
accessory begins.

**What the drawer hides is stated on the row while it is
shut, and it is not an accessory.** A drawer takes `summary:`
— words only — and the style owns the tier (`.callout` at
`ink3`: description, where the chevron's `ink2` is the row's
affordance) and the shut-only rule, so neither is a call-site
choice. It renders INSIDE the header button, unlike the
accessory beside it, so the hover highlight covers it and
clicking the words opens the drawer. It stays beside the title
rather than under it because it states a VALUE and disappears
on expand, where a caption explains what a thing IS and stays.
The ruling is in `docs/design-decisions.md`.

**A section header's trailing readout is words only.** A
`SettingsSection` takes `trailing:` — a short value at the
title's far edge, drawn in `ink2` at `.subheadline`, the Mac
Checklist's "Done: 2 of 4" — and never a control: an accessory
that acts needs a name and a value of its own, which is the
drawer accessory's job above.

**Weigh every title edit against the search index.** Search
indexes destination titles, every census-labelled setting row
(`SettingsSearchIndex`, one row per `SettingKey`) and the
catalog's own controls — drawer titles, mode tabs — plus a
sparse English synonym table (`SettingsSearchSynonyms`,
match-only, never displayed). A title that drops a word no
other indexed string carries makes its own drawer unfindable by
that word. "Monitor fingerprints" is the one indexed string
carrying "fingerprint", which is part of why that title wins.
"Lua" is also carried by the init.lua rows in General and
Shortcuts, but results are per row, so the raw-Lua drawer still
needs its own title's words. Per-instance rows (a space's own
binding row) stay out by design: their FAMILY is the setting,
and the **Made by you** group is how a named thing is found.

Localization splits here, and the split is the rule from §5:
R5's capitalization and R3's connector are **cosmetic**, so
German keeps its own typography ("Erweitert: …"). Dropping
"Advanced" changed the English **meaning**, so those two keys
take `scripts/drop-key` and re-queue for translation — see
`docs/translating.md`.

**A section title labels its rows visually; it does not label
them to VoiceOver.** A diagnostic readout row (Monitors'
fingerprint hashes) needs no visible per-row label when the
drawer above it is named for exactly that value. But the title
is spoken once while rows are stepped one at a time, so give
such a row a combined `accessibilityElement` with an explicit
`accessibilityLabel` naming the value, and keep `textSelection`
scoped to the value itself, so copying for a support ticket
yields the value alone.

Two things decide how far the combined element reaches:

- **Does the title name the value at all?** Monitors' drawer is
  titled "Monitor fingerprints", so its rows speak the display
  and the hash. The orphan-pin rows sit under "Pinned to
  disconnected monitors", which never says *fingerprint*, so
  their label carries both halves — the row's own sentence plus
  the monitor it is waiting for.
- **Does the row hold a control?** Combine the **readout only**,
  never the whole row: `children: .combine` folds interactive
  children in too, so wrapping a row that ends in a clear or
  edit button costs that button its own element — scope the
  combined element to the static run and leave the control a
  sibling.

**Option tabs are a solid sliding-pill segment control.**
Every pick-one-of-few chooser (layout parameters, mouse
resize, icon picker tabs) uses `SegmentedPicker` instead of
the native segmented picker: a capsule track where the
selection is a solid **accent** pill carrying the on-accent
ink — the accent-marks-control-fills convention — with no
shadow (a white pill needs the thumb's shadow to lift off a
same-luminance track, which dies in dark mode). The selected
state never rides colour alone: the
selected label is larger and semibold, a real font-size step,
because `scaleEffect` rasterizes the text and reads as blur.
Liquid Glass is not used on the pill: bare glass over the flat
settings background reads as washed-out, tint reads as "blue,
not glass", and the glass layer blurs content near it. ONE
persistent pill slides between segments via matched geometry,
adopting the selected segment's anchored frame — styling
attached to the selected label crossfades on selection change
instead, because the view is destroyed and recreated. Segments
are equal-width across the track (full-bleed, like a native
window-toolbar switcher), a deliberate trade against
content-sized segments. One control, one look.

**Sliders share the pill design.** Every value adjuster
(ratios, gaps, sizes) is a `SettingsSlider`: the same capsule
track as the segmented picker, a native-style solid white
thumb that overhangs the track by 2 pt per edge, and a
full-strength accent fill up to the knob — a translucent fill
reads as disabled, and a clear Liquid Glass knob refracts the
accent fill beneath it and turns blue. Accessibility is
delegated to a native `Slider` representation, so assistive
tech sees exactly the control it replaces.

**Buttons take a native style, and semantic role chooses the
class.** No gradients or shadows on buttons — the crisp shadow
is the slider thumb's alone. The single custom style is the
accent fill below, whose edge is a darker shade of its own
fill rather than a border in a new colour. Class is otherwise
expressed through native style + control size:
`.borderedProminent` regular for a surface commit on a
mode-varying ground (a popover confirm, an editor's apply);
`.bordered` large for row actions (Load, Apply, Customize, Set
Gap Values), level with large dropdowns; `.bordered` regular
for stateful input triggers (the shortcut recorder); and
`.borderless` regular for icon-only row actions (trash,
×-clear, rename). List-add actions stay `.bordered`; `.plain`
+ underline is reserved for inline prose links. Small controls
are subordinate inline or popover utilities (Shortcuts import,
override resets), never a normal row action. Native macOS
shape differences between these classes are intentional —
choose by semantic role, not by a desired silhouette.

**The exception is a button filled with the app's own accent,
and it is about ink rather than silhouette.**
`.borderedProminent` picks its own label colour, white on
macOS, which on KiwiDesk's kiwi green measures **2.41:1** in
both appearances (the accent is the same hue in each), under
every legibility floor this app holds. `accentInk` is the ink
the theme declares for text drawn *on* the accent, a pairing
the theme's contrast lens measures. Fill and ink are sealed
into one style — `KiwiProminentButtonStyle`, applied as
`kiwiProminentButton()` — which the first-launch tour's
primary action wears on every screen and the save pill's Save
wears for the reason below.

Reach for it only where a button carries an accent fill; a
custom style is a cost, not a free recolour. A `ButtonStyle`
keeps the `Button`, so focus, keyboard activation, VoiceOver
and `isEnabled` survive; what it takes over is what the system
style *drew*, so the pressed and disabled appearances are
redrawn through the fill rather than the label, and a click
never dims the ink.

Each of the three states is its own **opaque** token —
`accent`, `accentPressed`, `accentDisabled` — with the ink held
at `accentInk` throughout, since a state drawn as an opacity
composites differently against every ground. Disabled drains
the hue rather than dimming it: it measures 3.74:1 for the
label, stays a visible control on every ground the seal is
drawn on, and clears the protanopia separation floor —
`AccentStateSeparationTests` measures that against
`ColorVision.separationFloor` rather than a number written
here.

**On a ground that does not move with the appearance, the seal
stops being a preference.** The save pill is dark in both
modes, and an inactive window makes AppKit re-pick a prominent
button's ink against the *window's* appearance rather than the
plate the button sits on: in light mode the label and the fill
both collapse into the plate, **1.23:1** enabled and **1.09:1**
disabled, against the seal's 6.67:1 in every appearance and
activation state (in dark mode the system button reads at
11.48:1). So the pill's Save wears the seal, and every other
control on that plate sets its own ink (#1198). Settings'
remaining prominent buttons take the system style; moving one
onto the seal is its own change and its own eye-confirm.

**A recording shortcut field wears an accent halo.** The
armed recorder among dozens of identical rows gets an accent
fill + ring extending slightly past the button — the same
accent-layer vocabulary as `OverrideChrome`'s active rows —
because a tinted border plus a label swap alone is too quiet
to spot at list speed.

**Status badges stay flat.** The thumb's shadow is the
settings' vocabulary for "interactive, movable"; on a passive
`BadgeChip` it would promise interaction the chip does not
have. Depth comes from the hairline stroke both chip types
share, matching the flat capsule language of native tags. One
mark sits outside both vocabularies: the Monitors picture's
main-display card wears a soft accent bloom — decoration
stating a fact, promising neither interaction nor an armed
input, and always beside the textual "main" badge that carries
the answer. A non-interactive value state in a control row (the
slot size's "Default — orientation standard") renders in the
same capsule language rather than as bare gray prose.

**An "Automatic" color well shows adaptivity as a shape, not
an absence** (#429). Almost every color setting stores a
concrete hex, but a few default to an *adaptive* system color
(the sticky/floating marks use the label color, which flips
black/white with appearance and has no fixed hex). A
`HexColorField` opts into this with an `automatic` flag: an
empty hex is then a valid value meaning "Automatic," and the
swatch draws a diagonal light/dark split (the macOS "Auto
appearance" idiom) with an "Automatic" placeholder in the hex
field. Clearing back to Automatic goes through the checked
"Automatic" menu item — offered on every row-menu route (see
"Interaction states" ▸ a row's menu is one menu) — or by
emptying the hex field and committing. Resolve empty through
the mark fallback, never the generic hex parser, which falls
back to the accent color. The flag stays off for the ~14 wells
whose color has a concrete default and no adaptive concept.

## Row layout & alignment

**Row order within a section is fixed-tier, not
usage-frequency.** A field's vertical position is decided by
what *kind* of decision it represents, so the eye learns one
shape across every editor; natural adjust-order only breaks
ties *within* a tier. A contributor placing a new field first
asks **which tier**, then **where in it**. The tiers, top to
bottom:

1. **Preview / schematic** — in an area without a detail
   panel, leads unconditionally, *unless* the section has one
   master on/off toggle whose own state the preview depicts
   (Focus border's dimmed-when-off preview): then the toggle
   sits directly above the preview, as a gate above the gated.
   In a panel area the preview lives in the panel column
   instead, and this tier is empty.
2. **Defining / structural fields** the schematic takes as
   params — counts, ratios, axis / arrangement, positions —
   ordered coarse-to-fine. A *numeric-threshold* gate needs no
   strict adjacency to what it greys (Stack's Master count
   gates Master orientation, with the unconditional Master
   ratio between them): unconditional-before-conditional
   outranks adjacency, because the greyed state already
   signals the gating. Strict adjacency stays mandatory only
   for a boolean-toggle-controls-one-row pair.
3. **Standing placement / overflow policy** — New-window
   placement and Overflow style, steady-state behaviour
   rather than static geometry, cluster together and sit last
   among the schematic-tied fields.
4. **Secondary, occasional-use toggles** with their own
   captions (auto-derivation, wrap-focus), each still
   gate-above-gated internally.
5. **Escape-hatch buttons / actions** ("Fit layout gaps")
   — always last, and on the card whose VALUES they write.

An escape hatch that transforms other staged settings exposes
the transaction locally: label transient inputs as action
parameters, preview the resulting values before activation,
warn when structure will be flattened, and confirm that the
draft changed while the save pill's Save is still required.
The **Fit layout gaps** group is the reference pattern; its
action is opt-in and one-shot, never automatic border-to-gap
coupling.

Dividers mark tier boundaries, so a new field's tier decides
which divider-bounded cluster it joins — never wedge a field
mid-cluster to dodge adding a divider. All five layout editors
place new-window placement last among their schematic-tied
rows (#291).

**Rows share one label axis and one readout column.** Every
labeled control row (slider, segmented picker, dropdown) puts
its label in the same fixed-width column
(`SettingsMetrics.labelColumn`), so controls start on one line
across sections; slider readouts share one trailing column the
same way. Rows read the column from the environment
(`\.settingsLabelColumn`), and `OverrideChrome` narrows it once
(`overrideLabelColumn`, paying for its checkbox prefix), so a
shared row dropped into override chrome lands on the plain
rows' control axis by construction. Numeric steppers are the
exception: label leading, then an **editable monospaced
field** plus arrows trailing (the native System Settings
numeric layout) — a value embedded in the label string
("Columns: 3") or a plain readout beside arrows reads as
passive, so the value is a real `TextField` that commits and
clamps on Return / focus loss, with an optional unit `suffix`
("ms") between the field and the arrows. The color grid is the
other exception: its two-column `HexColorField` layout keeps
its own label width (`colorLabelColumn`), because the shared
axis would misalign the grid's second column. Dropdowns ride
the axis via `DropdownRow` and take `.controlSize(.large)` so a
menu button's height sits with the capsule tracks around it.
Within a section, a `Divider` separates geometry controls from
the behavior dropdowns (overflow, new-window placement).

The readout column is sized by a **word**, not a number
(R6/#406): an Auto-gated slider prints "Automatic" there. The
readouts render in the **proportional** system font with
`monospacedDigit()` — System Settings' own idiom — which keeps
the column at 72 pt rather than the 84 a monospaced face would
need. The per-space override rows, the app's narrowest editing
surface, absorb it in their bounded column, whose label column
(`overrideLabelColumn`) is narrowed to pay for the trailing
OVERRIDE checkbox. Alignment stays **trailing**: the readout's
outer edge is also the pane's right margin, so trailing is the
only choice that pins it to one line down the whole pane. See
`docs/design-decisions.md` before narrowing it again.

**Preview alignment splits on standalone-vs-paired, not by
tab.** Which one is decided by whether controls sit right next
to the preview:

- **Standalone illustration** (a Layout schematic, a bar or
  palette scene) — centered in its card with a caption below.
  No control column shares its row, so it reads as a figure,
  the way System Settings centers a wallpaper thumbnail over
  its label.
- **Preview paired with the exact controls in the same card**
  — left-aligned, flush with the control rows it drives, so
  preview and controls read as one stack (the accent-swatch /
  Displays-arrangement pattern).

A new preview picks its bucket by asking "are its controls
right here beside it," not by copying its page. Every area in
`SettingsDetailPanelOffer` draws its preview in the panel
column, where no control shares its row, so it lands in the
standalone bucket by construction; the paired bucket stays for
the next preview that does sit in a card beside the rows it
drives.

## Previews & schematics

**The areas that watch their draft do it in a fixed detail
panel; the rest keep full width.** Which ones is
`SettingsDetailPanelOffer.offering` and nothing else — Gaps &
Borders, Bars, Colours & Animations, Layout Defaults, Shortcuts
(its keyboard board), Advanced Colours and Spaces (#793,
#794). They open as two columns: the controls, then a fixed
392 pt right panel headed "Live preview · <area>" that redraws
the area's preview from the *staged* draft, with a "Changed in
this draft" list of old → new rows underneath, each a jump to
the control that changed. The offer is consulted by the
two-column mount, the save pill's centring offset and the
guards alike — an area with nothing to show hides the panel
and takes the full width, so absence is a stated verdict,
never a missing branch. The panel mounts the area's *one*
renderer — a migrated card preview, or (Shortcuts) a
panel-first drawing with no card twin — and that area's cards
carry no duplicate preview (`DetailPanelTests` holds the offer
set and the removed in-card mounts; the ruling is in
`docs/design-decisions.md` ▸ two columns).

**The panel keeps its column only above 1200 pt.** Between 900
and 1200 it detaches into a card floating over the content —
draggable by its grab bar, closable, and always landing whole
inside the window; below 900 the same card waits behind a
"Show preview" button. An area that offers a preview always
has exactly one way to it at every width, and the pill's
centring offset answers to the docked form alone. The card's
close is per-mount, never a stored preference: navigating
clears the answer, and above 1200 the panel takes its column
back whatever the answer was.

**A picture of something that is not the draft goes in a
SHEET, not the panel** (#859): the preset preview is a sheet
off the card, and Profiles stays out of
`SettingsDetailPanelOffer.offering` (`DetailPanelTests` pins the
refusal). *Why* is
[Design decisions](design-decisions.md) ▸ the panel's object is
the DRAFT.

**Transient surfaces are chosen by what they hold, not by
size.** A **popover** is a glance or a small edit anchored to
the control that opened it (a `?`, a rename field, a chip
overflow). An **alert** or `confirmationDialog` is a question
with consequences. A **sheet** is a body of content too big for
an anchored popover and not a question at all: one dismissal,
and it writes nothing. A sheet that grows a commit button is a
dialog wearing the wrong chrome; give the commit back to the
surface that owns it.

Two mechanics a sheet owes. **It is hosted where its identity
is stable for as long as the area is**, never inside a
`LazyVGrid`'s cards or any other subtree its own presenter can
tear down (the rule `SettingsView` follows for the one discard
dialog), and it is presented by `item:` over an `Identifiable`
request — the rule for any presentation whose content is built
from one row, stated as that in `.claude/rules/gui.md`. Its
**one dismissal answers Return and Escape both**: a `Button`
carries only one shortcut, so `.defaultAction` rides the
visible Done and Escape is a second, hidden button carrying
`.cancelAction` (the preset preview and About both).
`SheetPresentationSeamTests` is the register of which files may
host a sheet, and holds all three.

**Layout schematics draw staged values, never live windows
(#125).** Each layout has one `GapsDiagram`-family schematic
(`LayoutSchematicKit` / `LayoutSchematicCanvas` hold the shared
canvas, tile, and ghost language) that redraws from a *settings
value* — the staged config as the user edits it, or the settings
of whatever object the picture is of — never from live window
state, no AX calls: a preview answers "what would this look
like" without mutating the session, the #123 never-live-apply
principle. No hover, no tap-to-inspect, no drag-to-preview, and
**no idle animation** — a schematic eases between staged
values, but nothing loops (a timer in every tile for a pane
open seconds at a time is the cost that rules it out). *Every
tunable layout gets a schematic, Monocle included* — it draws
the **navigation model** (a fan of full-screen cards +
`orientation` cycle chevrons), not geometry.

One schematic serves several surfaces at two scales
(`SchematicScale`, whose own doc comment is the authority on what
each scale is *for*): a thumbnail in the "Choose a layout" strip
and in the preset preview sheet (#859), and the full-width
drawing in the Live preview card — the one that carries the
caption, `showsCaption` answering true for `panel` alone.
Inside Layout Defaults both mounts take a **window count** the
reader drives from that card's slider, so the drawing simulates
the layout at a count rather than illustrating it at a baked-in
one; a mount with no slider beside it passes
`LayoutSchematic.defaultWindowCount` instead, a stand-in and
not the reader's own windows either way. Why the count is an
input, and view state rather than a setting, is ruled in
`docs/design-decisions.md`; that it does *not* render the
reader's real windows is in
[accepted limitations](accepted-limitations.md). Tile counts
are capped for legibility with a "+N" chip.

**"+N" means the same thing wherever it appears: there are N
more, and here is how to see them.** The schematics' legibility
cap above and a Monitors card too small to draw all its chips
set the grammar; the Home cards' overflow chips and space fan
reuse it, and a new surface must not invent a different one. It
counts the items NOT shown (never the total), it takes a slot
of its own so it never claims to hide exactly one, and it is an
affordance rather than a label wherever the hidden items have
their own controls: on the Monitors card it opens a popover
holding every chip, each working as it does on the card,
because a chip that is merely counted has lost its clear button
and its menu.

**"+N" governs a bounded container that cannot scroll; content
past the fold of a SCROLLING container is cued in words
instead** (#1292). The ⌃⌥K shortcuts panel is the case: its
bands are non-uniform (headers, a caption, two-column layouts),
the fold cuts *through* a row, and the controller knows heights
rather than rows, so any N would be an estimate wearing a
precise shape. The panel says "Scroll for more shortcuts" and
counts nothing; it is read-only, so the hidden items have no
controls to lose and a label is admissible.

The middle clause is arithmetic, so it is code:
`OverflowSplit.shown(of:fitting:withMarker:)` is the one
statement of it, and a surface that caps a run routes through
it instead of restating the sum. Each caller still measures its
own capacity — a Monitors card from its geometry, a Profiles
row from a fixed slot count. Surfaces predating it still
compute `total - cap` and so can render "+1"; adopting one is
its own change, since routing it shows one item fewer.

**One frame per layout, and the conditional facts ride a shared
ghost vocabulary (#125, #753).** Every schematic is a **single
frame** — `docs/design-decisions.md` carries why the two-frame
sequence retired — and each carries whatever is conditional
about its layout with one of a small shared vocabulary: a
**spawn ghost** (dashed accent tile + "+", "the next window
lands here": BSP's incoming window, Track's own-vs-focused
track), an **off-monitor ghost** (solid gray, straddling a
drawn screen edge, "a real window scrolled off-screen":
Scrolling's side panel), and the **empty-cell gap** (dashed
gray, "unused grid space": rigid Grid). Stack's overflow is a
small iconic fanned-pile badge, not a permanently cascading
column. A fact the reader can reach by dragging the
window-count slider — a grid rebalancing as a fifth window
opens — is expressible in that one frame; a fact about *motion*
is the caption's to state, in words, and a caption that carries
one **switches with the control that changes it** rather than
stating it under every setting. Where a ghost needs more room
than a thumbnail has, the thumbnail leaves it undrawn rather
than shrinking the frame around it — undrawn, not merely
clipped (`SchematicCanvas.screen` says why). The app bar shown
in Scrolling/Monocle is **not** drawn into their schematics
(one preview, one job); its presence surfaces as live On/Off
state in the `CrossReferenceRow` that points at the App Bar
destination (#229).

## Labels & wire names

**A GUI label may diverge from the Lua/JSON wire name when the
label alone is ambiguous (#217).** The Grid picker shows
"Arrange: Columns first / Rows first"; the wire vocabulary
stays `split_direction: horizontal | vertical` (`horizontal` =
Columns first). "Split direction" collides with two opposed
real-world conventions (divider-axis vs stack-axis); the
row/column labels are unambiguous under both. Only the display
label changes — churning the documented verb widens the blast
radius (override commands, existing configs, testers' mental
model) for no gain. New option labels are new keys; what a
relabel does to the label's own key is `docs/translating.md`
▸ *Maintaining the key set* ▸ *Rename vs. drop vs. deprecate*'s.

**Geometric wire, presentational label — the rule for every
two-axis layout.** The **Track** picker has the same collision
(do the tracks run horizontally, or do windows stack
horizontally?), so the GUI labels it
**"Arrange: Columns / Rows"** (reusing Grid's
`scroll_grid.arrange` label; Track's options are bare
`Columns`/`Rows`, no fill-order "first" since Track has no
growth semantic). The Lua/JSON **wire stays geometric** for
both (`grid.split_direction`, `track.axis` =
`horizontal | vertical`): a wire value describes orientation,
unambiguous where nothing is visually parsed, and it keeps
Grid, Track, and scrolling on one axis vocabulary. Renaming
the wire to `columns/rows` is rejected on gain, not churn cost:
Grid's value carries fill-order (`columns_first`) and Track's
carries pure orientation (`columns`), so no single key/value
shape unifies them — a rename would move the inconsistency to
Grid-wire↔Track-wire and turn a geometric term into a
presentational one (an "axis" whose value is `columns`).
Single-axis layouts (Scrolling, Monocle) stay plain
"Horizontal/Vertical". Fix the label, never the wire — **when
the wire term is accurate; see the next entry for when it
isn't**. §5's one-vocabulary rule (Lua == JSON) holds either
way and is orthogonal to this GUI↔wire question.

**When the wire is the outlier, rename the wire instead (R6,
#406).** The rule above covers the case where the wire term is
*correct* and the label alone is ambiguous, so only the label
moves. When the **wire** term is factually wrong for what it
names, the accurate side stays and the outlier moves. Three
renames are that case: `drag.set_ghost_border_thickness` →
`…_border_width` (the GUI says "Width"; a stroke has a width, a
bar has a thickness), `track.set_count` → `track.set_limit`
(the GUI says "Track limit"; the value is a cap that
`auto_tracks` overrides, not a count of what exists), and
`tab_background` → `background_style` on both bars (the entries
are not browser tabs, and under Plain no item draws a box of
its own in steady state). The discriminator is never churn
cost — a Lua verb renames freely and a stored key owes its
migration (§5) — but which side misdescribes the thing.

**An override stepper's range must exclude any value that
carries a separate meaning on the wire (audit finding 20,
#406).** In a per-space override row `nil` is the inherit
sentinel (`OverrideChrome`), so every value *inside* the
stepper's range is a stored value with one meaning. A per-space
Track-limit stepper running `0...10` beside its global twin at
`1...10` gives a stored 0 two meanings, decided by which
surface wrote it: resolved to `max(1, 0)` = one track, while
the Lua setter's `0` means *automatic* and is never persisted
(it flips `auto_tracks` instead). Override steppers are 1-based
wherever 0 carries a separate Lua meaning; "automatic" belongs
to its own field. Track has no per-space automatic row, so the
grey there keys on the RESOLVED `auto_tracks` (#171) — the
value the space actually gets, never the global.

**"Automatic" is the word for a value; "Auto" is the adjective
in a toggle label (R6/#406).** A value the user *reads* or
*picks* takes macOS's own full word — the empty-hex colour
sentinel, a monitor chip's placement, and
`PtSlider`'s readout, which prints **Automatic** in place of
`0 pt` while the Auto sentinel is set. A toggle that turns
automation on takes "Auto" as an adjective, since its noun is
already on the next row. Two shapes, picked by **how many
fields the toggle gates**:

- **One gated field → `Auto <Field>`**, naming it exactly:
  "Auto item size" over **Item size**, "Auto track limit" over
  **Track limit**. The pair reads top-to-bottom.
- **A gate over a *set* of fields → verb + object** naming the
  composite: **"Auto-size grid"** gates Columns *and* Rows, so
  no single field name exists — "Auto grid size" would name a
  field that appears on no row. Do not "fix" it into the first
  shape.

Either shape must name **what** is decided automatically: no
track is itself automatic, only how many of them exist, so
"Automatic tracks" is not a label. And "Automatic" is for a
value the system *computes* — a fixed built-in default stays
**"Default"**.

:::unreleased
**Neither word fits a field that can hold no value at all: that
is an absence, and it is drawn as one.** Where a field holds no
value — because the setting then simply is not made — the cell
draws an em dash, never a menu item named after the absence.
*The system decides* is a value and takes "Automatic"; *there is
no rule here* is not a value and takes no word, since a word for
it has to agree with every sentence the surface uses for the
same state and cannot. Ask which of the two you have before
reaching for either. A table column is where this bites, having
no way to render a row that omits the field; App Rules answers
it with one list per rule, so no row has the absent cell
([Design decisions](design-decisions.md) ▸ App rules).
:::

**A boolean mode flag names the MODE on the wire, even when its
label names the field it gates (R6/#406).** "Auto track limit"
ships against wire `track.set_auto_tracks` /
`layout.track.auto_tracks`, a decided divergence: with the flag
ON, `limit` is not computed automatically, it is **ignored
entirely** (`TrackParams.trackCap` returns 0, meaning
unlimited, and the count falls out of geometry). So the wire
names a *mode* — "the partition manages itself; the limit field
is dead" — while `auto_limit` would name an automatic limit
that does not exist. The label may still say "Auto track limit"
because a label is read **beside** the field it gates, and a
wire name is read alone. This is the third clause of the
rename discriminator: relabel when the label is ambiguous,
rename the wire when the wire term is wrong, and expect a mode
flag to diverge from its own label by design.

## Interaction states

**A row's menu is one menu, on every route.** Wherever a row
offers a contextual menu (palette tiles, space rows, monitor
assignment chips, adaptive color wells), the same items are its
right-click menu, its VoiceOver actions, and its keyboard route
— a chord on the focused row, stated in the user guide's
keyboard section. One builder feeds all of them through a
single seam, so the routes cannot disagree; a surface adding a
row menu gets every route by taking the seam, and a row in the
family must be focusable so the chord has a target. (#845; the
seam and its guard are engineering-side, `.claude/rules/gui.md`
▸ the keyboard path.)

**Every animation KiwiDesk's own chrome plays honours Reduce
Motion**, the Settings window, the setup tour and both bars
included. Their motion — a caption fading in, a list springing
into its new order after a reorder, the scroll that carries you
to a search hit, a layout preview or the gaps diagram re-flowing
as you drag a slider, a hover or focus fade, the setup tour's
progress row, an App Bar's items sliding as its run changes
width, the Space Bar's drop ring sweeping — stands down when
macOS **System Settings ▸ Accessibility ▸ Reduce Motion** is on,
by dropping the *motion*, never the affordance: the caption
still appears and leaves, the rows still land in their new
order, the scroll still arrives, the preview still redraws at
the staged arrangement, the bar's items still show the run
that changed — they arrive rather than travel. This is separate
from the Motion card in Settings, which governs how *managed
windows* move; the system setting wins over both. (#989, #1069,
#1078; the engineering obligations and their guards are
`.claude/rules/gui.md` ▸ the Reduce Motion gate and
`.claude/rules/bars.md` ▸ the bars start motion in one file.)

Nothing is exempt, including the marks whose movement carries
meaning. The setup tour's waiting dot stops pulsing and stays
put, so the sentence it belongs to is still marked, and the
tour's progress row fills the same pips without the crossfade.
The Space Bar's spring-load ring keeps the ring, which says a
hold here will spring, and loses only the countdown sweep. What
you see is in the [User guide](user-guide.md); the pricing is
in [Design decisions](design-decisions.md).

**A drag source is legible at rest, not on hover.** Paint cannot
say "draggable", and hover arrives only once the pointer is
already there — so a token you can pick up wears a closed,
full-perimeter edge at a real weight, which reads as a piece
lying on the plate rather than ink printed on it. Two
obligations follow: the edge is **one weight for every kind**
(a kind moves its alpha, never its width — a sub-point stroke
is a half-pixel at 1x and can vanish on an external screen),
and **nothing that is not a drag source wears that costume**,
since a rest cue only reads as one if its neighbours lack it —
the Monitors `+n` marker, which opens a popover, takes the
shared chip rather than the pinned chip's fill (#1240).

**Picking from a picker IS the add.** Where a control's whole
job is to choose a thing that then becomes a row, the choice
commits it — there is no second button, because a confirm
pressed once after a selection asks for a decision the picker
already took. Both the app rules row and the app shortcuts row
work this way. The typed free-text path keeps a commit of its
own, because every keystroke of an identifier is a prefix of
that identifier and no moment in it means "this is the one".

:::unreleased
**Where the list may hold no empty rows, the picker names the
rule it composes.** App Rules keeps one list per rule, each with
its own picker — *Open an app in a Space…* and *Float an app…* —
so a pick lands a complete rule. One picker over a defaulted rule
authors a choice the user did not make ([Design
decisions](design-decisions.md) ▸ App rules).
:::

These pickers exclude the entries that cannot be added, but
their escape route — one file panel, the same on both rows
(#1279) — bypasses the exclusion, so a pick can still arrive
that creates nothing. **Where a pick can be refused, the
refusal speaks as a caption at the picker that refused it**,
derived from live state so it clears itself the moment the user
frees what was taken, and announced once for VoiceOver, since
the refusal can land as a panel dismisses. It is not a dimmed
control: with the button gone there is nothing left to dim, and
a dim was never a sentence. It is keyed to the picker rather
than to the section, or a list of rows prints one sentence
under every one of them.

**One escape, and it browses.** Both rows offer *Other…* and
neither takes a typed identifier: a person who needs to name an
app that is not installed writes Lua, which is where
*powerful on demand* lives, and a GUI control for that case
costs every other user a second thing to understand (#1279). The
list itself reaches one folder deep, so browsing is the rare
fallback.

Only the app shortcuts row has a refusal today (#1235); the app
rules row still drops a duplicate silently, and owes the same
channel.

**Hover confirms custom hit areas; it never creates the only
affordance.** Native bordered/prominent buttons, sidebars,
toggles, sliders, and fields keep system hover. Ambiguous
icon-only borderless actions use the shared adaptive chip
(`0.06` rest → `0.12` hover); custom full-row picker entries
use a hover-only `0.06` fill; unselected custom segments and
mode chips lift their existing fill by about `0.05`. A draggable
token chip is the one case stated as an ORDER rather than a
step, because its kinds are drawn apart by outline-versus-fill
and hover must not spend that channel: the outlined kind's
*hover* fill stays below the filled kind's *rest* fill, and the
edge carries the rest of the lift — which is also the only
channel the outlined kind has, having no fill to raise. No scale,
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
rigid grid, the scroll-duration row is dead when Animate focus
shifts is off, the bars' Content picker is inert on a vertical
edge and their Background color inert under Plain — the
dependent control stays visible and `.disabled`, never removed.
Hiding it would jump the list layout every time the governing
toggle flips and lose the cue that its stored value is
*preserved* (turn Auto-size back off and the old counts
return). Greying reads as "not right now"; hiding reads as
"gone". Precedent: the scroll-duration row, gated by
`onScrolling` (`LayoutDefaultsGates`).

**One deliberate exception: the floating save pill vanishes at
zero.** Save and Revert live in a dark pill floating over the
content column — the unsaved count with the edit target's name
("3 unsaved changes to Desk"), then **Revert**, **Save a
copy…** and **Save** — shown only while there is something to
act on, and offset left of a panel holding its own column. The
count line is the draft list's opener: while the draft has
attributed rows, clicking it pops the old → new change list,
each row a jump to the control that changed — the one such
count in the window, the header carrying none. Once the draft
is clean the pill disappears rather than greys: it is the
narration of a draft, not an inapplicable control with a
stored value to preserve. `GreyOutHidingTests` carries the
exemption; the ruling is in `docs/design-decisions.md` ▸ the
floating pill. Below 900 pt the same three verbs and the same
count dock into a full-width bar at the foot of the window —
one view, two containers, because at that width the floating
form covers the rows it is about. No draft, no bar.

**Rows go two-line below 900 pt.** A labelled row's control
normally hangs off the shared 210 pt label axis; below the row
breakpoint the label moves above it and the control starts at
the row's leading edge with the whole width in front of it,
every row in the window at once, so the alignment that makes a
section scannable is traded whole rather than per-row. Nothing
is removed and nothing shrinks. Home's card grid steps 4 · 3 ·
2 on the same thresholds, and below 820 the header's search
field collapses to its glyph, opening in place when clicked or
with ⌘K.

**A revealed target gets a transient wash, never a ring.** When
search (or any cross-reference) sends the user to a specific
place in a pane, the pane scrolls that place's *card* to the
top — a control landing without the heading that names it reads
as disembodied — and its **heading** takes a brief accent wash:
`SettingsTheme.accent` at `0.18`, a corner-6 rounded rect
bleeding 4 pt past the content, flat for 300 ms, then eased out
over 900 ms (`SettingsReveal` owns the numbers). Reduce Motion
drops the cross-fade only: the wash shows for the same ≈1.2 s
and then disappears, because a flat tint shown and removed is
not motion.

An **inline drawer** has no card of its own — it lives below its
section's heading, inside that section's card — so its scroll
target is its enclosing section, hoisted to the section's top:
the heading that names it stays on screen and the wash lands on
the drawer's own label below it (#610). A control anchored at
its own render site (`.searchAnchored`) is the third shape: the
row is both the scroll unit and the wash, so it lands at the top
edge without the heading above it — the gap edges and General ▸
Advanced's rows land this way. Where such a row sits behind a
`SettingsDisclosure`, the drawer opens first — it expands only
for its own catalog children — and the result's breadcrumb
names the drawer (#277, #1250).

Three things this must not become. **Not a ring or halo** — that
is this app's vocabulary for "this input is armed"
(`RecorderButtonChrome`, the search field's focus stroke), and
spending it here promises a keyboard focus state with no
`FocusState` behind it. **Not a pulse or scale** — the same
bouncy motion the layout schematics reject. **Not nested inside
a `GreyOut`** — `GreyOut` multiplies opacity on its content, so a
wash under a dimmed block compounds to ~`0.09` and reads as a
rendering fault; a hit on a control some other switch has greyed
still deserves full strength, which is the point of "grey,
don't hide".

Sequencing matters more than the paint. Select the destination,
then the local surface that *renders* the target (a layout's
card, `SettingsSurface.layoutMode`), then yield one layout pass
before asking the scroll proxy for the id — a `scrollTo` in the
same synchronous pass as the state change that mints the view
will miss it.

**The mode flip answers twice: motion says what just changed,
the accent-tinted frame says what is mode-gated** (#760).
Flipping the header segment to Power User washes the title band
of every *container* the flip inserted — the same transient
accent wash as a search reveal, same numbers — and the reflow
animates as pure insertion in both places the user can be
standing: Home's grid (Simple's card order is a subsequence of
Power User's) and the open area's pane. The durable half is the
frame: a container whose *presence* depends on the mode draws
its border at `SettingsTheme.containerStrokeModeGated` (1.5 pt)
in THE accent (the colour the active Power User segment wears,
never a second hue) at `modeGatedStrokeOpacity`, against the
1 pt hairline rest. Hue never carries alone: the weight step
remains and the strength is measured —
`ModeGatedFrameSeparationTests` derives the CVD floors against
both neighbours on the same edge (the hairline, and hover's
full accent) from the shipped tokens. The weight stays below
the doubling the Monitors (1.5→3 pt) and palette (1→2 pt) pairs
spend on *selected/applied*, because a mode-gated card is
present, not picked; hover keeps the full-strength accent as
its own register. The argument is `docs/design-decisions.md` ▸
*the flip to Power User answers with motion plus an
accent-tinted weight*.

Three boundaries. **Only the explicit segment flip washes** —
the implicit promotion (search or a cross-reference landing in a
Power-User-only area) already owns its arrival wash. **The flag
is the site's own offer predicate evaluated at `.simple`** —
never a hand-negated copy — so the weight states the same fact
as presence: Monitors is unmarked on a multi-display machine,
the Layers card is unmarked the moment a layer exists, and when
config presence changes the flag at rest the weight steps with
no wash. **The way back to Simple is a plain fade.** Reduce
Motion keeps the wash flat for the same ≈1.2 s and drops only
the reflow and the cross-fade. The vocabulary is
container-granular: a per-row *control* offer the mode also
unlocks (the Spaces "Customize…" cells) has no container border
to weight and appears plainly, and which offers stay unmarked
is data in `ModeGatedChromeTests`' `unmarked` map, not a
skipped site. `ModeGatedChromeTests` pins the chrome,
`SettingsModeRevealTests` the timeline.

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

**The parked action has to genuinely discard** — flipping a
flag without reloading leaves the save pill up, still claiming
unsaved changes, after the user agreed to lose them, and prompts
a second time on the way back. **Return early on a no-op**
before calling the gate: it cannot tell an inconsequential
action from a destructive one and will prompt for nothing. Do
not solve this by hiding or disabling the action while dirty —
prompting keeps it visible, which is what "grey, don't hide"
asks for. A source-scanning guard (`DiscardGateParityTests`)
fails the build on an ungated path; see
`docs/design-decisions.md` for why the gate sits at the call
site and which exceptions are deliberate.

Greying applied across a whole editor (#520, #527):

- **Read the claim aloud before writing the gate.** Greying
  row A off setting B says *turn B on and I act*; where A keeps
  working without B, the intent was a FLOOR — "don't leave
  yourself with none of these" — and a greyed control is the
  wrong vocabulary for a floor. Sticky's on-window mark is
  ungated off the Space Bar for that reason
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
  override is what renders greys the only editor for a value
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
  (#527): shut, the values inside are as hidden as if the rows
  had been removed; open, the user is stranded in a wall of
  dimmed controls. Put the `GreyOut` on the drawer's content
  and leave the label live. A block gate therefore must not
  wrap a section that *contains* a disclosure: push it down to
  the siblings, or pass the gate into the child view
  (`AdvancedColorRows(allows:gateHelp:)`, which the bar colour
  cards hand the same gate on both sides of their "More colors"
  drawer). Expansion state is preserved across the toggle —
  with the label live, closing is one click.
- **A block gate's explanation lives on a live anchor, not
  inside the block.** SwiftUI's `.disabled` is cumulative and
  `.disabled(false)` is a no-op, so every `HelpButton` inside a
  greyed block is dead (#527). A *block* gate (a whole editor
  or multi-row group) therefore renders a live `?` outside the
  gated subtree, passed only while the gate is active and
  carrying the why-off and how-to-enable copy, anchored on
  **the nearest live label that scopes exactly the gated
  content** — the `SettingsSection` header (its `help:`
  parameter) when the whole section body is gated, the drawer's
  live disclosure label when only the drawer's content is. A
  header `?` may scope a card whose census-exempt rows stay
  live (the App Bar card's Show-it-in switches) exactly when
  its copy points at them ("turn one on below"). When the gate
  must reach inside a child view to do this, pass it in
  (`AdvancedColorRows(allows:gateHelp:)`) rather than wrapping
  the child from outside, which would disable the anchor too. A
  *control-scoped* gate — one row, its gating control directly
  adjacent (Background style over Background size, a toggle
  over its slider) — keeps just the `GreyOut` hover string: the
  adjacency answers "why". **Adjacent is derived** (#815): same
  area, same container, and the gating row drawn whenever the
  gated one is — two rows inside one disclosure qualify, a row
  on the same page but in another card does not, and that last
  case draws its reason inline instead (`GateReasonPlacement`,
  argued in `docs/design-decisions.md` ▸ usable without a mouse
  is a second claim). A **master** control higher up the *same*
  page, driving rows in later cards, is not a fourth case:
  where a shared control would need dimmed per-instance twins
  to explain itself, delete the twins instead
  ([Design decisions](design-decisions.md), #754). What a
  master owes once the twins are gone is an
  **acknowledgement**: while the values it is about to
  overwrite disagree it carries a `?` saying so ("The three
  strokes are set differently right now; choosing here sets
  all three") and stays live, and a segmented picker whose pill
  can hide for an unmatched value shows *no answer* rather than
  asserting one. A *remote* control-scoped gate (the gating
  field lives on another **destination**) has no adjacency to
  answer "why", so it takes a **live pointer whose sentence
  names the destination to go to**, in one of two shapes. Where
  the block has a live label, the pointer is a `?` on the
  nearest live label above the dimmed rows: on Advanced Colours
  every gate is remote, so its Borders card and each Drag
  column carry a header `?` with no block gate at all
  (`AdvancedColorsHelp`). Where it does not, the pointer is a
  `CrossReferenceRow` drawn under the dimmed rows and outside
  the dimmed subtree, so it stays clickable while they are
  inert — the per-space override editor's Grid auto-size and
  Track auto-limit rows, whose switches have no row in that
  editor (`SpacesGateHelp.remote`, held to being a live link
  rather than a `Text` by `GateReasonPlacementTests`). Both
  shapes state the live fact as well as the destination —
  `LayoutCard`'s app-bar `CrossReferenceRow` is the model ("The
  monocle App Bar (currently on) is configured in …").
  Per-control `?`s inside a gated block stay visible-but-dimmed
  like every other row member; the anchor covers the meantime.
  Guarded by `GreyOutAnchorTests`.

**An auto toggle greys with the slider it governs** (#1377).
Where an `AutoGatedGroup`'s slider carries a row gate, the
toggle has no effect under that gate either, so the group is
wrapped in the gate's `GreyOut` and the toggle's row declares
the gate in the census. Auto Glow Size and its slider are the
class's only members today.

The gap masters take that same acknowledging shape over a
"mixed" readout (#1383): a grey would name a problem and
withhold the one gesture that fixes it. The per-edge drawer
under them pre-expands so the values about to be overwritten
are in view. A master whose followers disagree acknowledges
through the resolver's `followersDiffer` and the label's `?`,
and never takes a census gate.

Which of the two remote shapes a row takes follows from what is
dimmed, not only from whether a live label exists (#1310): a
header `?` scopes the CARD, so it answers for a greyed block,
while ONE greyed row inside a live card takes a
`CrossReferenceRow` directly beneath its grid, outside the
dimmed subtree — the Space Bar colours card's *Focused window*
row, whose picker lives on Bars, draws
`AdvancedColorsHelp.focusedItemReference` there, and the Border
colours card's *Unfocused windows* row draws
`unfocusedReference` the same way while the ring is on, each
linking the destination in the sentence; the Borders header `?`
answers only for the ring being off. The argument is
`docs/design-decisions.md` ▸ *a dim is not a sentence*.

A control whose *only* consumer is off may still have a second
one. The App Bar's "App symbol style" stays live even when no
bar shows, because `iconSource` also drives the shortcuts
panel's Apps band — check for a second reader before dimming.

The tree-wide half of the convention is guarded by suites that
scan for a *shape* rather than listing the greyed controls,
since a list cannot see the next site. `GreyOutParityTests`
pins the gates that must be present; `GreyOutHidingTests` hunts
the conditional that removes a control instead of dimming it.
The absence side is per-row — no scan can know which control
*should* carry no gate — so a row that earns one cites its own
guard where the bullets above do.

**Sentinel values read as words, not numbers.** A slider gated
by an Auto toggle stores `0` as the sentinel but its readout
prints "Automatic" while gated — "0 pt" next to a greyed slider
reads like a broken value. The full word, not "Auto": a readout
is a value, and the column is widened to hold it (see
*"Automatic" is the word for a value*, above). The slider
itself stays floored at 1 so dragging can never write the
sentinel (#381).

**A control may relabel with the mode it serves.** A
mode-dependent role gets a mode-dependent name: the scrolling
layout's slot size is **Column width** on a horizontal axis and
**Row height** on a vertical one (`SlotSizeRows`) — one stored
field, two honest names. Prefer relabeling an existing control
over adding a parallel enum value or a second field.
