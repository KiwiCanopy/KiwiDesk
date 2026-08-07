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
- **The live preview leads** its editor.
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
  Check *which* engine owns the rule before calling one: track
  spawn is `Space.insertIntoTrack`'s, not
  `Space.insert(_:placement:)`'s, and the two agree on position
  only because `LayoutSchematicTrackEngineTests` now requires it.
  Where a preview models part of an engine's rule, say which part
  and file the rest (#708 for the unmodelled spill).
- **Defer per-control "why" to contextual help** (the planned `?`
  affordance, #94) rather than bloating labels or captions with
  glosses that would later duplicate it. A caption's job is to
  label what's shown, not to teach.

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
label key as an `.accessibilityLabel`.** The App Rules sentence
is the worked case: its two menus sit inside a statement with no
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
  hue alone.
- **A new surfacing branch or one-line wiring decision in the
  shell joins `HomeSurfacingTests` in the same change**, keyed
  on its use site — the Monitors lesson, which this shell
  inherits whole.
- The mode pick persists via `SettingsModePreference`
  (`UserDefaults`, absent = Simple, never `gui.json`); the
  header's unsaved count comes from `SettingsDraftDiff`, whose
  every-leaf attribution net (`SettingsDraftDiffTests`) is
  what a new `GuiConfig` or `TilingSettings` field reds until
  its census row exists.

## Colour (#678 turn 16b)

Every surface, border and ink in the Settings tree comes from
`SettingsTheme`. The obligations that fall out of it:

- **A new colour goes through the theme.** A hex literal or a
  system colour beside a view is the drift the type exists to
  end. `SettingsThemeTokenTests` holds the only copy of the hex
  table and resolves each token under `.aqua` AND `.darkAqua`, so
  a token wired to one branch in both modes reds;
  `SettingsThemeWiringTests` puts every declared token in exactly
  one of two lists — wired at a named render site, or deferred
  with a reason — so a token nothing draws cannot ship quietly.
- **`Color.accentColor` is not the accent.** It reads the user's
  *system* accent and is unaffected by `.tint`, so in this
  window it renders the app's own decoration in a hue the app did
  not choose. Retired outright, along with the two `NSColor`
  window surfaces, by the lens in `SettingsThemeWiringTests` —
  which carries no exemption map on purpose.
- **The accent marks control FILLS, never text naming a value.**
  A toggle track, a selected segment, a prominent Save.
  **A control style that colours its label from the tint owes a
  neutralising modifier at every call site and a pairing guard
  in `SettingsLabelNeutralityTests`** —
  `.menuStyle(.borderlessButton)` → `neutralMenuLabel()` and
  `.buttonStyle(.bordered)` → `neutralButtonLabel()`, the second
  added only after the first had shipped and the same defect
  recurred in the other style. So treat the style as the unit,
  not the site: the fix is never a local recolour. That suite's
  `borderedExempt` map is the one copy of who may skip it, and
  an entry there names the source token that IS its reason, so
  an exemption whose grounds have gone reds. A button with no
  `.buttonStyle` at all renders bordered on macOS and takes the
  tint identically while matching no needle — give an action
  button an explicit style, which is what brings it under the
  guard.
- **Prefer a concrete ink to `.secondary` wherever an ancestor
  may set a foreground.** `.secondary` and `.tertiary` are
  *hierarchical* — derived from the enclosing foreground, not from
  a fixed grey — so one container-level `.foregroundStyle` turns
  every caption beneath it into a translucent shade of that
  colour. A container-level foreground plus a tinted row is how
  the header and the empty-icon placeholder both shipped
  green-on-green for an afternoon.

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

## Strings

Nearly every `L()` call site in the repo is in this tree, so the
authoring rules apply here even though the catalogs live in Core:

- Every user-facing string goes through `L("key", "English")`
  (issue #9). English is the source of truth, inlined at the call
  site.
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
- **Never hand-edit `Resources/Locales/*.json`.** `en.json` is
  regenerated from real call sites; the other catalogs are
  translation-owned and edited only through `scripts/*-key(s)`.
- A cosmetic English edit (typo, punctuation) keeps translations;
  a **meaning** change runs `scripts/drop-key <key>` in the same
  change set.

The tooling, the content guards and the "Core names, the
GUI narrates" seam (#96) are in
[localization.md](localization.md).
