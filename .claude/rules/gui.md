---
paths:
  - "Sources/KiwiDesk/**"
---

# Settings app & SwiftUI GUI

Canonical for this subsystem (AGENTS.md §2.7 and §5 index it).

## North star — simplicity, intuitiveness, Apple-native, in that order

**"Apple-native" binds behavior, not the Settings GUI's visual
idiom** (owner ruling 2026-08-02, argued in
`docs/design-decisions.md`). Controls behave the standard way —
focus, keyboard, VoiceOver, dark mode, drag and drop are system
conventions, non-negotiable. The window's information
architecture and look are KiwiDesk's own: the #678 redesign
deliberately breaks with System Settings, which is explicitly
not the bar. Two obligations follow — don't reject a redesign
surface for breaking System Settings' idiom, and don't read
"GUI ours" as licence for non-standard controls. Simplicity and
intuitiveness stay first and still break ties. When unsure, ask
a `ui-designer` consult framed by these priorities before
inventing a layout.

**Approachable by default, powerful on demand.** A new user gets a
good tiling setup with almost no configuration; that simplicity
must never *cap* what's achievable — beneath every easy surface is
a deeper layer (Lua config, profiles, advanced layouts, per-space
overrides) there when wanted and never required to begin. Depth is
a capability the user grows into, not a cost paid upfront. The
#326 panel is the shape: a glance surface with one "Edit in
Settings…" bridge down to the full editor.

**The GUI curates, Lua is open.** The GUI is the opinionated gate
that decides what most people *should* touch (safe defaults for
the rest); Lua is the unrestricted power layer. A Lua setter
clamps or rejects only genuinely-broken / unrenderable values (an
invisible alpha, a >1 factor, a malformed color) — never to
enforce taste or a ratio the GUI keeps tidy. Risky-but-valid knob
→ hide it from the GUI, expose it Lua-only, and don't add a guard
that second-guesses the power user (the bars' `dim_factor` /
`active_dim_factor`: Lua-only, clamped to a legible range yet free
to invert the dim ladder).

## Settled conventions — extend, don't relitigate

- **Group by topic, never by widget type.** A toggle and the
  control it gates are one decision, so the toggle sits directly
  *above* the control it gates, never in a separate "toggles"
  block. Colors, which gate nothing, may group by type for grid
  scannability — and since #678 Phase 3 they do so wholesale, on
  their own destinations. **A colour renders in exactly one
  area**, which is Advanced Colours; adding a `HexColorField`
  anywhere else in `Settings/` reds
  `SettingsColorSurfaceTests`, whose allow-list is the one copy
  of who may. Structure (is it drawn, how wide, how round) stays
  with its feature; only the tint moves.
