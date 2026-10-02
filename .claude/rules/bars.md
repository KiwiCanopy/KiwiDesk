---
paths:
  - "Sources/KiwiDeskCore/Bar/**"
  # The title-refresh gate's driver lives in App/, and it is the
  # exact site where the drawn/announced split has twice been
  # reasoned about wrongly — this file must load there too.
  - "Sources/KiwiDeskCore/App/KiwiCore+BarTitles.swift"
  # Both bars are built per display, and each reads the focus
  # for itself — #1214 shipped that reading wrong twice, in the
  # drivers and in the item builders they call.
  - "Sources/KiwiDeskCore/App/KiwiCore+SpaceBar.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarRun.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+AppBar.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+AppBarGroups.swift"
  # The one shelf (#1517): where a bar field lives, the one
  # reservation, the one placement rule, the retired verbs.
  - "Sources/KiwiDeskCore/App/KiwiCore+Shelf*.swift"
  # The looks (#1684): which bar fields a look may set.
  - "Sources/KiwiDeskCore/Appearance/*Look*.swift"
  # The Settings preview asks ShelfArrangement and the hard floor
  # like the live plan does; a hand placement there is this
  # file's defect, not gui.md's.
  - "Sources/KiwiDesk/Settings/HomeCardPlate+ShelfStrip.swift"
  - "Sources/KiwiDeskCore/Layouts/KiwiShelf*.swift"
  - "Sources/KiwiDeskCore/Layouts/Shelf*.swift"
  - "Sources/KiwiDeskCore/Layouts/SpaceBarStyle*.swift"
  - "Sources/KiwiDeskCore/Layouts/AppBarStyle*.swift"
  - "Sources/KiwiDeskCore/Layouts/LayoutAppBar*.swift"
  - "Sources/KiwiDeskCore/Commands/Reference/APIReference+Retired.swift"
  # Glass hosts outside Bar/ (#1620, #1621): they take their tint
  # through GlassTint.apply and their stand-down through the gate,
  # whose obligations live here.
  - "Sources/KiwiDeskCore/Tiling/DragOverlay.swift"
  - "Sources/KiwiDeskCore/Tiling/DragMarkerView.swift"
  - "Sources/KiwiDeskCore/Borders/StickyMarkPlate+Glass.swift"
  # ...and the two sites that decide their glass through the gate.
  - "Sources/KiwiDeskCore/Tiling/KiwiCore+DragMove.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+StickyMarks.swift"
---

# Bars (App Bar & Space Bar overlays)

Canonical for this subsystem (AGENTS.md §5 indexes it).

## The bars sit on KiwiShelf, one shelf per edge (#1517, #1731)

The look both bars share is KiwiShelf's
(`TilingSettings.kiwishelf`); the EDGE is each bar's own
(`space_bar.edge`, `app_bar.edge`). On one edge the two are one
fused shelf; on two edges each bar is its own shelf, and two bars
are never stacked on one edge (`ShelfSplitGeometryTests` ▸
`edgesPerMode`). A field both bars read, stored
twice, was a question the user answered twice. The argument is
`docs/design-decisions.md` ▸ One shelf holds both bars, and its
#1731 amendment. Obligations:

