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
Layout Defaults and App Rules render from it now** (#678 Phases
2-3):
`BarsRowOrder` / `ColorsRowOrder` / `ShortcutsRowOrder` /
`LayoutDefaultsRowOrder`
hold the display order and `BarsCensusRenderTests` /
`ColorsCensusRenderTests` / `ShortcutsCensusRenderTests` /
`LayoutDefaultsCensusRenderTests` pin
them to the census, so a row in
those areas moves by editing the census.

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

**The census's unit is a SETTING, and one setting may draw many
rows.** A keybinding family is the worked case: `focusDir` is
one census case that puts four rows on screen and `goToSpace`
one that puts a row per live space, so the Shortcuts area needs
a second seam the other areas do not — an order list saying
*where a family sits* and `ShortcutsFamilyRows` saying *what it
draws*. An area whose keys expand this way owes both halves and
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
  (`BarsGateContext`, `ShortcutsRuntimeGate`), never
  re-implemented inline beside it — a renderer whose predicate
  drifts from the declaration greys the wrong row, or hides one
  entirely, and the tier case is invisible by construction
  (`ShortcutsRuntimeGateTests`, written after three such
  violations passed the whole suite);
- a predicate the resolver **cannot** answer from the declared
  owner — resolved shown-bar values, auto sentinels, live editor
  state — is a wiring predicate and was never a census gate;
- **which declared gates the resolver cannot answer is data**
  (`ShortcutsRuntimeGate.resolved` / `.resolvedElsewhere`), so
  the gap stays deliberate and a new gate landing in neither
  set reds.

The resolvers still take different shapes — one keys on
`SettingsContainer.gate` over `TilingSettings`, another on
`SettingRuntimeGate` over `GuiConfig`, a third
(`LayoutDefaultsGates`) on a row's own `SettingKey` over
`TilingSettings`. **Converge them before a fourth shape
appears**; the split is why one legitimate gate is "resolved
elsewhere" today. Layout Defaults did not force the
convergence and does not discharge it: it answers only ROW
gates, so it had nothing to converge *with* — **give this area
a container gate or a `.runtime` one and converge the
resolvers rather than teaching this one a second shape.**
`LayoutDefaultsGateTests`' `everyGatedRowIsResolved` holds both
halves: it reds when a ROW gate this resolver does not answer
appears, and it pins that no container in the area declares a
gate at all — because the resolver has no `allowsEditing` arm,
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
`allowed` map is the one copy of who may. Scope such a guard to
the row's FILES rather than to the sentence property:
guard-prover walked through a body-scoped cut twice, the second
time with a spacing helper declared outside the property and
composed into it. What no source scan can reach is per-segment
spacing that is not a stack argument — a `.padding`, a
`Spacer`, a `.frame` — so that residue is stated in the suite
rather than chased.

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