- **Grey, don't hide** a control with no effect in the current
  mode (#171) — keep it visible and dimmed. This covers a control
  that *would* work in another mode, so dimming says "switch that
  on and I act".
- An affordance for a channel that **does not exist yet is removed
  outright**: dimming cannot revoke the promise its shape makes,
  and it reads broken instead of forthcoming (the site's App Store
  badge, removed rather than greyed — permanently, the store being
  out of scope; see `docs/design-decisions.md`).
- **The live preview leads** its editor — in areas WITHOUT a
  detail panel. An area in `SettingsDetailPanelOffer.offering`
  watches its draft in the panel column instead, and its cards
  carry no duplicate preview (`DetailPanelTests` holds the
  migration and the offer set; the argument is in
  `docs/design-decisions.md` ▸ two columns).
- **A picture whose object is NOT the draft goes in a sheet, and
  writes nothing** (#859). Choose the container by whose object the
  picture is — draft → the panel, anything the user is not editing
  → a sheet off the thing that names it — and keep the sheet
  read-only, a sheet that grows a commit being a dialog wearing
  the wrong chrome. A read-only sheet also answers the keyboard
  both ways: Return on its one dismissal, and Escape, which a
  `Button` cannot carry beside `.defaultAction` so the content
  view takes `.onExitCommand`. `SheetPresentationSeamTests` is the
  register of which files may host one and holds the dismissal
  contract; `PresetPreviewSheetTests` adds the structural half
  that matters most — the sheet takes no `SettingsModel`, so
  reaching the draft is a new stored property rather than a
  one-token edit. **Why**, in full, is
  `docs/design-decisions.md` ▸ the panel's object is the DRAFT;
  the popover/alert/sheet split is `docs/ui-patterns.md`'s. Do not
  re-argue either here.
- **A presentation whose content is built from ONE row is handed
  that row** — `.sheet(item:)` / `.popover(item:)` over an
  `Identifiable` request, never `isPresented:` (#843). Drawn at
  the presentation rather than at the sheet on purpose: the reason
  is that `isPresented:` builds content from parent state written
  in the same tick, which has nothing to do with which chrome is
  used, and the defect was found on a popover. Sheets are simply
  where the tree has no legacy call sites, so
  `SheetPresentationSeamTests` can hold it absolutely there while
  the existing `.popover(isPresented:)` sites are grandfathered.
  (An earlier draft of this bullet said how many those are, and was
  wrong — in the commit whose subject was three other false
  counts. A count in a rule file derives or cites a guard; this one
  can do neither, so it is gone rather than corrected.)
- **A preview that claims to show engine behavior asks the
  engine.** Never re-implement a rule the engine owns beside the
  drawing of it — call it, and where the shape does not fit, wrap
  the call once (`SchematicPlacement.splice` over
  `Space.insert(_:placement:)`). A copy is right the day it is
  written and drifts the day the rule moves, and a preview that
  drifts is worse than no preview: it teaches the user something
  the app does not do. It also has to survive whatever the
  preview's own controls can reach — the five schematics' copies
  of the placement rule were constants until a window-count
  slider made them arithmetic across 2…12, and two arms of one of
  them then marked the wrong window as focused (#702).
  `LayoutSchematicPlacementTests` holds each schematic to what
  its frame promises and
  `LayoutSchematicPlacementScanTests` reds on the next copy.
  **Where a frame sorts the array into ZONES, guard the
  membership and not only the sizes**: Stack's two zone reads
  could be swapped end for end with the sizes still adding up
  and the whole suite green (#707), so the partition is asserted
  against `StackLayout.partition` — the boundary rule itself —
  in `LayoutSchematicZoneTests`, which also holds #313's mirror
  to `StackLayout.mirrorsMasterZone`.
  Check *which* engine owns the rule before calling one: track
  spawn is `Space.insertIntoTrack`'s, not
  `Space.insert(_:placement:)`'s, and the two agree on position
  only because `LayoutSchematicTrackEngineTests` now requires it.
  Where a preview models part of an engine's rule, say which part
  and file the rest (#708 for the unmodelled spill).
- **A schematic draws ONE frame, and a fact about motion goes in
  the caption.** Never add a second mini-screen, an arrow between
  panes, or a sub-caption under one: a pair denotes two *states*
  and leaves the tween to the reader, so it buys no motion while
  costing double the width in a strip built for comparison — the
  argument is in `docs/design-decisions.md`, and
  `LayoutSchematicScaleTests` reds on the retired vocabulary
  coming back. Two obligations follow from putting the fact in
  words instead:
  - **The caption switches with the control that changes it.**
    One string spanning a picker's options states the odd
    option's fact under all of them, so every option that does
    not have that fact carries a sentence about one that does,
    and VoiceOver asserts it over a frame that was never drawn
    (`LayoutSchematicCaptionTests`). Where the odd option's
    frame is another option's to the pixel, the words are the
    only thing that can tell them apart at all.
  - **A caption may not point at a mark the frame does not
    draw.** A finite canvas crops a row long before the row
    ends, so a clause naming the insertion `+` is conditional on
    the `+` being on the frame (`drawsInsertionMark`, held to
    the drawing by `LayoutSchematicCaptionTests`) — and that
    condition owes the SCALE as well as the row, since a
    thumbnail whose monitor fills its canvas has no margin for
    the neighbouring slot to reach into.
- **A thumbnail drops a fact it has no room to render — by not
  drawing it, never by shrinking the frame around it**, and by
  skipping the drawing rather than leaving it to the frame's
  clip, which does not crop where a reader assumes
  (`SchematicCanvas.screen` states the mechanism). Scrolling's
  off-monitor ghosts are the worked case, drawn at `.panel` and
  left undrawn at `.tile`; the argument for the trade lives on
  `SchematicScale`, whose doc comment says what a thumbnail is
  *for*, and `LayoutSchematicScaleTests` holds both halves.
- **Defer per-control "why" to contextual help** (the planned `?`
  affordance, #94) rather than bloating labels or captions with
  glosses that would later duplicate it. A caption's job is to
  label what's shown, not to teach — with one carve-out, named
  here so the two rules are not read as contradicting: **a
  schematic's caption also carries whatever its one frame cannot
  denote.** That is the one-frame bullet above, and it is not
  licence to gloss: it applies where the picture is the
  explanation and the
  missing piece is motion, not to a row whose control could take
  a `?` instead.

Shared control conventions (help affordance, control choice, row
tiers) are elaborated in `docs/ui-patterns.md`; the durable
product/UX rulings behind them in `docs/design-decisions.md`.

## No window controller changes the activation policy

A content window comes forward with `NSApp.forceFront`, which
shows and activates it from `.accessory`. Never
`setActivationPolicy` from a controller, and never a helper that
wraps one.

`ActivationPolicySeamTests` holds the line and **its `allowed` map
is the one copy of who may** — today launch and the
single-instance alert, each for a reason stated there. The
argument, and why the rule is phrased as an obligation on
controllers rather than as a claim about the process, is
"Permanent accessory mode" in `docs/design-decisions.md`.

## A window that finishes something already begun comes forward

**It activates at the moment it appears, a window a framework
opened included — and it refuses any affordance that parks it out
of that activation's reach.** `.accessory` earns no Dock tile, so
`requestUserAttention` and every other Dock-borne nudge is inert
here, and activating a process deminiaturizes nothing. The
corollary under "Permanent accessory mode" in
`docs/design-decisions.md` argues why, and scopes it — an
unsolicited OFFER is governed by the opposite rule and must not
take the screen.

Take the seam that NAMES the moment the window appears; a
callback that merely fires near it is a race, not a fix. #1011 is
the worked case (Sparkle 2.9.6, the version `Package.resolved`
pins — a bump re-checks it): `UpdatePromptDriver` overrides
`showReadyToInstallAndRelaunch`, and `UpdatePromptPolicy` refuses
the status window's minimize button.

**A guard on such an override pins the WIRING beside the body**
— `UpdatePromptWiringTests` holds that the framework is shown
through that driver and not a stock one, because an override
left in place and no longer reached is how the defect returns
with every count still at one. It is a suite of its own for
that reason: `UpdatePromptFocusTests` reads what the override
DECLARES and structurally cannot see what it is wired to.

## A window that must clear the bars derives its level

The bars render at `BarPanel.level`. **A window that must not be
covered by one takes `BarPanel.aboveLevel` rather than writing
`.floating` — or `.floating` plus a step — again at the raising
site.** The two spellings are one fact ("the bars are here, and
this is above them"), and written apart they drift the day the
bars move. The first-launch tour is what asked for the constant
(#828), and it takes it only once the grant lands: raised
earlier it would sit over the System Settings window the grant
step sends the user to.

Not every overlay wants that step, and the ones that do not are
deliberate: some of the app's own panels are the bars' PEERS and
settle with them in raise order. Which they are, and why each
stays a peer, is `BarPanel.level`'s own doc comment — the
authority for this rule, and the one place that list lives.

## File layout

Section bodies in `Settings/Sections/`, their widgets in
`Settings/Components/<area>/` — one directory per area, and
where that area is a destination the directory carries the
destination's name, so **renaming a destination renames its
directory in the same change set** (Appearance became
GapsAndBorders with its page in #678 Phase 3).
Shell/model files and root-composed widgets live at `Settings/`
root. `Common/`
admits only primitives shared across multiple component areas;
root-owned widgets stay at `Settings/` root. `Settings/Census/`
holds the `SettingKey` settings census (#678) — data enums only,
never views.

## The settings census (#678, redesign coexistence)

`Settings/Census/` records every setting's redesign placement,
tier, gate and text keys, and the redesigned GUI renders from
it. **Bars, Colours & Motion, Advanced Colours, Shortcuts,
Layout Defaults, App Rules, General, Gaps & Borders, Spaces &
Layouts, Profiles, Monitors and Behaviour render from it now**
(#678 Phases 2-3): each
carries its own order list and a census-render suite pinning that
order to the census (`MonitorsRowOrder` /
`MonitorsCensusRenderTests` is the newest pair), so a row in a
`ForEach`-rendered container moves by editing the census — with
the bespoke edge below. This bold list is itself a hand-kept
claim with no guard,
so an added area joins it here in the same change that ships its
`*RowOrder` (General was silently dropped from it once).

That promise has a stated edge in Shortcuts, and reading it as
unqualified will waste your afternoon: three containers there
are BESPOKE views, not `ForEach`es over an order list — the
layer strip, the app list and the raw-Lua drawer. Their order
lists exist so the census still records those rows for the
placement table and for search, and the guard holds their
MEMBERSHIP, but editing one moves nothing on screen. Which
three is data — `ShortcutsRowOrder.bespokeContainers`, asserted
by `ShortcutsCensusRenderTests` — so a fourth going bespoke has
to edit that set; check it before assuming an edit will show up.

General, Gaps & Borders, Spaces & Layouts, Profiles, Monitors
and Behaviour push that edge wider: EVERY container in them is
bespoke
(`GeneralRowOrder.bespokeContainers` /
`GapsBordersRowOrder.bespokeContainers` /
`SpacesRowOrder.bespokeContainers` /
`ProfilesRowOrder.bespokeContainers` /
`MonitorsRowOrder.bespokeContainers` /
`BehaviorRowOrder.bespokeContainers`, each the whole set,
asserted by `bespokeMeansNoForEach` in each area's render suite),
so their order lists are membership-and-search only and editing
one moves nothing on screen. In Profiles the reason is
structural rather than incidental: every container there expands
one key into a row per live instance, which is what an order-list
`ForEach` cannot express at all — the paragraph below owns that
seam. Monitors is the far end of the same argument and worth
knowing before you look for a list to reorder: its placement
container is a PICTURE, positioned by the real display
arrangement (`MonitorArrangement`), so its rows have no reading
order to state — a card's place on screen is where that monitor
is on the desk.

**The census's unit is a SETTING, and one setting may draw many
rows.** A keybinding family is the worked case: `focusDir` is
one census case that puts four rows on screen and `goToSpace`
one that puts a row per live space, so the Shortcuts area needs
a second seam the plain areas do not — an order list saying
*where a family sits* and `ShortcutsFamilyRows` saying *what it
draws*. Profiles has the same pair (`ProfilesFamilyRows`), and
there the expansion is per live INSTANCE in every container it
draws — a row per saved profile, per Desktop, per preset, held by
`instanceCounts` in `ProfilesCensusRenderTests` because set
equality over `SettingKey` cannot see a collapse to one row.
Monitors has the pair too (`MonitorsFamilyRows`), and adds the
case where several families must be read TOGETHER: its three
placement families partition the declared spaces — carded (a
chip), following main (a chip in the tray), or waiting on an
absent monitor (a row of its own) — so each one's own count can
be right while a space falls through all three. Only a guard
over the UNION sees that, so a family joining or leaving that
partition joins `MonitorsCensusRenderTests`'
`everySpaceLandsExactlyOnce` in the same change. An
area whose keys expand this way owes both halves and
a guard over each; **which keys may legitimately expand to
nothing is data, never a skipped branch**, because a renderer
reading `rows(for:) ?? []` cannot tell a hand-drawn container
from a family that lost its rows, and a guard that skips `nil`
goes green on exactly the disappearance it exists to catch
(proven against `ShortcutsCensusRenderTests` before it shipped).

**A census `gate:` is resolved through its area's gate
resolver — whatever the gate decides.** Not "presence gates are
census-owned and greying gates are wiring-owned": `BarsGates`
already resolves census gates and everything it decides is
greying, and `SettingRuntimeGate`'s cases split across greying,
surfacing and hiding, so that line would cut the enum in half.
The rule that needs no guessing:

- a declared gate is answered by the resolver
  (`BarsGates`, `ShortcutsGates`), never
  re-implemented inline beside it — a renderer whose predicate
  drifts from the declaration greys the wrong row, or hides one
  entirely, and the tier case is invisible by construction
  (`ShortcutsGateTests`, written after three such
  violations passed the whole suite);
- a predicate the resolver **cannot** answer from the declared
  owner — resolved shown-bar values, auto sentinels, live editor
  state — is a wiring predicate and was never a census gate;
- **which declared gates the resolver cannot answer is data**
  (`ShortcutsGates.resolved` / `.resolvedElsewhere`), so
  the gap stays deliberate and a new gate landing in neither
  set reds.

The census gate resolvers share ONE shape (convergence
2026-08-03): a struct keyed on a row's own `SettingKey` — and,
where the area block-greys, `containerReason(for:
SettingsContainer)` — returning a REASON case rather than a Bool,
with a `GateHelp.sentence(for:)` companion where the reason is a
grey the user reads, and the answered / answered-elsewhere split
held as `resolved` / `resolvedElsewhere: Set<SettingKey>`. The
shape carries every flavour a census gate can be: a container
block gate (`BarsGates`, `GapsBordersGates`), a saved-config
`.runtime` GREYING gate (`GapsBordersGates`' gap masters), and a
`.runtime` SURFACING gate (`ShortcutsGates.onlyDefaultLayer`,
whose non-nil reason WITHHOLDS a row behind its offer rather than
greying it — so that one resolver carries no `GateHelp`, there
being no inline sentence to render). **A census-rendered area
resolves its declared census gates through a resolver of this
shape; a Bool-returning or otherwise divergent census-gate
resolver is the regression this convergence removed.** Each
area's gate-wiring suite pins that its VIEWS consult the resolver
rather than re-deriving the predicate inline — the dead-resolver
trap General shipped, where the resolver was built only in tests
(`BarsGateWiringTests`, `GapsAndBordersGateWiringTests`,
`ShortcutsGateTests.layersCardConsultsTheResolver`), gate-granular
so a file resolving two gates reds if EITHER goes hand-rolled.
`ShortcutsGates.resolvedElsewhere` holds its one gate
(`.luaImportAvailable`) because that is a live-editor-state
predicate the saved config cannot answer — not because of any
shape split, which no longer exists.

**Consulting a resolver is not drawing what it answered, and a
SURFACING gate leaves nothing behind to prove the difference.**
A greying gate ends in a dimmed control a test can find; a
surfacing one ends in an `if` inside a `body`, and every guard
above it — the resolver's own suite, the census parity, the
family expansion — passes whether or not that `if` was ever
written. Monitors shipped a cut where five such branches could
each be deleted with the whole suite green (guard-prover,
2026-08-04): the orphaned-pins card, both of the picture's
notes, the chip overflow and the tray. So a view drawing off a
resolved answer owes a needle naming the BRANCH, not only the
consult — `MonitorsGateWiringTests`' `surfacingBranchesAreDrawn`
is the worked example, and a new surfacing branch joins it in
the same change. Two authoring rules the same run paid for:
key a needle on the site that USES the value (a bare
`overflowChip(` matched the helper's own declaration; a bare
`rows.chips(on:)` matched a tooltip while the chips went
hand-rolled), and strip comments before matching, or a comment
quoting a deleted key stands in for the call site.

Where the value is already arithmetic, the paragraph below on
live previews owns which half a scan is for; a branch that was
never written at all is what it cannot see.

`AdvancedColorsGates` is deliberately NOT one of these resolvers
and is not the regression the rule names: it answers no census
`gate:` of its own. It DELEGATES the two bar block gates to
`BarsGates` (`var bars`), and otherwise picks the SENTENCE for
greys whose owning switch lives on ANOTHER page — a `Bool` +
`String?`, `@MainActor` wiring-and-copy job, not census-gate
resolution. The line is whether the thing answers a declared
census `gate:`; if it does, it takes the shape.
`LayoutDefaultsGateTests`' `everyGatedRowIsResolved` holds both
halves: it reds when a ROW gate this resolver does not answer
appears, and it pins that no container in the area declares a
gate at all — because the resolver has no `containerReason` arm,
so a container gate here would grey nothing, silently, and the
row-gate net cannot see one. A resolver returns the *reason*
rather than a Bool where the area greys with an explanation
(`LayoutDefaultsGates.InertReason`, rendered by
`LayoutDefaultsGateHelp`) — why-you-cannot is always inline, so
the grey and its sentence must not be two decisions that can
disagree, and a reason CASE keeps the whole resolver assertable
off the main actor.

**Config presence expands the Simple surface.** Anything that
already EXISTS in the user's config — a layer, an imported
binding, an override — is displayed in BOTH Settings modes and
enhances the simple one; Simple withholds only the OFFER to
create, and that offer retires itself once the first one exists.
So a row whose gate says the thing is already there is
`SettingTier.immediate`, never `.showMore`, and its gate is what
gives the tier meaning — `immediateRowsAreGated` pins that every
`.immediate` row carries one. Reading such a row as `.showMore`
hides a user's own configuration from them, which the Shortcuts
area shipped once. The argument is in `docs/design-decisions.md`.

**A live preview that takes a window count owes the arithmetic
a guard, not a source scan.** Layout Defaults' schematics
simulate the count the preview's slider supplies, and a
schematic that takes the count and draws a constant satisfies
every substring a scan can look for while answering nothing —
guard-prover shipped that mutation past the first cut of
`LayoutSchematicCountTests` — the general form of that failure
is [rule-authoring.md](rule-authoring.md)'s "Prove a new guard
reds". So each schematic's count-derived
quantity is internal rather than private and asserted directly,
and the source scan stays only for what arithmetic over
existing types cannot see: a NEW schematic that never took the
count. A suite reading those quantities is `@MainActor`, since
they are `View` properties and reading one off the main actor
traps the runner instead of failing an expectation. One residue
is knowingly unguarded and stated so it is not mistaken for
coverage: nothing pins that a schematic's `body` still *draws*
the quantity it derives, so a correct derivation feeding a
constant frame passes.

**A census-named row that draws no visible label authors its
label key as an `.accessibilityLabel` — and gives back whatever
that label displaced.** The App Rules sentence is the worked
case: its two menus sit inside a statement with no
label beside them, and the census still names those rows by
`app_rules.space` / `app_rules.float`. That one call site is
load-bearing three ways — VoiceOver has nothing else to call the
control, `SettingKeyLocaleTests` requires the key in every
locale, and search indexes it — and dropping it is silent in all
three until a locale prunes the key.
`AppRulesCensusRenderTests`' `facetsKeepTheirLabels` matches the
modifier's SHAPE over stripped source, because an earlier cut
accepted any mention of the key and went green when the
modifier became a `.help()`, leaving the menu with no
accessibility name at all.

The second half is not a nicety, and this instruction is what
produced the defect that forced it: **`.accessibilityLabel`
REPLACES the name SwiftUI derives, which for a `Menu` is its
current choice.** Both facet menus announced "Space, pop up
button" and never *which* space, for as long as they shipped —
a sighted reader takes the value out of the sentence, so nothing
looks wrong, and every guard was green because the label was
exactly where it was required to be. So a control named this way
owes an `.accessibilityValue` carrying what it announced before,
drawn and spoken from ONE expression
(`AppRuleRow.spaceFacetLabel`); `facetsAnnounceTheirValue` holds
the count. Read the rule as: whenever you name a control for
VoiceOver, ask what naming it took away.

**A sentence with controls in it is one localized frame, not
connectives between fixed stack positions.** Author the frame
with positional specifiers, split on them, and emit the pieces
in the translation's order (`SentenceFrame`,
`SentenceFrameTests`) — a row assembled from `"opens in"` and
`"and"` keys placed by an `HStack` cannot be reordered by any
catalog, and this app ships four verb-final locales. The
argument is in `docs/design-decisions.md` ▸ App rules.

**And the stack that lays such a frame out adds no spacing —
the frame's own literals carry it.** A per-segment gap reads as
merely wide in English, whose literals already carry their
spaces, and is wrong outright wherever the literal between two
slots opens with a particle that must hug the noun before it
(`は`, `에`): the gap tears it off, in exactly the languages the
frame exists for. So the spacing is the translator's too, and a
row drawing one owes an allow-list naming any stack that may
space its children and why — `AppRuleSentenceLayoutTests`, whose
`allowed` map is the one copy of who may. What no source scan
can reach is per-segment spacing that is not a stack argument —
a `.padding`, a `Spacer`, a `.frame` — so that residue is
stated in the suite rather than chased.

**A capability unlocked in one list stays scoped to that list**
(#678). Once a profile carries a single shortcut override, the
override affordance is live on every row of that list — never
re-earned per row — and it turns nothing on elsewhere in the
app. Do not gate such an affordance on a Settings mode: mode
depth is per AREA (`SettingsArea.minimumMode`), never per row,
and nothing is read-only because of the mode.
`ShortcutsCapabilityUnlockTests` holds those three.
The fourth clause has no guard because it needs no code —
**never give an override resolver a mode parameter**;
`KeyLayerOverride.resolved(onto:)` takes a base list and
nothing else, and a flag deciding which shortcuts fire is a
second config the user cannot see.
Container-level greying is census-driven there (the container
gate plus `exemptFromContainerGate`), but a ROW's grey
predicate stays wiring-owned even in a census-rendered area —
the census `gate:` names the owning setting, the exact
predicate (resolved shown-bar values, auto sentinels) lives in
the row builder. A Phase 3+ area copying the Bars shape copies
that split too; don't expect editing a row's census gate alone
to change on-screen greying — and the reverse obligation holds
in census-rendered areas: **retargeting a row's grey predicate
updates that row's census `gate:` in the same change set**, or
the declared owner and the wiring drift apart with every test
green. Until
the *other* areas render from the census, their hand-written
views stay the behavioral authority — so **a change to a
Settings row's placement, its `GreyOut`/`disabled` gating,
or its `L()` keys updates the matching `SettingKey` entry in the
same change set.** The census's gates were transcribed from the
live wiring once; nothing mechanical can re-derive them from
views, which is why the obligation sits here, where every
`Sources/KiwiDesk` edit loads it. The 4f guards
(`SettingKeyCensusTests`, `SettingKeyLocaleTests`,
`SettingKeyModelParityTests`) catch the model and locale halves;
placement and gating drift only a reviewer — or this rule — can
catch. Text stays key-only: `scripts/extract-keys` reads the
views' `L(key, english)` call sites, so a change that deletes a
view must re-author its keys through a scanner-visible shape in
the same change or the keys are pruned from every locale.

## Home, the shell (#678 turn 9)

Home (a card grid; `model.destination == nil`) is the only
navigator — there is no sidebar. The conventions a shell change
must keep:

- **One offer predicate.** Whether a destination is reachable —
  the Simple/Power-User gate, the computed Monitors promotion, the
  #18 stored-profile axis — is answered by
  `HomeCardOrder.isOffered`, consulted by the grid, the
  selection repairs and the `settingsNavigate` guard alike;
  a hand-negated copy at any of those sites is the drift #18's
  one-predicate rule exists to prevent
  (`HomeCardOrderTests`). The `displayCount` axis has NO
  selection repair, deliberately — a display disconnect never
  pops an open area; `HomeCardOrder.isOffered`'s docstring
  carries the argument.
- **Navigation into a mode-withheld area switches the mode,
  never refuses** (`ensureModeAdmits` — search and
  cross-references index both modes), and a flip back to
  Simple pops a `.powerUser`-gated area to Home
  (`SettingsModeNavigationTests`). User-facing labels are
  "Simple" / "Power User", wire and label alike
  (`docs/localization-naming.md` owns the pair's policy).
- **A card is an answer**: subtitles derive from the draft
  (`HomeCardContentTests` holds the derivations), previews
  come only from renderers that already ask the real data, and
  only the Shortcuts conflict may shout — glyph + text, never
  hue alone. A profile card's picture rides the desktop plate
  (#786), drawn from the draft in the user's palette through
  the `schematicPalette` environment — never an init
  parameter — with the fold floored against the plate; the
  two card heights derive from the group partition.
  `HomeCardChromeTests` pins the heights pair, the plate's
  shape, silence and group parity and the stroke-above-clip
  order; `HomeCardPaletteWiringTests` the per-struct palette
  consults, the floor and the shared border-width remap.
- **A new surfacing branch or one-line wiring decision in the
  shell joins `HomeSurfacingTests` in the same change**, keyed
  on its use site — the Monitors lesson, which this shell
  inherits whole.
- The mode pick persists via `SettingsModePreference`
  (`UserDefaults`, absent = Simple, never `gui.json`); the
  save pill's unsaved count (the header carries none — the
  pill is the draft's one narrator) comes from
  `SettingsDraftDiff` via the popover's own row list, and that
  diff's every-leaf attribution net (`SettingsDraftDiffTests`)
  is what a new `GuiConfig` or `TilingSettings` field reds
  until its census row exists. A surface stating an N beside
  a visible list derives the N from that list's rows, never
  from the settings count — a per-instance family made the
  two disagree on sight (owner 2026-08-10).
- **The mode flip's reveal has one entry point and two
  channels** (#760): only the header segment's explicit flip
  washes (`flipSettingsMode` — `ensureModeAdmits`' promotion
  stays on `setSettingsMode`, silent), the wash rides title
  bands alone, and mode-gated *presence* draws the
  accent-tinted frame (`containerStrokeModeGated` at
  `modeGatedStrokeOpacity` — the mode's own colour, never a
  second hue, the weight step keeping a hue-free channel) from
  the site's own offer predicate evaluated at `.simple`, never
  a hand-negated copy. `ModeGatedChromeTests` pins the chrome
  and the predicates — membership is DERIVED (any Settings
  offer consulting `.powerUser` threads `modeGated` or argues
  its exemption in that suite's `unmarked` map, the one copy
  of who may stay plain) — `ModeGatedFrameSeparationTests`
  derives the frame's CVD floors from the shipped tokens, and
  `SettingsModeRevealTests` pins the timeline; a new
  mode-gated container passes `modeGated:` to its container
  shape.

## Responsive width (#678 turn 17a)

The window is the user's to make narrow — tiled like any other
window (#678 item 18: `SettingsWindowController` stamps
`OwnWindowTiling.identifier` and
`OwnWindowTilingSeamTests`' map is the one copy of who may;
the engine-side obligation this creates — own windows
discriminate per window, and a new one is chrome by default —
is in [input-and-animation.md](input-and-animation.md), which
owns the `Events/` lane that enforces it), floatable if they
say so, and hand-draggable either way. What
it sheds as it narrows, and in what order, is
ruled: **preview (1200) → row layout (900) → chrome (820), and
controls never.** 720 pt is the hard minimum, below which the
window stops resizing. The argument is in
`docs/design-decisions.md` ▸ narrow windows; the obligations
that fall on a change here:

- **`SettingsWidthClass` is the one derivation.** The shell
  measures once and publishes the band through
  `\.settingsWidth`; a site that compares a width of its own
  is the drift the type exists to end, and a second literal
  720 anywhere is how the window comes to resize below its
  own narrowest band. Properties that share a threshold are
  DERIVED from each other (`docksSavePill` *is*
  `stacksRows`), never re-tested against the number.
  `SettingsResponsiveOrderTests` walks every supported width
  and holds the order as implications between them.
- **A capability may lose its layout, never its reachability.**
  An area offering a preview lands on exactly one of docked ·
  floating · offer (`SettingsPreviewForm`, total by
  construction; `SettingsResponsiveOrderTests`'
  `previewIsAlwaysReachable` walks every band against every
  answer) — a fourth state, no card and
  no offer, is one deleted `else` away and is exactly what
  "controls never" forbids. The detached card's close is
  per-mount `@State` cleared on navigation, never a stored
  preference: the panel is dropped by WIDTH, and an answer
  that outlives the window growing back is the collapse
  handle `DetailPanelTests` bans, wearing a different name.
- **A card the user can move is clamped by arithmetic**, not
  by a gesture bound — dragged past an edge at the minimum
  there is nothing to bring it back
  (`SettingsFloatingPanelTests`).
- **A gesture that moves a live preview owns no build of it.**
  The `@GestureState` goes in a view that takes the preview as
  an already-built child (`MovableCard`), never in one whose
  body constructs it: a gesture update invalidates its
  declaring view every frame, and `SettingsDetailPanel`'s body
  diffs the whole draft and redraws a schematic. The symptom
  is stutter under the pointer, which no suite can see — the
  residue that survived even this shape is #813. The same
  obligation binds any future surface that animates a preview.
- **Two controls in one strip are two accessibility elements.**
  A label on the row that CONTAINS a button either renames it,
  swallows it or is dropped, and all three are invisible to
  every locale guard — both keys are present, both render
  somewhere. The card's grip and its × are named apart, held
  by `SettingsFloatingPanelTests` on the modifier's shape.
- **The row axis has one application site.**
  `SettingsRowShape` is where a label meets its control; a row
  framing `settingsLabelColumn` itself keeps the wide
  arrangement at every width, which is invisible in review and
  in every other guard (`SettingsRowShapeTests`' `allowed` map
  is the one copy of who may). It swaps `AnyLayout`, never an
  `if`: both arrangements draw the same two children, so the
  identity survives and a menu stays open, a field keeps focus
  and the reflow animates instead of flickering under a drag.
  What the scan watches is a label FRAMED to a settings column,
  every spelling of it — a row laying its label out some third
  way (a `Grid`, a `Spacer`) is review's to catch, and a new
  column constant joins the needle list with its own site. One
  such spelling was already loose when the list was first
  written.
- **A component that changes KIND stays one view.** The save
  pill docks into a full-width bar below 900 through a
  parameter on `SettingsFooter`, not a second footer type —
  two views describing one draft is two places for them to
  disagree — and the shell, not the footer, decides which
  container it mounts in. Both mounts are needled in
  `HomeSurfacingTests`, because either one alone leaves a
  width band with no save affordance at all. Stated residue,
  since it is the one place this pass accepts what it forbids
  for rows: the two containers are different structural
  positions, so crossing 900 rebuilds the footer and drops its
  view state — an open unsaved popover closes, and a
  half-typed profile name in its naming alert is lost. Both
  need a resize mid-edit to reach, and the alternative is a
  footer mounted in neither place properly.

## The keyboard path (#678 turn 20a)

"Accessible with VoiceOver" and "usable without a mouse" are two
claims, and this tree has historically shipped the first while
believing it shipped both. The argument is in
`docs/design-decisions.md` ▸ usable without a mouse is a second
claim; the obligations a change here takes on:

- **A `.contextMenu` is right-click and nothing else**, macOS
  having no default key that opens a focused control's
  contextual menu. So a row offering one routes it through the
  ONE composition seam — `rowActions(id:_:)`
  (`ContextShortcut.swift`) — which takes the builder ONCE and
  applies right-click, VoiceOver's named actions and the
  focus-gated keyboard chord itself; a bare channel spelled
  beside the seam is how a crossed pairing or a stale mirror
  ships, and `KeyboardActionParityTests` bans it outside the
  seam file while pinning the seam's own composition (the one
  builder, the chord, the focus gate). The chord, the hidden
  anchor mechanism and the focus-gating argument are
  `ContextShortcut.swift`'s doc's to own — the user-facing copy
  is `docs/user-guide.md` ▸ Using Settings from the Keyboard,
  and the ruling behind the shape (a key on the focused row,
  after a visible `⋯` was rejected twice and a whole-chip
  `Menu` ate the drag) is `docs/design-decisions.md` ▸ the row
  menu's keyboard route. Two obligations ride along: a row
  joining the family must be able to HOLD focus (the
  assignment chip needed `.focusable()` — an `HStack` has no
  Tab stop of its own), and the chord's landing is a device
  fact — eye-confirm with keyboard navigation ON; the guard
  proves wiring, never behavior.
- **A control whose label is a sibling `Text` has no name.**
  VoiceOver derives a name from the label a control OWNS;
  a `Text` beside it in an `HStack` names nothing, and the
  control announces a bare value — a percentage, for the window
  count sliders. Name the control and hide the decorative twin,
  rather than leaving one value spoken as three elements.
  **And a control that is NAMED is VALUED in the same change
  (#812):** `.accessibilityLabel` replaces what SwiftUI derived,
  which for a `Picker` or `Menu` is the selection, so the label
  that names it is the modifier that silences its choice —
  `AnnouncedValueTests` scans every labelled `Picker`/`Menu`
  chain for the value beside it, against an exact census of who
  is labelled. A `.menu` picker under `labelsHidden` keeps no
  AX title (the dated observation is the design decision cited
  below), so `DropdownRow` takes the selected option's title
  from its site, its `spokenValue: nil` escape enumerated by
  the same suite; `SettingsSlider` takes
  `label` and `spokenValue` as required arguments and re-earns
  the Tab stop and arrow keys a custom-drawn view has no claim
  to; `SettingsRowLabel`'s text is drawn, not spoken, since every
  control in the shape names itself. The argument is
  `docs/design-decisions.md` ▸ a name replaces the announcement.
- **A picture speaks as ONE description, read from the
  drawing's own predicates.** A schematic's `axLabel`, the
  keyboard board's `KeyboardBoardSpoken` sentence — one element
  whose label is the picture's meaning, never an element per
  mark and never a caption read beside it a second time; the
  spoken form consumes the same predicates the marks do
  (`KeyboardCensus.state`, `overwrittenReserved`), so it cannot
  disagree with them (`KeyboardBoardSpokenTests`).
- **A title component carries `.isHeader`.** A reader who
  cannot glance moves card to card by the headings rotor, so a
  new section, group, panel or area title joins the ones that
  declare it (`AnnouncedValueTests` counts them per site); nothing
  headless proves the rotor lists it — verify on device.
- **A dim is not a sentence.** A greyed row that announces only
  "dimmed" is a dead end: the dimming says an answer exists and
  withholds it. **Which channel carries the reason is derived,
  not chosen** (#815): `GateReasonPlacement` reads the census —
  a block gate keeps its `?` anchor, a row whose cause is in its
  own container needs nothing, a row gated from another
  destination owes a LIVE pointer naming that destination, and
  only what falls through all three draws the reason INLINE,
  outside the dimmed subtree, the way `GeneralRestartRow`
  already does. What SHAPE the remote
  pointer takes follows from the block: a `?` where there is a
  live label above the dimmed rows to hang one on (Advanced
  Colours), a `CrossReferenceRow` under them where there is not
  (the per-space override editor, #841) — either way it must be
  reachable while the rows it explains are inert, so it is drawn
  outside the `GreyOut`, and hover text alone never discharges
  it. So do NOT caption every greyed
  row — a `GreyOut` inside a `ForEach` stamps its sentence under
  every child, and several of these greys are ordinary states.
  `GateReasonPlacementTests` holds the derivation against the
  sites that draw one and reds when the per-space editor's
  pointer falls back to hover text; `GreyOutAnchorTests` counts
  the `?` anchors, exactly, so losing one is a conscious edit.
  **A hint is not a proven substitute**: an
  `.accessibilityHint` on `GreyOut` was written and backed out
  because that modifier wraps whole blocks, so whether it
  reaches the controls inside — and whether its empty value
  displaces a hint a descendant sets for itself, as
  `ColorField`'s swatches do — could not be observed headlessly.
  `GreyOut`'s docstring carries the two failure modes; re-adding
  it needs an Accessibility Inspector session recorded first.
- **A destination has to be able to HOLD focus, which is not
  what "always drawn" means.** macOS gates keyboard focus for
  everything except text fields and lists behind System
  Settings ▸ Keyboard ▸ Keyboard navigation, which no app may
  set for the user and which was OFF by default as observed on
  macOS 26.6.1, 2026-08-11 — check it again rather than trusting
  this sentence, the default having moved across releases before. So a pop-up
  menu, a checkbox or a button accepts a `@FocusState`
  assignment only on a machine that has turned it on; where it
  has not, the assignment lands nowhere and focus falls to the
  window's first text field — the search field at the top,
  which is the "focus goes to the top" outcome the rule below
  exists to prevent, arriving by a different road. Deleting a
  space shipped exactly that way: the destination was correct,
  always drawn, needled, and reachable by nobody on a default
  Mac (owner eye-confirm, 2026-08-11).
  **Verify a focus destination with keyboard navigation ON, and
  read a green needle as saying only that a destination was
  named.** Nothing headless separates drawn from focusable, and
  `docs/user-guide.md` ▸ Using Settings from the Keyboard is
  where the user is told which setting this all presumes.
- **Every shape change states a focus destination**, and the
  destination must be a control that is always DRAWN. Binding a
  return to a mode-gated affordance sends focus to a value no
  view claims, which lands at the top of the list — the exact
  behaviour the rule exists to prevent, and invisible to a
  source-needle guard, which is why the wirings in
  `KeyboardActionParityTests` are keyed on their use sites.
  The shell states two of these itself (push focuses the back
  chip, return restores `nav.homeReturnFocus`); a sub-view the
  shell cannot see states its own, and a deletion reads its
  neighbour through the one `DeletionFocus.neighbour` rule
  (#816, PR #842) — BEFORE the mutation, or it names whichever
  row slid into the gap. Naming a destination is a different
  claim from focus arriving there, and on a machine without
  keyboard navigation the two outcomes look identical.

## Colour (#678 turn 16b)

Every surface, border and ink in the Settings tree comes from
`SettingsTheme`. The obligations that fall out of it:

- **A new colour goes through the theme.** A hex literal or a
  system colour beside a view is the drift the type exists to
  end. `SettingsThemeTokenTests` holds the only copy of the hex
  table (alphas included — `planeRing` is a construction that
  exists in dark only) and resolves each token under `.aqua` AND
  `.darkAqua`, so a token wired to one branch in both modes
  reds; `SettingsThemeWiringTests` puts every declared token in
  exactly one of two lists — wired at a named render site, or
  deferred with a reason — so a token nothing draws cannot ship
  quietly. Two lenses hold the pass-7 verdicts:
  `SettingsThemeContrastTests` computes WCAG ratios from the
  shipped tokens at the render's own alpha — its pairing list is
  hand-kept, so **a change drawing an ink on a surface it did
  not draw on before adds the pairing there in the same change
  set** (the board's ring pairs stay `ColorVision`-governed in
  `KeyboardRingSeparationTests` — one authority per pairing) —
  and `SettingsRawColorTests` bans
  fixed hues, RGB literals and fixed white/black outside its
  reasoned maps, with `SettingsFixedGroundTests` banning
  hierarchical greys on the FIXED-dark chrome families
  (stem-derived, so a §2.1 split cannot fall out of it) — on
  mode-varying surfaces `.secondary` still self-inverts and
  "prefer a concrete ink" stays a preference.
- **A dark plane on a dark ground takes the `planeRing` seam**
  (16b's one non-swap construction): where a fixed-dark surface
  meets a mode-varying one — the plate, the save pill, the
  search panel, a drag lift whose black shadow dies in dark —
  the inset light line is the edge, drawn OVER any hairline,
  transparent in light by the token itself, never by a
  `colorScheme` branch.
- **`Color.accentColor` is not the accent.** It reads the user's
  *system* accent and is unaffected by `.tint`, so in this
  window it renders the app's own decoration in a hue the app did
  not choose. Retired outright, along with the two `NSColor`
  window surfaces, by the lens in `SettingsThemeWiringTests` —
  which carries no exemption map on purpose.
- **A focus RING is the exception, and stays the platform's**
  (#833). `NSColor.keyboardFocusIndicatorColor` reads the user's
  system accent and ignores `.tint` exactly as
  `Color.accentColor` does, but here that is right: a focus ring
  follows their accent AND their "Increase contrast" and
  focus-ring settings, which is behavior, and the north star
  binds behavior to the platform. So **leave a `TextField`'s
  ring alone** — converting one to `.plain` to paint it kiwi
  removes the platform's indicator, and a control that does that
  owes an indicator of its own plus the contrast the platform's
  had — the search chip is the worked example, which took
  `.plain` for the chip shape and then owed itself an indicator
  (its accent at 0.55 measured 1.52:1 on `sunken` and had to go
  to full strength). The argument is in
  `docs/design-decisions.md` ▸ a focus ring is the platform's.
- **The accent marks control FILLS, never text naming a value.**
  A toggle track, a selected segment, a prominent Save.
  **A control style that colours its label from the tint owes a
  neutralisation a guard can count** — the menus pair it per
  call site, `.menuStyle(.borderlessButton)` →
  `neutralMenuLabel()` (`SettingsLabelNeutralityTests`), and a
  `.bordered` action button takes `settingsActionButton()`,
  which seals the style to `neutralButtonLabel()` by
  construction (#771) after per-call-site pairing shipped the
  same defect in a second style (#759). So treat the style as the unit, not the
  site: the fix is never a local recolour. A raw
  `.buttonStyle(.bordered)` is legal only in
  `SettingsBorderedSealTests`' `borderedExempt` map — the one
  copy of who may, whose entries name the source token that IS
  each reason, so an exemption whose grounds have gone reds —
  and a direct `.neutralButtonLabel()` on any other style stays
  enumerated in `SettingsLabelNeutralityTests`'
  `neutralisedDirectly`. A button with no `.buttonStyle` at all
  renders bordered on macOS and takes the tint identically
  while matching no needle — give an action button an explicit
  style, which is what brings it under the guards
  (`SettingsButtonStyleConventionTests`, whose arithmetic
  counts a seal as naming one).
- **A button carrying an accent FILL takes the second seal.**
  `.borderedProminent` picks its own label colour, and on macOS
  that is white — which `SettingsTheme.accentInk`'s docstring
  rules out on kiwi, and whose legal replacement
  `SettingsThemeContrastTests` measures. So an
  accent-filled primary action takes `kiwiProminentButton()`,
  which pairs the fill with `accentInk` by construction exactly
  as `settingsActionButton()` pairs the bordered rank with its
  neutralisation one rank down; both spellings count as naming a
  style in `SettingsButtonStyleConventionTests`. Read neither
  seal as a finished sweep: a site still on `.borderedProminent`
  is drawing white on the accent, and adopting the seal there is
  its own change and its own eye-confirm.
- **Prefer a concrete ink to `.secondary` wherever an ancestor
  may set a foreground.** `.secondary` and `.tertiary` are
  *hierarchical* — derived from the enclosing foreground, not from
  a fixed grey — so one container-level `.foregroundStyle` turns
  every caption beneath it into a translucent shade of that
  colour. A container-level foreground plus a tinted row is how
  the header and the empty-icon placeholder both shipped
  green-on-green for an afternoon.

## Source-scanning guards have scan ROOTS, and a new tree joins them

Several guards scan directories rather than the whole target, so
a GUI tree outside their roots is not partly covered — it is
silently exempt from a fail-open guard. **A new directory under
`Sources/KiwiDesk` that draws chrome joins `ChromeScanRoots` in
the same change that creates it**, and one that renders a
**schematic** joins `LayoutSchematicPlacementScanTests`' roots
as well. Each guard carries a root-coverage check, so a moved or
renamed directory reds rather than going quiet.

`ChromeScanRoots` is the ONE list of which trees draw the app's
own chrome, and a guard that scans chrome reads it rather than
hand-listing the trees again — the membership test, and why the
list is shared at all, are its own doc comment's. A guard
scanning a different question (the placement scan watches the
trees that draw schematics, which is not the same set) declares
its own roots and says in the suite what makes them narrower.

The Onboarding tree is the worked case: it shipped a raw
`.green`/`.orange` status hero in the first window every user
sees, for as long as it existed, because the lens
stopped at `Settings/`.

## SwiftUI traps

- **Cursor changes use `NSCursor.set()`, never push/pop.** A view
  removed under the pointer (a link that deletes itself, a row
  rebuilt by rename) never delivers the balancing
  `onHover(false)`, and hover interleaved with a drag gesture pops
  the wrong entry — a cursor stack cannot balance. Bit the spaces
  drag handle and the link-hover modifier.
- **Keep `body` a shallow container.** A long modifier chain with
  conditional `background` / `overlay` closures, or
  `+`-concatenated string literals inside one `body` expression,
  can exceed the type-checker's budget — and the failure is
  machine-dependent: it compiles locally but dies on the slower CI
  runner ("unable to type-check this expression in reasonable
  time"), so the local verify gate does not catch it. Extract
  chained subviews into private computed properties / funcs and
  hoist concatenated strings into constants. Bit
  `KeyRecorderField`.
- A view `.disabled()` on a `.menu` `Picker` is **unreliable** —
  it blocks selection but won't grey. Never make it the sole gate
  on a side effect; guard the setter too, and grey the picker
  rather than the row so a `?` affordance stays live.
- **An `NSMenu` that greys a row for a reason of its own turns
  auto-enabling off, and then every row states `isEnabled`.**
  AppKit re-enables at display time any item whose target
  responds to its action (observed on macOS 26.6.1,
  2026-08-12), so a row that WORKS cannot be dimmed while
  `autoenablesItems` is on — which is what the quick menu
  needs during boot (#802) and what the Layout submenu's save row
  needed before it (#68). The cost is the other half of the
  switch: a nil-action row is no longer disabled for free, so an
  unstated `isEnabled` ships an enabled-looking context line —
  and a **submenu parent** is one of those rows, its nil action
  being what opens the child.
  **The flag is per `NSMenu` and does not inherit**, so a builder
  that nests menus turns it off on every one it constructs, not
  only the outermost: a nested menu left on auto-enabling
  re-enables at display time exactly the rows the switch was
  thrown to keep dim. `QuickMenuBootRowTests` and
  `QuickMenuProfileRowTests` hold the two menus' rows;
  `LayoutMenuEnablementScanTests` pairs each constructed row to
  its own `isEnabled` statement (never a per-file total, which a
  `guard-prover` round forged) and derives the flag count from
  the `NSMenu()` count, so a nested menu that skipped it reds.
- **Modifiers on a bare `ForEach` apply PER CHILD, never to the
  run.** A container that hands a `ForEach` straight to its
  chrome (a background well, padding, a border) stamps that
  chrome onto every child — the Motion drawer shipped every
  toggle, a caption and a lone divider each in its own sunken
  well. Wrap the content in a `VStack` (or another single view)
  before applying the chrome; `SettingsDisclosure`'s interior
  states the mechanism at the seam.

## Strings

Nearly every `L()` call site in the repo is in this tree, so the
authoring rules apply here even though the catalogs live in Core:

- Every user-facing string goes through `L("key", "English")`
  (issue #9). English is the source of truth, inlined at the call
  site.
- **One carve-out, and it is CLOSED: the four modifier
  abbreviations the tour draws.** `OnboardingModifierNames` draws
  `ctrl` / `opt` / `shift` / `cmd` under `⌃ ⌥ ⇧ ⌘` with no catalog
  keys at all. Treat that list as exhaustive — **a new verbatim
  user-facing string is a ruling, not a judgement an author makes
  at the call site**, and there is no test to apply: the obvious
  one is false. (An earlier draft of this bullet offered
  "is the token the same in every catalog, checkable against
  `key_recorder.help_press`" — and that key, which carries each
  locale's FULL modifier names, is translated in `es`, `it` and
  `pt-BR` ("Opción", "Controllo", "Comando"). The check returns
  *this is narration, it takes a key*, which is the opposite of
  what it was written to establish.)
  So the honest scope, stated rather than derived: the four are
  drawn verbatim because an abbreviation of a modifier reads
  alike across the languages KiwiDesk ships, and in the three
  catalogs that DO localize the full name the app therefore names
  one key two ways — the tour's `opt` against the editor's
  "Opción". That split is known and accepted, not overlooked.
  The argument is `docs/design-decisions.md` ▸ the tour teaches
  the tier; the translator-facing half is `docs/translating.md`.
- A value interpolated into a sentence (a name, a count) MUST use
  the `L(key, english, args...)` overload with **positional**
  `%1$@` / `%1$d` specifiers — never `+`-concatenated fragments.
  A translation cannot reorder pieces stitched together in Swift,
  and many languages need to.
- **That holds when the pieces are sibling VIEWS, not just
  string fragments.** `HStack { Text(prose); <the value> }` is
  the same defect with a layout container doing the stitching:
  the value can only ever land at one end, so every key must be
  authored dangling, and a translation still cannot move it.
  Nothing catches this — `extract-keys` sees one well-formed
  key, the specifier-drift and content guards see nothing wrong
  with it, and it reads as ordinary SwiftUI. It shipped for four
  cross-reference captions until `CrossReferenceRow` was made to
  render its link AT a positional specifier, by which point
  `ja`, `ko`, `zh-Hans`, `zh-Hant` and `ru` had each ended their
  translation on a colon or a bare preposition, having no way to
  write a sentence. So: a value that belongs INSIDE a sentence
  is interpolated into it, whatever kind of thing renders it.
  `CrossReferenceRowSlotTests` holds the cross-reference family;
  a second family of stitched sentence owes its own guard, since
  that one is scoped to `CrossReferenceRow(` call sites.
- Replacing a SwiftUI control with an AppKit one **re-earns what
  the control gave away free** — focus, keyboard activation,
  VoiceOver, and `isEnabled`, which `.disabled()` sets in the
  environment and which no `NSView` inside an
  `NSViewRepresentable` reads on its own. `LinkedCaption` and
  `LinkedCaptionHitTests` are the worked example, and the first
  cut of it shipped none of the four.
- A frame interpolating a **count** is authored so nothing has
  to agree with it — put the number last behind a label ("Keys
  taken: %1$d"), in the English too. The argument, and what the
  app's two-form picking can and cannot express, is
  [localization.md](localization.md) ▸ a frame interpolating a
  COUNT; it is repeated here because that file never loads while
  you are authoring a call site in this tree.
- **A sentence that names another control INTERPOLATES that
  control's label key; it never spells the label out** (#818,
  `InterpolatedLabelTests`). Repeated here for the same reason
  as the bullet above — the obligation binds the English author,
  and every call site in this class is in this tree. Quoting is
  a hand-kept mirror across ten catalogs with nothing checking
  it, and it had already drifted in five of them: `es` named the
  boxed style "En casillas" against a picker reading "En caja",
  `it` a colour row "Elemento sotto il puntatore" against a row
  reading "Elemento al passaggio mouse". Interpolated, the
  anchor is held by `placeholder_drift` in every locale. Two
  authoring rules fall out. **Spend each specifier once** — the
  drift guard compares a multiset, so a repeated `%1$@` makes a
  stylistic second mention mandatory in every language and fails
  a translation that pronominalises it; carry the second mention
  with a common noun instead. And **do not name a place
  deictically** ("below", "above") unless the thing is on this
  page: `app_bar.icon_source.help` said its colour rows were
  below while they render on Advanced Colours, all three
  Power-User-only.
- **Never hand-edit `Resources/Locales/*.json`.** `en.json` is
  regenerated from real call sites; the other catalogs are
  translation-owned and edited only through `scripts/*-key(s)`.
- A cosmetic English edit (typo, punctuation) keeps translations;
  a **meaning** change runs `scripts/drop-key <key>` in the same
  change set.

The tooling, the content guards and the "Core names, the
GUI narrates" seam (#96) are in
[localization.md](localization.md).