- **Store a bar field in exactly one of `KiwiShelf`,
  `SpaceBarStyle` and `AppBarStyle`.** A value both bars must
  agree on — the strip's depth and look, the alignment, the item
  gap, the font size — is the shelf's, and the edge is each
  bar's own (#1731); a value each bar may
  set for itself is that bar's style, even where both bars spell
  it alike (an indicator, a colour). A shelf field takes **no
  per-layout override**: `LayoutAppBar` mirrors `AppBarStyle`
  and nothing else. `KiwiShelfParityTests` ▸ `looksAreDisjoint`
  reds a name on the shelf and on either style, and
  `AppBarParityTests` ▸ `propertyParity` a `LayoutAppBar` field
  that is not `AppBarStyle`'s; whether a NEW field is shared or
  a bar's own is review's, since no guard can tell. **And a new
  field is ruled for the looks (#1684)**: styling — how the same
  items look or where they sit — joins `LookKeys.all`,
  functionality or a field left alone joins `LookKeys.leftOut`
  with its reason, a colour joins `ColorPaletteKeys`, which a
  look carries whole (#1752); the owner's test
  and the argument are `docs/design-decisions.md` ▸ A look is
  KiwiShelf's styling. `LookKeysCensusTests` reds an unruled
  field of `KiwiShelf`, `SpaceBarStyle`, `AppBarStyle`,
  `BorderStyle` or the `gap` group (#1739); which home is right
  is review's. **A write `ShelfLook.apply` makes beyond a look's
  keys joins what `KiwiCore.unpainted` returns** (#1720), or the
  tour's Revert leaves it behind: `ShelfPaintRoundTripTests` ▸
  `revertRoundTripsEveryLook` reds one that reaches a glass leaf
  or a per-layout App Bar override; a write elsewhere owes that
  fixture the field.
- **Retire a bar verb by adding it to `APIReference.retired`**,
  naming its replacement or nil, and never by an alias (AGENTS.md
  §5). A field the shelf migration moves joins
  `ConfigMigration.shelfMovedKeys`, which the retired list
  derives its setter spellings from, so a verb and its stored key
  retire together. `KiwiShelfRetiredVerbTests` holds the list:
  ▸ `replacementsAreLive` that every replacement is dispatchable,
  ▸ `retiredAreUnregistered` that no retired name is still
  registered, ▸ `retiredCallIsAnIssue` that `init.lua` reports
  one as its own Config Issue.
- **Reserve each edge a bar draws on through the one
  `TilingSettings.layoutBounds(from:mode:)`, listed by the one
  `shelfEdges(in:)`** — itself the one `barEdges(space:app:)`,
  which the live plan (`KiwiCore.shelfPlans`) takes too, so the
  strips drawn and the edges reserved are one list — the Space
  Bar's edge in every layout
  while it is on, the App Bar's only in the layouts whose own
  App Bar is on and only where the Space Bar does not already
  hold it — never a layout, a bar or a mode carving a strip of
  its own, and never a second "does a bar draw here" predicate
  beside it. A switch between two layouts that draw on the same
  edges moves no window; a switch into or out of a layout whose
  App Bar draws on an edge nothing else holds is the ruled price
  (`docs/design-decisions.md` ▸ One shelf holds both bars).
  `ShelfGeometryTests` ▸ `reservesWhereABarDraws` holds the fused
  per-mode answer and `ShelfSplitGeometryTests` ▸ `edgesPerMode`
  the split one, `ShelfDriverTests` ▸
  `layoutSwitchReflowsNothing` the no-reflow half, and
  `LayoutBoundsRoutingTests` the route (#537). The answer is per
  MODE, so a per-space `appBar` would draw a bar where nothing is
  reserved — [state-and-layout.md](state-and-layout.md) owns that
  half, since the override types are its files.
- **Measure the strips of several edges through the one
  `ShelfGeometry.strips`, the Space Bar's edge first** — at a
  corner the earlier strip runs the whole edge and the later one
  stops at its reservation, so the Space Bar, which draws in
  every layout, never moves for an App Bar
  (`ShelfSplitGeometryTests` ▸ `cornerYields`, and ▸
  `splitIsTwoPlans` through the live plan).
- **An edge is a bar's own and never a layout's.** The App Bar's
  is global only — `AppBarStyle.layoutFixedKeys` names it, a
  layout's override refuses it, and `AppBarParityTests` mirrors
  every other field, while `APIReference.retired` derives the
  layouts' refusal from the same register — since an edge per
  layout carries the bar across the screen on a layout switch
  (`BarEdgeCommandTests` ▸ `noLayoutEdge`, through `execute`).
- **Place every bar along the edge through the one
  `ShelfArrangement`** — the live drivers through
  `KiwiCore.shelfPlans`, and the Settings preview and the
  alignment note by asking it too
  (`ShelfArrangement.spaceBarMoves`), never by arithmetic of
  their own: a picture that places the bars by hand can claim a
  placement the engine does not make (gui.md, #702). The same
  holds for the corner of a split pair: the preview gives it to
  the first of `barEdges(space:app:)`, as `ShelfGeometry.strips`
  does (`BarsPreviewCornerTests`). The Space
  Bar's front-app segment stands down on the same App Bar content
  the plan is built from. `ShelfArrangementTests` holds the rule,
  `ShelfDriverTests` ▸ `bothBarsShareTheStrip` the disjoint
  segments and ▸ `frontAppYieldsToTheAppBar` the stand-down; no
  suite scans the Settings tree for a hand placement, so the GUI
  callers are review's.
- **Refresh both bars through the one `KiwiCore.updateBars()`,
  never a single-bar sync.** It builds each display's plan once
  from both bars' content and syncs both managers from it, so a
  change to either bar's need moves the other in the same pass;
  a path refreshing one bar leaves the other in a segment the
  plan no longer gives it. `BarsRefreshSeamTests` holds both
  managers' `sync(` to `KiwiCore+Shelf.swift`, and
  `ShelfDriverTests` drives the pair through it.
- **A show whose input repeats draws nothing, so everything a
  draw reads belongs IN the compared input — the shown value or
  the one `BarDrawEnvironment` — and a path that LEAVES views
  where a draw of the same input would not put them invalidates
  its overlay (#1901).**
  A Space switch refreshes the bars from its retile, its focus
  report and its activation, and on the device each repeat cost a
  full render (~46 ms) until the two bar overlays and the shelf
  compared what they were handed with what they last drew. A
  draw-time read outside the input — Reduce transparency, the
  installed fonts, the system accent, the UI language, the
  primary screen's height the panel is flipped against — leaves
  the old drawing standing. The App Bar drop is the one path of
  the second kind: its hand-set frames survive a refresh that
  repeats its input, so it invalidates and redraws itself when
  no refresh drew. A manual scroll, a glide or a fade moves
  views too and owes nothing — a redraw of the same input puts
  them where they already are. Finding a NEW draw-time read is review's: the
  suites hold the ones the environment carries and the drop
  (`BarRenderSkipTests`). Keep the input comparable, which is why
  the bars' app icons come from the one `BarIconCache`: a fresh
  `NSImage` per read never compares equal and costs a
  LaunchServices round trip besides.
- **Stand a bar down through the one
  `KiwiCore.shelfStandsDown(on:)`**, read once per display in
  `updateBars()` for both bars — a native-fullscreen Space
  (#670) or a window filling that screen in FRONT (#1787) —
  never a user-space read beside it, which hides on the first
  and draws over a slide show. The cold-start App Bar
  (`appBarFallback`) is the one exception: it runs before any
  display is published, with no display to ask about.
  `ShelfStandDownSeamTests` holds the bar-building files to that,
  its `allowed` map the one copy of who is exempt;
  `FullscreenStandDownTests` ▸
  `presentationInFrontStandsShelfDown` holds both bars through
  it.
- **Keep a bar's `naturalLength` equal to what its render
  draws** — the need the plan hands `ShelfArrangement` restates
  the render's padding, so a change to either side moves both:
  handed a segment exactly that long, the run fits with no fade
  and its plate reaches the segment's GUTTER-side end, the Space
  run's outer `pad` the one slack allowed where `item_gap` is
  below it. `ShelfNeedParityTests` holds both bars to it, both
  placements, a gap each side of the pad.
- **Add at every item-length site the end inset its layout adds,
  through the one home** (#1763): a rounded end's clearance is
  `KiwiShelf.endClearance`, handed the item's own cross offset,
  and which ends draw rounded is the one
  `KiwiShelf.roundsItemEnds`, fed the run place the render flags
  its views with (`runPlace`), never a second reading — so a
  Space item's `autoLength`, the front-app chip's extent and its
  title's cap, the App Bar's slot and the Settings preview's need
  each add what their layout draws. `RoundedItemEndPadTests` ▸
  `boxedItemMeasuresWhatItDraws` and `RoundedItemEndPadTests` ▸
  `plateItemsPadOnlyTheRunEnds` hold the Space item,
  `RoundedItemEndPadChipTests` the chip and the App Bar, and
  `ShelfStripPreviewTests` ▸ `needCarriesPipClearance` the
  preview; a new item type owes one of them a clause. The
  vertical App Bar takes no inset, by the owner's ruling on #1763.
- **Collapse a Space item once, in
  `SpaceBarOverlay.Item.collapsed(to:)`, applied by the item
  builder after the `hide_empty` verdict** (#1683) — never in a
  render or a preview, since the plan measures the builder's
  items and a collapse decided anywhere else draws a run the plan
  did not reserve. A collapsed item's count is a disc on the
  identifier's cell and adds no length, so the length and the
  layout both measure the identifier alone.
  `SpaceBarCollapsedRenderTests` ▸ `discRidesTheIdentifier`
  holds the disc inside the planned length; that no other site
  collapses is review's. The run's glide on a
  switch goes through `BarMotion` like every bar motion, its box
  glass travelling with its item (`SpaceBarGlideWiringTests`).
- **Key the App Bar's item views, their box glass and the members
  still gliding by WINDOW, never by position** (#1831): a group's
  fold or release is then a glide of the same views, and each
  glass stays paired with the window it hosts, so no view moves
  between glasses (#1315). On a boxed glass run only content
  crosses: a folded member leaves its glass at once, and a
  released one travels bare (`glidingIn`) until the latest
  glide's landing re-renders it into its glass — the host change
  that arm names. `AppBarGroupGlideTests` holds the mapping,
  ▸ `glassRunMovesContent` the pairing and ▸
  `landingLeavesNoGlass` that no render mints a second glass. A
  render that folds or releases runs its item frames AND its
  glass hosting on the one plate glide the shelf re-places the
  section on, both passes taking the one groups-or-not choice
  (`AppBarGroupGlideDispatchTests`).
- **Stand what a glide or fade will read from and COMMIT it
  through the one `BarMotion.standCommitted`, before the group
  that reads it** (#1838) — a section's glide start in
  `standGlideStarts`, a shelf's transparent first show.
  The animator starts a frame glide from the layer's last
  COMMITTED presentation, never from a frame written in the same
  pass: a start stood at 569 glided from 0 until the
  `CATransaction.flush()` behind it (device, 2026-09-30), the
  content jumping aside first. Compute where a start is through
  `ShelfOverlay.glideStart`, never beside a call site: content that keeps its
  offset inside
  the section glides from the old frame, size included; content
  re-anchored in its slot starts at the new size placed where it
  was drawn, since the old bounds would clip it; and a slot that
  did not change moves the section not at all — its row
  re-centring inside the whole strip is its own render's, and a
  start that held it slid the section in from the side (device,
  2026-10-01). `ShelfSectionGlideTests` holds the three; that the
  start is flushed is review's, since no headless render reads
  the animator's from-value. The glide's length is the user's
  `animations.shelf_duration`, `BarMotion.shelfGlide` set in
  `updateBars()` (`ShelfGlideSettingsTests`).
- **A section joining a fused shelf grows out of the section it
  joins and a leaving one shrinks back into it; a shelf on an
  edge of its own fades in and out, plate included** (owner
  ruling, #1838). The fade-out keeps the panel until it lands,
  a show meanwhile fades it back, the shelf reports leaving
  exactly once, and `ShelfManager` retires it only then
  (`ShelfFadeTests`). Never hold a strip reserved for a shelf that is fading
  out:
  the windows take it the instant the switch lands and the fading
  shelf draws over their edge.
- **A Space switch DISSOLVES the App Bar's row, both rows fading
  from the first frame, the old over `BarMotion.dissolveOutShare`
  of the glide** (holding the new row back left the boxes empty
  between; owner, device 2026-10-01) — keyed on the Space
  `AppBarManager` hands
  `show`, never a close within a Space, never the first show
  after a hide, which LANDS its run and items rather than sliding
  them in (`AppBarLandingTests`). A section wanted again before its
  leave lands leaves `leavingViews` and stays on the strip
  (`ShelfFadeTests` ▸ `reWantedSectionStays`).
  On a boxed glass run the boxes CUT and only content dissolves:
  a glass takes no alpha — at partial opacity it shows the tint
  behind it bare — and no geometry — its content re-lays every
  frame (both device, 2026-10-01) (`AppBarDissolveTests`). A bar
  manager hides its display's overlay and never drops it — a bar
  coming back is the same section re-shown — retiring only a
  display that left (`BarManagerKeepTests`); its `hide()` tears
  nothing down and a hide of a hidden section writes nothing,
  since the shelf draws a leaving section until its leave lands
  (`ShelfFadeManagerTests` ▸ `hiddenSectionKeepsItsViews`,
  `hiddenSpaceBarSectionKeepsItsViews`,
  `refreshKeepsTheLeavingSection`); and a shelf fade-out already
  running is never restarted by a later refresh (`ShelfFadeTests`
  ▸ `repeatedHideKeepsTheLanding`) — both were how a lone shelf's
  appear took the fused join arm and flew in. A leave stamps its
  views, and a landing removes only the views whose latest leave it
  owns (`ShelfFadeTests` ▸ `leaveInsideALeave`) that still sit on
  its own strip (`ShelfSplitDriverTests` ▸
  `splitKeepsTheMovedSection`). Schedule a landing through the
  overlay's `afterGlide`, never a timer beside it, so a test drains
  it by hand rather than on a clock (`ShelfFadeTests` ▸
  `reWantedSectionStays` reds on a landing scheduled past it).
  Retire a departed display's bar overlays AFTER `syncShelves`, and
  never one `ShelfManager.leavingDisplays` names: the shelf sync is
  where a departing display's shelf is told to leave, and an
  overlay dropped mid-fade re-joins as a new section when the
  display re-enumerates inside the glide (`ShelfFadeManagerTests` ▸
  `managerRetiresOnceLeft` the reading, `ShelfRetireWiringTests`
  the one door and its place after the sync). The Space
  Bar's chip
  glide stands down when its slot changed, the shelf gliding the
  section then (`SpaceBarInactiveContentTests`).
- **A row of floats alone keeps the floating mark ahead of its
  first float and draws no rule** (owner ruling, #1838):
  `AppBarFloatOverlayTests` ▸ `floatsAloneKeepTheMark` holds the
  mark, the rule, the run's lengths and the drawn span.

## One shelf panel per display and edge draws the plate; the bars draw sections

Two panels each painting a plate put two fills and a seam on one
strip, and a plate a bar drew for itself could not know where the
other section ended. So the surface is the shelf's and the bars
render content into it (#1517). Obligations:

- **The panel, the ONE plate and the section divider are
  `ShelfOverlay`'s, one per display and edge — one while the bars
  share an edge, two while they are split (#1731), keyed by
  `ShelfManager.Key` and retired when an edge empties; a bar
  overlay renders its section into its `root` and paints no
  plate.** `ShelfSplitDriverTests` holds the two shelves and the
  re-fuse. A shelf carries the sections its plan placed on it
  (`ShelfStrip.carriesSpace` / `carriesApp`), never a second
  reading of the bars' edges (`ShelfSplitDriverTests` ▸
  `splitDrawsTwoShelves`). An edge move need not glide: the
  panel is keyed by its edge, so a moved shelf arrives. Whether a plate
  draws at all is the one `KiwiShelf.drawsPlate`: Boxed paints a
  box per item — glass per item where Liquid Glass is on — and no
  plate beneath, solid or glass. The glass plate is a backdrop
  BEHIND the section strip and never hosts a view, so the
  no-reparent obligation below holds for it by construction.
  `ShelfOverlayTests` holds the joined plate, ▸ `plateModes` Full
  and Boxed, and ▸ `dividerInTheDrawnGap` the divider; no suite
  scans a bar overlay for a plate of its own, so a section growing
  one is review's.
- **Centre the live shelf's section divider between what the two
  sections DRAW, never on the slot gutter (#1779)**: each bar insets its
  run and its items' content by its own amounts, so the gutter
  middle reads off-centre. A bar reports its drawn span as
  `contentFrame` — the item boxes on a boxed shelf, else the
  content inside each end item — read from the same end-inset
  readings its layout and measurement take
  (`SpaceBarItemView.contentInset`, `AppBarItemView.horizontalPlacement`
  and `verticalIconSquare`),
  never a copy beside them; `ShelfManager` hands it on beside the
  plate. `ShelfDividerCentringTests` ▸ `dividerHalvesTheDrawnGap`
  measures the real bars' glyphs and boxes either side, in both
  orders. The Settings shelf preview keeps `dividerMiddle`: its
  runs are schematics padded alike at both ends, so its gutter IS
  its drawn middle.
- **Wire a section's `onRendered` in `ShelfManager.sync` alone,
  and place each section at the slot it drew into
  (`shownStrip`)**, never at a plan slot read beside it: a
  section re-renders on its own — a page, a wheel, a drag — and
  a slot derived elsewhere leaves the plate trailing what the
  section drew. `ShelfFollowTests` ▸ `relayoutHeld` holds the one
  ordering hazard (no relayout against the old plan while
  `updateBars` syncs); the single wiring site is review's.
- **Re-read every bar view's hover from the resting pointer at
  the tail of `ShelfManager.relayout`** (#1665), through the one
  `BarHoverHit.ownsPointer`, never trust an enter/exit pair alone:
  a render or a placement moves a view out from under a resting
  pointer and AppKit sends no exit, so the hover fill stayed on a
  chip after a click re-laid the bar. The relayout's tail is the
  one point where both sections and the panel are placed, so a
  new hover-bearing bar view joins that sweep, and its event path
  and the re-read share one gate (`SpaceBarStuckHoverTests`,
  `ShelfWiringSeamTests` ▸ `itemsGateHover`); the pointer read is
  a seam `makeTestCore` pins (`MouseButtonSeamGuardTests`).
- **Reduce transparency stands the shelf plate down in
  `ShelfManager.relayout`**, which hands the overlay the gated
  shelf from one `LiquidGlassGate.rendered` call and reads the
  stored one nowhere beside it (`ShelfPlateGlassGateTests` ▸
  `shelfPlateTakesTheGate`). The plate reaches no
  `GlassHosting.resolve(`, so the derived roster in the
  Reduce-transparency obligation below cannot see it — this suite
  holds its gate. **Every Core glass host names the suite that
  gates it** in `OverlayGlassGateTests` ▸ `everyGlassHostIsGated`,
  derived from `GlassPlate.make(` callers — the one copy of who
  hosts glass, so a new host reds until it has a gate. The drag
  markers and the sticky mark host
  glass the same way and take the same rule where each is
  rendered — `handleDragMove` when a marker shows,
  `updateStickyMarks`, which the flip re-runs — handing the gate
  the stored leaf once (`OverlayGlassGateTests` ▸
  `overlaysTakeTheGate`, `OverlayGlassTests` ▸ `gateStandsDown`).
  Their stood-down look is their flat one, not made opaque
  (`docs/design-decisions.md` ▸ Reduce transparency).
- **Every rule a bar draws takes its geometry and ink from
  `BarDivider`** — the in-item rule, the layer and front-app
  breaks and the section divider: the boundary between two bars
  outranks a detail inside one item, sits below idle ink, and no
  rule runs the full depth. The values live there and nowhere
  else; `ShelfDividerWeightTests` holds the ordering, a contrast
  floor on every bundled palette and ▸
  `drawnDividerTakesTheLadder` the drawn divider.
- **An idle Space identifier's ink is `KiwiShelf.idleItemColor`**,
  read by the live bar and the Settings preview alike, never an
  alpha applied to the item colour beside it.
  `IdleItemContrastTests` holds the value and its legibility; the
  routing is review's.
- **An empty Space's identifier, on a Space its screen does not
  show, is `KiwiShelf.emptyItemColor` under either content,
  derived from the palette and never picked** (#1683): the idle floor and the
  occupied-to-empty step
  both hold, or the cue drops rather than the floor.
  `EmptyItemInkTests` measures every bundled palette's answer.

## Overflow fades, follows and pages through one home each

Arrows cost a box at each end of every overflowing section and
read as items; the argument for fades is
`docs/design-decisions.md` ▸ One shelf holds both bars.
Obligations:

- **A section's overflow arithmetic — fade length, offset, hidden
  counts, the page target — is `ShelfOverflow`'s; the fade is
  `ShelfFadeMask`, a mask on the item container so it holds on
  glass; the count is `ShelfCountView`. A section draws no arrow
  and does no overflow arithmetic of its own.**
  `ShelfOverflowTests` and `ShelfOverflowPagingTests` hold the
  arithmetic (a side counts any entry its edge cuts; a page lands
  on an entry boundary and reaches the end), `ShelfCountTests` the
  count and mask, and `ShelfDropTargetTests` that a scrolled Space
  Bar's drop targets stay on their items under a fade, which is
  the drag autoscroll's zone.
- **Whether a render follows its active entry is the one
  `ShelfFollow`, an instance per section.** A manual scroll — a
  page, the wheel or trackpad, a drag autoscroll — holds the
  offset until the active entry changes or the section hides.
  `ShelfFollowRuleTests` holds the rule, `ShelfFollowTests` both
  sections through it, and `ShelfScrollWiringTests` the wheel.
- **Scroll input maps to travel through `ShelfScrollInput`**,
  whose deltas arrive already corrected for natural scrolling
  and are never flipped again (`ShelfScrollInputTests`).
- **A manual scroll moves the section's run view and never
  renders.** A section hosts its run — items, per-item glass,
  tints, the layer rule, an unpinned front segment — in one
  `itemRun` whose frame carries the offset
  (`ShelfOverflow.runFrame`), so its items keep their frames; a
  wheel, trackpad, page or drag-autoscroll step goes through the
  section's one scroll door (`moveRun`), which moves that view
  and re-reads what a render derives from the offset. A render
  per event re-framed every glass and stalled a fast scroll
  under boxed Liquid Glass. Whatever a render derives from the
  offset is re-read there to exactly a render's answer at that
  offset, so a new offset-dependent piece joins the door — a
  piece a render cuts at the viewport included, as the
  scrolling front segment's name is (#1763).
  `ShelfScrollRunTests` holds both bars to a render's answer and
  to no render.
- **An overflowing run keeps the end pads a fitting one has,
  read from its bar's one `endPads`** — the reading
  `naturalLength`, the overflowing viewport and
  `ShelfArrangement.hardFloor` all take (#1830) — and placed by
  the run's own alignment, so crossing into overflow moves no end.
  `ShelfOverflowPadTests` holds both bars across the threshold at
  every alignment; a bar whose need and viewport read two pads is
  what it reds.
- **Every `ShelfArrangement.arrange` caller hands it the Space
  section's floor from `ShelfArrangement.hardFloor`** — the live
  plan and the Settings preview alike. The argument is required,
  so it cannot be forgotten, only passed wrong:
  `ShelfFloorWiringTests` ▸ `planHonoursTheFloor` holds the live
  plan and `ShelfStripPreviewTests` ▸ `spaceKeepsItsFloor` the
  preview.
- **The divider drag writes the Space Bar minimum through
  `execute("kiwishelf.set_minimum")` on release** — the door Lua
  and the CLI take — while a step re-lays the bars alone. The
  length it may reach is `ShelfArrangement.Divider`'s, the
  arrangement's own, the percentage takes the setter's one clamp
  (`KiwiShelfCommandSetting`), and the grip exists only while the
  shelf is full. `ShelfDividerDragTests`
  ▸ `onlyFullDrags` holds the full-only half, ▸ `dragClamps` the
  range, ▸ `managerWiresTheGrip` that
  a drag and a double-click both reach the manager's one report,
  and ▸ `managerWritesTheSetting` that the report reaches the live
  setting; that the release takes `execute` rather than a direct
  write is review's, since both land the same value.

## A bar item's title is SHOWN on two channels: drawn and announced

A `count == 1` item resolves its window title into `item.text`
whatever the edge, and the item view builds its accessibility
label from that text unconditionally — so a vertical bar, which
draws icons alone (#1528), ANNOUNCES the title it does not draw,
and **a title that is announced stale is as wrong as one drawn
stale**. Any consumer reasoning "content draws no text ⇒ the
title is not consumed" re-opens this defect; the class has now
been review-caught three times (Space Bar 2026-08-20, App Bar
#937, and the Settings title-cap grey-out in #937's review
round).

Obligations:

- A gate standing a title consumer down asks "does the title
  reach EITHER channel", never "does it draw text" alone. The
  refresh gates (`AppBarManager.showsTitle(of:)`,
  `SpaceBarManager.showsTitle(of:)`) are the worked cases —
  `BarTitleRefreshTests` pins the arm on a vertical bar, and
  `AppBarAccessibilityTests` /
  `BarTitleRefreshOutputTests` pin the announce channel and the
  rebuilt text there, so a downstream re-derivation of the
  retired gate reds one of those three, not zero.
- The one place the two channels legitimately diverge is a
  collapsed group (`count > 1`): it draws AND announces its app
  name, never a member's title (`KiwiCore.barItemText`,
  `AppBarItemView.updateAccessibilityLabel`), so a member
  rename is not a title consumption on either channel —
  `BarTitleRefreshTests` pins that at two group sizes.
- Per-title-change cost is bounded by the refresh pipeline's own
  debounce (`KiwiCore+BarTitles`), never by consumers
  pre-filtering on what an item draws — the old content gate was
  that pre-filter, and it is what dropped the announced channel.
- **A hover title is read when it shows — through
  `SpaceBarGlyphActions.tooltip` on a Space Bar glyph,
  `AppBarItemActions.tooltip` on an App Bar item — and never
  stored on a view.** It is a third title channel, and it owes
  the refresh gate above no arm only because nothing caches it;
  a view that keeps the string brings back the stale title with
  no gate watching (`SpaceBarGlyphWiringTests` ▸
  `tooltipIsReadAtHover`, `AppBarHoverTitleTests` ▸
  `tooltipIsReadAtHover`). An App Bar item asks only where it
  hides text — Core's cut verdict (`barItemTitle`, the one
  branch the item text also takes) or a label it did not draw
  in full (#1514) — and both bars build the string through the
  one `KiwiCore.hoverTitle(app:titles:)`.

## A Space Bar glyph is a click target the item owns (#1528)

Every app glyph and the `+n` badge carry a `SpaceBarGlyphTarget`;
what a click does is Core's (`KiwiCore+SpaceBarClick.swift`).
Obligations:

- **A clickable piece of an item joins the item's `hitTest`
  target list**, or subview order decides who takes the click —
  a render re-adds the glyph views above kept targets
  (`SpaceBarGlyphTargetTests` ▸ `hitTestPrefersTheTarget`).
- **A menu a bar click opens is built by `SpaceBarWindowMenu`
  and shown through `SpaceBarGlyphActions.present`**, which both
  `makeTestCore` twins pin, since a modal menu hangs a run. Its
  rows' enablement is the focus door's own refusal, greyed and
  never hidden (`SpaceBarGlyphWiringTests` ▸
  `refusedRowIsGreyed`); that no second builder exists is
  review's.
- **Which groups a Space item draws is `SpaceBarStrip.window`,
  and its length reads the same arithmetic** — the builder takes
  the window, `autoLength` counts the drawn glyphs plus one cell
  per disc (`SpaceBarOverlay.Item.discs`), so the length the
  shelf plans is the one the item draws and a focus change never
  moves it (#1528, `SpaceBarStripTests`,
  `SpaceBarCentredStripTests` ▸ `lengthIsFixed`). The centring
  anchor is WHICH app the strip shows, a question of its own:
  the active Space's system focus, falling back to its
  remembered one where the system focus is no drawn group (a
  transient overlay, a switch not yet reported), and another
  Space's remembered one — never the `+n` tint's reading, which
  stays gated on the active Space below.
- **A strip under the pointer is held by `SpaceBarManager`
  alone** and released through its one `onStripReleased`, wired
  to an `updateBars()` DEFERRED on `DeferredTasks.Key
  .stripRecentre` — a hold can end inside a render or the
  relayout's hover re-read, where a synchronous refresh would
  nest `holdingRelayout` and let the outer render redraw the
  stale hold (`ShelfWiringSeamTests` ▸
  `stripReleaseRefreshesTheBars`). The hold ends wherever its
  chip stops drawing that Space, not only on the pointer's exit:
  item views are reused by index, so a slot handed another Space
  reports the old Space's exit from `configure`, and a view the
  run drops, or an overlay that hides, reports it before it
  goes; another Space's entry
  replaces the hold AND releases it, since its exit may arrive
  second; and `sync` drops a hold on a Space no shown bar
  draws. A new way for a chip to stop drawing a Space owes the
  same end, or the strip stays frozen with the pointer gone
  (`SpaceBarStripHoldTests`).
- **A render is compared with the last through one
  `SpaceBarStrip.Drawn` — the window AND the row's group
  count — never through indices alone.** A window opened or
  closed shifts every index, so the same range names other
  apps: the builder keeps a hold only while `Drawn.holds(count:
  span:)` says the row's group count is unchanged and could draw
  it, and
  `Walk.between` walks nothing across a changed row, a collapse
  on either side, or a jump whose windows share no group — which
  would slide glyphs over the neighbouring chips
  (`SpaceBarStripTests` ▸ `changedRowNoWalk`, `jumpNoWalk`,
  `heldWindowShapes`; `SpaceBarCentredStripTests` ▸
  `staleHoldCentres`).
- **A strip walk plays through `BarMotion.playWalk`, as additive
  offsets over the frames and alphas the layout just wrote, and
  its leaving glyphs leave only when it lands.** A chip is laid
  out more than once per render, and every pass rewrites the
  final frames and resting alphas: an animator write to the same
  properties was cancelled by the next pass, and a pass that
  found no walk pending dropped the fading glyphs, so the device
  showed no fade at all (`SpaceBarStripViewTests` ▸
  `laterPassKeepsTheWalk`).

## A bar's right-click menu is one row list (#1518)

A menu drawn one way for the pointer and another for VoiceOver
offers two sets of rows, and a Settings row that opens a page
rather than the row it names makes the user search again. So:

- **Build a bar menu's rows in `KiwiCore.barMenuRows(_:)`, keyed
  by a `BarHit`, and nowhere beside it.** The one
  `BarContextMenus` instance (`ShelfManager`'s) turns them into
  the `NSMenu` and into VoiceOver's named actions both, through
  `BarMenu`, which turns auto-enabling off at every level and
  states each row's enablement — greyed, never hidden (#802)
  (`BarMenuTests`, `BarMenuRowsTests`). Every menu ends with the
  shelf section.
- **A view that answers a right-click overrides `menu(for:)` and
  `accessibilityCustomActions()` with its own `BarHit`, and one
  with nothing of its own answers nil**, so the click reaches the
  section root under it (`BarMenuViewTests`). It finds the menu
  source through `barContextMenus`, the nearest `BarMenuView`
  above it, never a reference handed down: a section root and the
  shelf's surfaces are the one holder each, which their overlay
  sets and their manager hands the overlay
  (`ShelfWiringSeamTests` ▸ `managersHandTheMenus`). A new
  right-clickable view owes `BarMenuViewTests` a clause, and a
  bar element VoiceOver can reach speaks at least the shelf
  section — the front-app chip's plain label and image carry it
  as a list set at render, since they have no override to answer
  per query. And a view that takes a press — to focus, page
  or drag — opens a Control-click's menu before anything else
  (`openControlClickMenu`), since AppKit makes that click a
  context menu only where `mouseDown` is left alone
  (`ShelfWiringSeamTests` ▸ `controlClickComesFirst`,
  `BarMenuViewTests` ▸ `controlClickFindsTheMenu`).
- **`barMenuRows` reads state and adoption snapshots alone** —
  it runs on every menu open AND every VoiceOver query for a
  chip's actions, so a file read there is #1245's cost per focus
  and an AX read of another app is accessibility.md's blocking
  call on the main actor. A row whose enablement needs such a
  read takes it from a snapshot, or refuses at perform time with
  a cue.
- **A Settings row names its place as a `SettingsLanding` value,
  and the GUI maps it** (`SettingsAnchor(landing:)`), landing on
  the card or row as the search does — never a destination or a
  sentence authored in Core (#96, `BarMenuLandingTests`).
- **A row that acts on a window acts through a public verb that
  names it** — a `Commands/Reference` record taking a `.window`
  argument, called through `execute` — never a menu-only path
  into Core (owner ruling 2026-09-29 on #1518). A window row a
  verb cannot yet express earns the argument first, the way
  #1789 did for move and float; its refusal is the verb's own
  `.fail`, cued as structure the GUI narrates. A refusal only an
  AX walk of another app can tell is the one exception: the walk
  runs off the main actor, so the verb replies `.ok` ("asked")
  and the refusal is a Core-drawn refusal pill through the one
  `flashRefusalPill` door, plus a log line (#1518's New Window
  and Close Window, `BarWindowActionRowsTests`; the door's
  callers and its one primitive call are `RefusalCueSeamTests`
  ▸ `pillDoorCallersAreNamed`). Nothing scans for
  a menu-only path, so this is review's; `BarWindowMenuRowsTests`
  drives the rows through their verbs.
- **A row that writes a stored setting goes through its setter,
  then the one `writeThroughLiveProfile` door**, whose draft
  policy is [profiles.md](profiles.md)'s (`BarMenuRowsTests` ▸
  `discSetsTheSpan`). A session value — a Layout pick, the
  divider's reset — takes the setter alone, as its other doors
  do.
- **The Layout rows' look is `LayoutModeRows.entries`**, which
  the status item's Layout menu builds from too; each side hands
  it its own words, so no sentence crosses the #96 seam.

## A Space wears one marker, drawn after its identifier (#1790)

A held Space (#1507) and a temporary one (#1790) each wear a
marker after the identifier, in its ink, and a Space is never
both, so the two share one `markerView`. **A further Space state
joins `SpaceBarItemView.Marker`**, which picks the symbol and the
`spaceName` sentence in one place, rather than growing a second
view; **its slot is measured through the one `markerLength`**,
which `autoLength` and the layout both add, so the length the
shelf plans is the one the item draws (`SpaceBarCollapsedRenderTests`);
and **no marker is gated on `style.stickyBadge`**, which hides
window state alone (`TemporarySpaceBarTests` ▸
`stickySwitchKeepsMarkers`).

## A per-display bar answers the SHOWN question, never the render one

A bar is built per display, so a per-display value sits in easy
reach of every derivation inside it. #1214 reached for one: the
Space Bar handed each screen's own shown Space into #445's render
verdict as if it were the focused one, and every screen's bar was
told a ∞ window rendered there while the layout drew it on one.
The `+n` badge's focus tint beside it was the same substitution a
second time.

The presence half is no longer policed here at all: the
derived-verdict obligation in
[state-and-layout.md](state-and-layout.md) owns it (#1225), and
this file would only be a second copy to rot. What is left is the
reading a bar still makes for itself:

- **A bar derivation reads `state.windows`, never the away
  ledger** (#1228). The bar draws the Desktop in front of the
  user: a window KiwiDesk parked is its to draw, a window macOS
  is showing on another Desktop is not. The obligation and its
  two residues are
  [state-and-layout.md](state-and-layout.md)'s — this line
  exists because that file does not load when you edit
  `Bar/**`, and the next new bar surface (#1229's overview
  panel) is written here.
- A bar derivation answering *which window holds the SYSTEM
  focus* — the glyph tint, the `+n` badge's — reads
  `workspaces.lastFocused` and gates on the active Space, never
  on the display's own shown one and never on a Space's
  remembered `focused` slot. Those diverge on an injected ∞
  traveler, which holds `lastFocused` and can never be the
  membership-guarded `space.focused` (#431), and that is the one
  case the `+n` tint exists for.
- `currentSpace(on:)` answers *which Space is this screen
  showing*: the item that draws as active, the Space a bar is
  BUILT for, chrome coverage. It is a bare alias of
  `activeSpace(on:)`, so a new read states which of the two
  questions it means in a word beside the call — they are one
  token apart and read identically at a glance.
- `SpaceBarStickyScreenTests` pins the two-screen half from the
  driver: the ∞ arm on both sides of a switch, the 📌 arm that
  refuses the over-broad "prune every sticky off an unfocused
  screen" fix, and the `+n` tint — which on 2026-09-02 was the
  only test in the tree that redded when that gate was reverted.
  The single-screen suites
  stay blind to all three by construction, which is why they are
  their own file rather than added expectations.

## The bars start motion in one home, and that home gates it

A bar animation is gated on Reduce Motion, and `BarMotion` — its
file and the extensions split from it at the §2.1 ceiling, which
`BarMotionSeamTests.homes` lists and censuses alike — is where
every one of them lives (#1078). `Sources/KiwiDesk`'s gate
is spelled per call, in the argument, because a SwiftUI
animation carries one to name; an AppKit frame write does not
(`view.animator().frame = f` takes no animation argument at
all), so the bars take the other shape tests.md sanctions — one
home, routed through the seam, applied exactly once.

Obligations:

- **A new bar surface animates through `BarMotion`**, never
  beside it. `BarMotionSeamTests` holds that, and it scans ALL
  of `Sources/KiwiDeskCore` rather than the bar paths: a bar
  surface lands wherever it lands — #1229's overview panel is
  the next one — and a guard scoped to the directories bar code
  occupies TODAY cannot see the one that arrives outside them.
  Its `allowed` map is the one copy of who is exempt, and a
  ruling that fires on nothing reds, so an entry cannot outlive
  its site.
- **A member added to `BarMotion` owes a census entry** naming
  the gate its body reaches, and one that starts motion may not
  be censused as starting none. That clause is the fail-shut
  half: the routing clause exempts the home file by design, so
  without it a fourth ungated wrapper is invisible to every test
  in both suites — which is where a hand-listed case list left
  it (guard-prover). Deleting the gate inside a shared helper
  ungates every caller at once while the routing clause stays
  green, which is the failure [gui.md](gui.md) ▸ the Reduce
  Motion gate rejected an abstraction over.
- **A decision takes the flag as an argument**, so it is
  assertable: `BarMotionTests` pins the collapsed group
  duration, the frame write that lands instead of travelling and
  both shapes of the drop ring, and none of them reads the live
  setting. `BarMotion.isReduced` is the one expression a test
  cannot reach, deliberately — it is the whole of what is left.
  **Every entry point takes the same shape** — a `@MainActor`
  wrapper that reads, a pure decision that is handed the answer
  — because a second shape beside it owes the seam suite a
  second clause, and the clause a caller-fed gate needs cannot
  be the one a wrapper-read gate needs.
- **The gate drops the MOTION, never the affordance**, and **a
  DELAY is not motion** — a quiet window before something
  appears survives the gate at its full length, because
  shortening it changes what the affordance MEANS rather than
  how it travels. What a stand-down costs the user is a product
  ruling and not this file's: `docs/design-decisions.md` ▸ the
  bars honour Reduce Motion argues the two that `BarMotion`'s
  decisions implement, and a third is argued there, not here.

## A stored Fill becomes a colour on glass in ONE place

The same shape, one subsystem over, and for the same reason it
was needed there. `GlassTint.apply` clamped the coloured backdrop
to `GlassTint.maxAlpha` while `GlassPlate.update` set
`NSGlassEffectView.tintColor` from the raw Fill beside it — and a
clamp with an unbounded sibling is not a clamp. Every bundled
palette ships a bar fill at `…B3`, so the ungoverned channel ran
at 0.70 on a default install and the plate rendered as a
near-solid slab for as long as the finish shipped (#1297).

Obligations:

- **A glass surface takes its colour from `GlassTint.apply`**,
  which is handed the Fill's **hex** and never an `NSColor`. The
  narrower parameter is the rule, not an accident: while it took
  a colour, a call site could substitute one for the capped one
  and every guard stayed green — the same bypass one level up
  from the one that was being closed. A surface that genuinely
  needs a non-Fill colour on glass earns a second mint inside
  `GlassTint`, never a colour parameter.
- **An arm that moves a glass among its siblings ends by calling
  `GlassTint.apply` and never re-orders the backdrop beside it.**
  `apply` repairs the order only where it is wrong: a sibling
  move of the glass — the Space Bar's `spanBackdrop` arm — left a
  backdrop inserted once above it for the rest of the process
  (#1314), and a per-render reparent would be the churn #1315
  names. `GlassTintOrderTests` holds the order through the real
  arm via `SpaceBarManager.sync`, requiring the arm rather than
  trusting the fixture's arithmetic, and holds the no-reparent
  half on a counting parent — AppKit fires no view-level callback
  for a re-add, so only a parent can see one. Residue, stated
  because it fails OPEN: an arm that inserts its own sibling
  DIRECTLY beneath its glass makes the repair fire every render,
  silently; the no-reparent clause is not through the arm.
- **A steady-state bar render reparents nothing into a glass
  subtree.** A view moves only on a host CHANGE, and the arm that
  changes the host is the one that names it — the Space Bar's
  `prepareGlassHosting` creates the hug run and picks the
  segment's host in the same arm, with no fallback — while a
  z-order need is met by the positioned insert at that change,
  never by a per-render re-add: the segment is laid out after the
  last item, so it and the items never overlap (#1315,
  `SpaceBarFrontViewChurnTests`, whose add count is the one
  clause that sees a wrong hug host, since `hugRun` re-hosts any
  stray). A same-parent re-add fires no AppKit hook and is a
  reorder, so a guard against one counts inserts at the PARENT or
  pins subview identity, never a view-side callback (#1314 too).
  The pinned arm's plate move is order-guarded the same way, and
  its ORDER half is `GlassTintOrderTests`' index pin; its
  no-reparent half has no counting clause — stated, fails OPEN.
- **A view a glass hosted leaves it only through
  `GlassPlate.release`, and a bar tears its per-item glass down
  BEFORE the frame pass that places the items it hosted** (#1730).
  Hosting turns `translatesAutoresizingMaskIntoConstraints` off;
  a hand-back that does not restore it is laid out at its
  intrinsic size in the corner, and so is an item still inside a
  glass when a frame pass that frames only the container's
  subviews runs — `GlassPlate.setContent` releases what it
  displaces for the same reason (`GlassHandBackTests`;
  `GlassHandBackSeamTests` reds a glass `contentView =` write
  outside `GlassPlate`, in either Sources tree).
- **Build the fade in `GlassTint.apply`, from an edge every call
  site hands it — never a default** (#1622). A surface on no
  screen edge — the drag markers, the sticky mark — hands `.top`
  by ruling, a fade downward (#1620, #1621). The
  backdrop is a `GlassBackdrop`, whose BACKING layer is the
  gradient so it rides the plate glide; a sublayer would jump to
  the final size. A call site that dropped the shelf's edge
  for a constant draws every shelf as a top shelf — which only a
  fixture on another edge can see (`GlassTintFadeTests`,
  `GlassTintCensusTests` ▸ `applyTakesAFillNotAColour`), and the
  backdrop paints nothing of its own (`GlassTintCensusTests` ▸
  `backdropPaintsNothing`). An EMPTY Fill is no colour there —
  clear glass, nothing pinned — which the drag marker's fill-off
  and the sticky mark's Automatic both hand it
  (`OverlayGlassTests` ▸ `uncolouredMarkIsClearGlass`).
- **A glass surface is thinned only by a ruling, and only on its
  own view's opacity.** Both drag markers' glass sits at
  `DragMarkerView.glassOpacity` so the window a drop swaps with stays
  readable (owner, device 2026-09-25); there the
  `maxAlpha` premise — a floor on how much refraction survives —
  does not hold, by that ruling. A second thinned surface argues
  its own entry in `docs/design-decisions.md` first
  (`OverlayGlassTests` ▸ `markerGlassIsThinned`).
- **`GlassPlate` takes no colour at all.** It is geometry. The
  channel it used to drive carries none of a Fill's hue — see
  `docs/design-decisions.md` ▸ Liquid Glass for the measurement —
  so a surface reaching for it is asking for a dimmer while it
  looks like it is asking for a tint.
- **A member added to `GlassTint` owes a census entry** naming
  what its body reaches, and one that paints without routing
  through the clamp may not be censused as routing.
  `GlassTintSeamTests` is the fail-shut half — every other clause
  in it exempts the home file by design, so without the census a
  second unclamped painter inside `GlassTint` is invisible to
  both suites, which is exactly the hole the equivalent
  `BarMotion` clause exists to close.
- **The number is retuned against a ground with STRUCTURE in
  it**, and the argument lives in `GlassTint.maxAlpha`'s
  docstring rather than here (tests.md ▸ #1021). A flat wallpaper
  shows no refraction at any alpha, so it cannot answer the
  question it looks like it is answering; and what actually binds
  the cap is the bar's own ink, which is fixed palette hex with
  no vibrancy path, so the plate is its legibility floor at the
  fade's anchor edge; at the clear end, where it runs at
  `GlassTint.floorShare` of the cap, the #1308 dark pin carries
  the ink, so a retune measures the ink at both ends.
- **The glass's light/dark variant is PINNED from the Fill in
  `GlassTint.apply`, never left to the OS per view.** macOS
  decides a Liquid Glass view's variant from the backdrop that
  view samples and holds the verdict, so two bars sharing a Fill
  diverged with identical KiwiDesk state, and every eyeball
  reading blamed whichever bar was in the dark state (#1308; the
  numbers are in `docs/design-decisions.md` ▸ Liquid Glass). A
  dark Fill pins `.darkAqua`; a light Fill pins nothing, so the
  glass carries `NSApp.appearance`, which the Settings Appearance
  pick writes (#678) — two writers reach one view, and the
  precedence is the Fill's where it is dark and the pick's for
  the rest, ruled in that entry. Only dark can be pinned, and
  that fact is scoped to the ambient it was measured in by
  `GlassTint.pinnedAppearance`'s docstring, never restated here.
  The threshold is `wantsLightInk`'s — one copy with the mark
  glyphs — and `GlassTintPinTests` holds the consumer,
  including that a light Fill LIFTS a pin the previous Fill left.
  Nothing else in Core writes `.appearance =` on a view
  (`GlassTintSeamTests` ▸ one-home clause, allow map empty by
  design); a surface that needs to owes `docs/design-decisions.md`
  an argument first.
- **A `Sources/KiwiDesk` surface that tints glass owes this suite
  a root.** `GlassTintSeamTests` scans Core alone, so the GUI
  tree is not covered by it — a Fill→colour derivation that lands
  there is invisible until someone widens the roots. Note the
  reason to think twice before writing one, which is not a
  capability limit: SwiftUI's `Glass.tint(_:)` **does** work, and
  the near-colourless finding above is AppKit's. What the bars
  lack is a vibrancy path for their ink, which a SwiftUI surface
  drawing `.primary` / `.secondary` over a material has — so the
  argument that forces a tinted fill onto a bar does not reach
  that tree, and a tint there is a design choice needing its own
  ruling rather than an inherited one.
- **Reduce transparency stands the glass down at the one
  render-time read, and never by moving the stored value**
  (#1374). `NSGlassEffectView` ignores the setting — measured
  2026-09-13, live and at creation — so each overlay's `render`
  resolves its stored style through `LiquidGlassGate.rendered`
  exactly once — glass off AND the Fill at full alpha, since the
  setting asks for opaque backgrounds — and every consumer
  downstream (`glassEnabled`, `hasBox`, `GlassHosting`, the
  plate painters) reads the copy; `GlassTint` refuses a
  colour beneath it as the net, and the observer that re-draws
  BOTH bars on the flip is wired in `start()` and retired in
  `stop()`, its token owned per core and never a static — a
  stopped core draws nothing, and the next core must not inherit
  the last one's observer. A new bar surface's render takes
  the same read — the roster is DERIVED Core-wide from every type
  reaching `GlassHosting.resolve(`, the one hosting decision —
  spelling its stored style nowhere but as the
  gate's argument, and a new reader of the OS flag in Core is a
  second gate free to disagree with the first
  (`ReduceTransparencySeamTests`: one home per tree, one read per
  render on a stored style read once, both bars in the handler,
  every glass fixture pinned; `ReduceTransparencyTests` holds the
  behaviour and the observer's delivery). Why the OFF shape rather
  than an opaque glass is `docs/design-decisions.md` ▸ Reduce
  transparency.

## A Space Bar text glyph is framed through the one `BarTextGlyph.frame`

A label's `cellSize` carries ~8 pt of cell padding around the
advance, so at a thin bar it exceeds the square glyph cell for
every App Font ligature — and `NSTextFieldCell` then draws the
string LEFT-aligned whatever `alignment` says, so a frame the
size of the cell clipped the trailing quarter of the ink at the
thickness floor (#1529). The vertical-centring block that came
with that frame had already been hand-copied once, from the
item's `place` into the front-app segment, which is how both
sites clipped alike.

- **Place a text glyph in a Space Bar cell through
  `BarTextGlyph.frame` and nowhere beside it**: the frame takes
  the label's own width, centred on the cell so the alignment
  holds, shifted so the INK is centred rather than the advance
  (the neighbours are image cells, whose pixels centre; a
  ligature's slack sits on its trailing side), and a glyph whose
  ink would reach past the cell by more than the SLACK its site
  states is scaled to fit — an app cell states none, since its
  neighbour abuts; the identifier states the item's pad, so a
  three-digit id or a monogram keeps the ladder's size and
  reaches into the pad rather than shrinking beside a one-digit
  neighbour. The helper returns unaligned geometry and the site
  rounds ONCE to its backing. A new site owes
  `SpaceBarGlyphCellTests` a clause of its own — the suite pins
  the item's and the front-app segment's fields by rendering
  them, and reads no site list, so a third site that framed by
  hand would stay green there.
- **Anchor a bar text glyph by its INK, through
  `BarTextGlyph.Metrics`' placements, never by its advance or its
  frame** (#1543): centring the advance drew an App Bar glyph a
  sixth of the slot to the left, and snugging the frame's
  trailing edge to the name left the slack between glyph and
  name. The App Bar's icon slot (`AppBarItemView+GlyphSlot`)
  keeps its own font-scaling and `snugToName` rulings and takes
  `originX(centringInkOn:)` / `originX(inkTrailingAt:)` /
  `originX(inkLeadingAt:)`; a badge hangs on `glyphInkFrame`,
  whose x-span is the ink's — the label's frame carries the
  cell's padding on that axis. `AppBarGlyphInkTests` renders both anchors
  and holds their OUTPUT — a hand-copied CoreText read that
  anchored the ink correctly would stay green there, so the
  routing is review's.

## An indicator's weight comes from the shelf, never a literal

`kiwishelf.highlight_width` (#1680) is the weight of both bars'
active indicator, so every stroke drawn in `highlight_color` to
mark the current Space or focused window reads it.

- **A drawing takes `KiwiShelf.resolvedHighlightWidth` for an
  outline and `edgeMarkThickness` for an edge mark**, never the
  stored `highlightWidth` (a writer that skips the clamp would
  reach the screen) and never a point literal. The Space Bar's
  drop ring morphs into the outline, so it strokes alike.
  `HighlightWidthTests` builds both bars' item views and the
  drop ring and holds their strokes to the width.
- **A preview of the bar draws the draft's width**, scaled from
  those two readings: the Settings Bars preview carries them on
  its `BarSpec` (`HighlightWidthPreviewTests` holds the spec).
  That the strip then strokes with the spec's widths rather
  than a literal is review's — no clause renders it. A new
  indicator surface owes one of those suites a clause, since
  neither reads a list of sites.

## The shelf's border is painted in one place

`kiwishelf.border` (#1679) rims the plate under Plain, and each
box — both bars' items and the Space Bar's front-app chip — under
Boxed.

- **Every rim goes through `ShelfBorder.paint`**, handed the
  SURFACE it rims (`.plate` or `.box`) and never a verdict: which
  surface the shelf rims is `ShelfBorder.rims`, from
  `KiwiShelf.drawsPlate`. It reads `KiwiShelf.drawnBorderWidth`
  (0 while the switch is off, the clamped width otherwise) and
  `borderColor`, never the stored width. The rim is its own
  fill-less, click-through view framed to the surface, so it
  strokes on the edge, never inset: above the plate or the
  chip's glass, and beneath an item's active outline, which
  strokes over it. `ShelfBorderSeamTests` holds the one home:
  only the painter reads the drawn width in Core, and in `Bar/`
  the only layer-border colour written beside it is the active
  indicator's. `ShelfBorderDrawingTests` builds the plate (solid,
  glass, under Reduce transparency), both bars' boxes and the
  chip and holds the stroke, its place in the order, and its
  absence while off; a new rimmed surface owes that suite a
  clause.
- **A preview of the shelf draws the draft's border**: the
  Settings Bars preview through `PreviewPlateEdge` on every
  plate and box, from its `BarSpec` (`ShelfBorderPreviewTests` ▸
  `edgeStrokesTheBorder` and `ShelfBorderPreviewTests` ▸
  `stripsTakeTheEdge`), and the palette scene only while the
  draft's switch is on — `drawsBorder` has no default, and every
  scene hands it the draft's switch (`ShelfBorderPreviewTests` ▸
  `sceneRimFollowsTheSwitch` and `ShelfBorderPreviewTests` ▸
  `scenesReadTheSwitch`).
- **Every bundled palette carries `kiwishelf.border_color`**,
  measured as drawn — composited over the plate over the
  palette's HOME wallpaper, the extreme its plate contrasts least
  with — against that wallpaper, at the idle floor
  (`ShelfBorderContrastTests`). The switch and the width are not
  palette keys (#375).

## An item's content is sized to the content depth, never the thickness

`kiwishelf.glyph_size` (#1713, retiring #1682's item padding)
sets how large an item draws inside the thickness while the
thickness stays the reservation, so a content size read off the
strip's depth draws the full size beside smaller neighbours.

- **Size an item's content through the look's strip-depth
  readings** — `contentDepth(forDepth:)` for a cell, an icon or a
  badge, and the `forDepth:` font ladders, which take the glyph
  size once inside. Hand them the STRIP depth; the
  `forContentDepth:` ladders are for a caller already holding a
  content depth (the Settings preview's schematic), and a live
  bar passing them the strip depth compiles and draws full size.
- **A box keeps the full depth**: an item, the front-app chip, a
  plate, a corner radius. A RULE inside an item is content — the
  identifier divider runs the content's share, centred on the full
  depth — while a section or layer divider between runs keeps the
  full depth.
- **A new consumer owes a clause** in `GlyphSizeSpaceBarTests`
  or `GlyphSizeAppBarTests`, which render both bars at a glyph
  size and read no list of sites; the preview's own guard is
  `GlyphSizePreviewTests`.

## Bar text takes its face from `BarFont`, never a system call

`kiwishelf.font_family` and `font_weight` (#1681) are the face of
both bars' text — Space identifiers, titles, counts — so a site
that builds a system font of its own draws text the setting never
reaches.

- **A bar text site asks `KiwiShelf.textFont(ofSize:)`, and a
  count `badgeFont(ofSize:emphasis:)`**, handed the size the
  section above derives (the look's `forDepth:` ladders, the
  content depth) — size from the glyph size, face from the shelf —
  and never `systemFont` or a
  family of its own; an App Font glyph and an app icon never ask
  either. A site that MEASURES text (a slot width, a segment's
  extent) asks the same, or it sizes for a face it does not
  draw. `BarFontSeamTests` counts every system-font spelling in
  `Bar/` and `Layouts/`, by path, against its `allowed` map —
  the one copy of who is exempt — and `BarFontSiteTests` builds
  each site and holds its face to the shelf's; a new site owes
  the latter a clause, since it reads no site list.
- **Resolve the weight in `BarFont` at render time, never on
  write**: the stored weight is the user's number whatever the
  family, and a missing family is kept by name and reported
  (`ConfigIssue.Kind.missingFontFamily`). What a family has is
  memoized inside `BarFont` and forgotten only by the one
  font-set observer (`KiwiCore+FontSet.swift`, wiring pinned by
  `BarFontSeamTests` ▸ `fontSetObserverIsWired`); the one copy
  beside it is the Settings picker's list and row faces, read
  when it opens and kept for that open only. The argument is
  `docs/design-decisions.md` ▸ The bar font's weight is stored as
  asked. `BarFontTests` ▸ `familyRoundTripKeepsWeight` holds the
  round trip and ▸ `variableFamilyIsExact` the in-between
  weights.
- **Derive the missing-family issue at `updateBars()`, never in
  a writer**: every settings landing — a load, a profile apply, a
  Desktop binding, a monitor change, a Settings Save, a verb —
  reaches the one bar refresh, and `setConfigIssues` re-derives
  the font issue on every publish, so no writer hands it in or
  owes a call. A writer-side refresh is the shape that left the
  issue stale after `load_profile`. `BarFontIssueTests` ▸
  `followsProfileSwitch` and ▸ `fontSetChangeRederives` hold it.
- **Set every bar text's baseline through `BarTextGlyph` — the
  font's `Band` centred on the item, one baseline per font and
  band — never by centring its line box and never by a string's
  own ink** (#1707): an old-style 3 descends where a 1 does not,
  so per-string ink centring gave each digit its own baseline,
  and a tall face's ascent lifted a centred line box off its
  item. The band is the SITE's role, never read off the string:
  a count or badge takes `.figures` (the ink of the font's ten
  digits, since old-style figures sit below the caps' middle), a
  title or name `.caps`, and only a Space identifier is judged
  by its text through `Band.of(identifier:)`. A string-read band
  put "3" and "+3" badges in one item on two lines
  (`BarTextBaselineTests` ▸ `identifierFigures`,
  `BarTextBaselineSiteTests` ▸ `overflowBadgeLine`; one baseline
  per band is ▸ `numeralsShareABaseline`). A
  cell site takes `frame`, free-running text (the App Bar title,
  the front-app name, `ShelfCountView`'s number) `originY`, and a
  badge cell `lineTop`; an App Font ligature is an icon and
  centres its line box. Never set `usesSingleLineMode` on bar
  text: it draws a tall face above its own ascent, clipping it.
  `BarTextBaselineTests` and `BarTextBaselineSiteTests` render
  each site in Apple Chancery, and `SpaceBarGlyphCellTests` ▸
  `identifierInFaceIsWholeAndCentred` a tall and a mono face; a
  new site owes one of them a clause, and `BarTextFieldCensusTests`
  holds every bar text field to a named door. The Settings
  preview draws SwiftUI `Text`, which centres its line box, so it
  is not baseline-faithful for a tall face — residue, stated; so
  is `ShelfCountView`'s stacked arm, whose number takes the same
  `originY` line as the side-by-side arm the suite renders.
- **A preview of the bar draws the draft's face** through the
  same resolver (`BarSpec.textFont`); that the strip then draws
  with it is review's — no clause renders the text.

## The App Bar's row reorders; its floats do not (#1826)

- **List a float after the App Bar's row, never in `barGroups`**:
  `moveBarItem` indexes `barGroups`, so a float there would be a
  slot a drop could land in and a reorder would write into the
  tiled order. The overlay reads which items float from
  `Item.floating` alone — `tiledCount` and `breakAfter` take the
  tiled prefix from it — and Core's highlight reads the same flag
  (`appBarActiveIndex`). `AppBarFloatTests` ▸ `floatsTrailTheRow`
  holds the order and `AppBarFloatOverlayTests` ▸
  `floatDoesNotReorder` the drop.
