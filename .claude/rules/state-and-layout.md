---
paths:
  - "Sources/KiwiDeskCore/State/**"
  - "Sources/KiwiDeskCore/Tiling/**"
  - "Sources/KiwiDeskCore/Layouts/**"
  - "Sources/KiwiDeskCore/Commands/**"
  - "Sources/KiwiDeskCore/App/**"
  - "Sources/KiwiDeskCore/Tabs/**"
  # `Space` and the values it holds live in Models, so the
  # flat-array rule and the per-space session state below govern
  # an editor there. parity-tests.md and config-vocabulary.md
  # glob it too — they own the mirror and the naming halves,
  # this one owns the shape.
  - "Sources/KiwiDeskCore/Models/**"
---

# State, tiling & layout

Canonical for this subsystem (AGENTS.md §1 and §5 index it). When
editing here:

- Windows live in a **flat `[WindowID]` array per space**. Do not
  introduce tree or container structures into state or layout code.
- Layout algorithms are **pure functions** over that flat array —
  keep them actor-free and unit-testable; no AX or AppKit calls.
- Display **bounds** reach layout only through
  `TilingEngine.visibleBounds` (#531) — layout slots, track
  capacity, the resize spans in `Commands/` and the float nudge
  in `App/` all read it, never `GeometryUtils.axVisibleFrame`
  directly. A direct call re-imports the host's real screen,
  which is what made identical code build different arrangements
  on a dev Mac and a CI runner (#523).
  `VisibleBoundsRoutingTests` scans the whole `KiwiDeskCore`
  target and fails on an unlisted direct call; **its `allowed`
  map is the exemption list** — which files may call it, and
  why — so add the entry there rather than a note here.
- A layout **span** reads one hook further in:
  `TilingEngine.layoutBounds(on:)` (#537), which reserves the
  Space Bar's strip (#293) so a resize divides its delta by the
  region the layout filled, not the whole display. Routing
  through `visibleBounds` and then dividing by the display
  passes the guard above and is still the bug —
  `LayoutBoundsRoutingTests` is the second net, and its
  `allowed` map is likewise the exemption list. The exception is
  a rect used as a *containment box* for a window the layout does
  not place: no span, no midpoint, and the painted-strip clamp
  (#242) owns its relationship to a bar. Which files qualify
  lives in that map, not here.
- Space identifiers are **strings** and case-sensitive; numeric
  strings and integers are equivalent (`"1"` == `1`).
- A retile may **promise** that every window it touches is
  spring-sized (`BatchSizing.allSpringSized`, #593), which lets a
  shrinking pane slide its shared edge instead of snapping. The
  promise is false for any pass that opens, closes or re-slots a
  window — that reintroduces #45 — so it is opt-in and
  allow-listed by `BatchSizingRoutingTests`. The argument lives
  on `BatchSizing`; it is named here because every site that can
  break it is in `Commands/`, `Tiling/` or `App/`, while the
  subsystem rule that owns it
  ([input-and-animation.md](input-and-animation.md)) only loads
  under `Animation/`.
- The **create fold's spawn grant** — the focus a fresh window
  gets for existing, not one macOS reported — consults
  `ManagedWindow.isTransientOverlay`
  first, and asks **state** rather than the incoming snapshot,
  because the create fold clears the flag when a remembered-tiled
  restore heals the window. A popup that surfaces as an AX window
  collected the whole apparatus of being focused, dismissal
  handoff included, from a grant nobody asked for (#671).
  Weigh the reach before widening this to a slot-wide rule: the
  same flag covers layer-0 dialogs and panels, which `#300`
  ruled behave correctly and want their focus, so barring them
  from the slot would put every focused command on the window
  behind the one being typed in.
  `TransientOverlayFocusTests` pins both arms; the product
  argument lives in `docs/design-decisions.md`.
- **A window that lands on another screen takes THAT screen's
  space, through the one shared predicate** (#1010):
  `StateCoordinator.screenHome(of:leaving:landingOn:)`. Two
  call sites ask it about the same defect, and **each must gate
  itself so that exactly one answers a given move**: the create
  fold answers only for a departure it WATCHED (never a
  `.restored` filing), and `moveToDesktop` only for a Desktop
  its screen is ALREADY showing (`target.isCurrent`), which is
  the case that produces no departure at all. Answering a hidden
  target in the verb as well is not redundant but WRONG — the
  destination would be the space that screen shows now, while
  the reveal can activate a different one, and the reap would
  then remember the window on the arrival's own display and
  stand the fold's rule down. A third site that needs "which
  space does that screen show for a window landing on it" joins
  the predicate rather than re-deriving it; the stand-downs —
  float, sticky, same display, nothing shown — live on it,
  once. The product ruling is `docs/design-decisions.md`'s.
- **Resolve the arriving frame's screen ABOVE the pure core,
  and let the fold decide from it** (#1010). `KiwiCore.handle`
  writes `StateCoordinator.arrivalDisplay` inside the
  `.windowCreated` arm and BEFORE `state.apply`, which consumes
  it; the decision itself stays in the fold, on pure state. A
  frame is AX coordinates (y grows DOWN) while `Display.frame`
  is AppKit's (y grows UP), so comparing them inside this
  actor-free core is silently wrong on exactly the topology
  that needs the rule — a second screen at a negative y.
  `TilingEngine.screen(containing:)` resolves the pair
  correctly, over `GeometryUtils.axVisibleFrame(of:)`, which
  owns the flip. Re-home through `workspaces.add` — the fold's
  own, or `addFocusedToSpace` at the command altitude — never
  `moveWindow(_:to:follow:)`: it fires a focus hand-off, the
  move latch and the #446 wallpaper focus yield, and both
  callers have already chosen their own focus policy.
  A command-altitude re-home also owes what `moveWindow` owes:
  the destination's focus stamp (#22 — `workspaces.add` nils
  `lastFocused` and hands the origin's `focused` to a
  successor) and a retile of its own, since the branch it rides
  may stand down without one. `ArrivalScreenHomeTests` and
  `ScreenHomePredicateTests` pin the rule and each stand-down;
  the two production wirings reach no unit test and are pinned
  by `ArrivalDisplayWiringTests` and
  `DesktopMoveRehomeWiringTests`.
- **A follow owes the window it sent away a focus, and pays it
  at the ARRIVAL** (#1007). `move_to_desktop_and_follow` onto a
  Desktop nobody is showing cannot focus the window at the moment
  of the move — AX does not list a window on an unshown Desktop —
  so `FollowFocusIntent` records the debt and the `.windowCreated`
  arm pays it, that being the moment the window is addressable
  again. Three obligations, and violating any of them leaves
  the behavioural suites green — `DesktopFollowTests` drives the
  paid path end-to-end and stays green through all three
  (guard-prover, #1007): the debt is recorded **only** for a
  switch that HAPPENED
  (a Desktop already shown produces no vanish and no reveal, so a
  debt recorded there is never drained); paying it is a space
  SWITCH — activate, focus, emit — because a bare focus leaves
  `focusedWindowID` naming the space the user left, so their next
  command acts there; and the departure stands the close-return
  raise down through the one `closeReturnRaiseStandsDown`
  predicate (the #936 clause below) rather than beside it.
  Key the drain to the arriving WINDOW, never to the reveal: a
  reveal is not scoped to the window that owes, so an unrelated
  switch inside the drain window would pay the debt and yank
  focus mid-swipe.
  `FollowFocusSeamTests` is the register of the production
  wirings — add a site there in the same change, since deleting
  any one of them leaves `FollowFocusIntentTests` fully green
  while the follow silently stops carrying focus. The ruling is
  `docs/design-decisions.md`'s.
- **The ignored-panel distrust mutates through its ONE state
  machine** (#21/#244/#951): `armIgnoredPanel` and
  `shouldConsumeIgnoredPanelReport` in
  `KiwiCore+IgnoredPanel.swift` are the only writers of
  `KiwiCore.ignoredPanel`, and `handleWindowFocused` the one
  consulting site — the #292 command guard is a read-only
  consumer. An inline `.insert` / `.removeAll` beside a focus
  call site is exactly the shape #951's disarm race grew from,
  and nothing scans for a new one, so each new focus-path
  author owes the routing deliberately. The #958
  accessibility-steal return is that machine's SIBLING, not a
  second writer: `KiwiCore+AccessibilityReturn.swift` owns its
  own debt the same one-machine way
  (`AccessibilityReturnTests`), and a new consumer of either
  latch routes through the owning file rather than reading the
  stored state beside a call site.
  `IgnoredPanelGraceTests` pins the machine's transitions (the
  dismissal grace, the click-provenance escape, expiry, the
  re-arm reset); the trade the grace accepts is argued in
  `docs/design-decisions.md`.
- **Sticky Desktop reach is owned state with ONE machine
  (#1145).** `KiwiCore+StickyReach.swift` derives every bridge
  membership and the `StickyReach` ledger reconciles them
  against the dispatch OUTCOMES — the membership query cannot
  see a second Desktop (#889 item 5), so nothing verifies by
  re-query, a refused add re-issues on the next refresh, and a
  believed-but-never-dispatched membership is the ledger lying
  to `retire`. Two obligations on a change here: a removal
  NEVER names the window's own memberships (the `homes` set
  threaded into `reconcile` — a removal there takes the window
  off the Desktop it lives on), and a new site that changes a
  sticky window's scope, home or the toggle joins
  `StickyReachWiringTests`' register in the same change,
  because the bridge is deaf under `swift test`, so a deleted
  hook leaves every behavior suite green
  (`StickyReachLedgerTests` and its sibling suites own the
  pure halves).
- A **native-fullscreen window keeps its `space.windows` slot
  but leaves both tiled-member derivations** (#670) — a layout,
  navigation or z-order consumer of the tiled members routes
  through `localTiledMembers` / `effectiveTiledMembers` and
  never re-checks `isFullscreen` at its own call site; only a
  walker whose domain is wider than the tiled members (the
  stash, which also parks floats, and a focus fallback reading
  `space.focused`) carries its own check. macOS moved the window to its own Space, so a
  frame-set, navigation step or raise aimed at it fights the
  fullscreen app or yanks the user into its Space. Nothing
  scans for a fresh open-coded `!isFloating` partition, so each
  new site owes the routing deliberately — three shipped
  without it in this rule's own change set. A fullscreen flip
  is a membership change and retiles (`shouldRetile`), and the
  **fullscreen-space verdict comes from `NativeSpaces.isUser`**
  — never from the nil Mission Control number, which cannot be
  told apart from "SkyLight unavailable", where the
  single-space fallback must keep bars and settles running.
  `FullscreenLayoutExemptionTests` pins the membership half and
  `FullscreenStandDownTests` the verdict and the gated surfaces;
  the argument lives in `docs/design-decisions.md`.
- A mutation that can change **which windows overlap** — a
  reorder, a swap, a focus move that crosses more than one slot —
  **arms the matching z-order restore after its own retile**
  (`scheduleScrollingZOrderRestoreIfOverflowing`,
  `scheduleTrackZOrderRestoreIfOverflowing`, or
  `scheduleZOrderRestore`), or `requestZOrderRestoreAfterDispatch`
  when the retile belongs to the command dispatcher rather than
  the call site. Arming *before* the retile lets the settle
  callback consume the restore off the pre-mutation frames
  (#153). Nothing scans for a mutation that forgot to arm, so
  each new one owes its own arm deliberately — three have now
  shipped without one (#150, #153, #674).
  Arm **narrowly**: a restore drains a verified raise sequence on
  the blocking ordered queue — holding the mouse warp for as long
  as that takes — re-asserts the focus at the end of it, and
  leaves the tiled plane above the float layer until the next
  genuine focus event (#418), so "harmless, it re-raises the same
  order" is not an argument for arming on a mutation that
  scrambled nothing.
  And the close-return stand-down governs the ARM, not only the
  direct raise (#936): a removal whose return raise stood down
  arms no track restore either, because the drain ends in a focus
  re-raise of the very anchor the stand-down refused, one settle
  later; the next genuine mutation's arm heals the pile. **Which
  removals those are is
  `EventLoop.closeReturnRaiseStandsDown(after:)` and not a list
  here** — this row carried one, a third arm landed under it
  (#1007), and a rule file that reads as instructions was
  carrying a false census until review caught it. A new arm goes
  in that predicate rather than beside it, so the raise and the
  arm can never disagree about which removals are exempt.
  Command-driven arms are exempt by ruling — an explicit user
  command is not an event-driven return raise; the product
  ruling (and which arms that covers) is
  `docs/design-decisions.md`'s. `CloseReturnStandDownWiringTests`
  pins both consulting sites.
  An arm in `focusWindow` guards against its own re-arm (the
  restore's closing re-assert calls back in) **semantically** —
  refuse because the focus is unchanged (`previousFocused !=
  id`, the jump test), never by gating on
  `zOrderRestoresInFlight`: that counter is warp-scoped, a
  drain holds it for its whole verified span, and a counter
  gate then drops GENUINE restores for exactly the window a
  double-target correction clicks into — the monocle arm
  shipped that way twice (#689). `ZOrderMonocleArmTests` and
  `ZOrderFocusJumpTests` pin one arm each.
- **Several raises that must land in a given ORDER go through
  `raiseSequentially` / `performZOrderSequence`** — never a loop
  of bare `AXHelper.raiseQuietly` calls. The AX call returns once
  the app has *accepted* the raise, not once it has performed it,
  so a loop issues the whole sequence inside the window where
  none of it has happened yet and the apps land it in whatever
  order they reach it — the pile settles scrambled (#684).
  `ZOrderDrain` owns the verification, the budget and the timings
  they are sized from; read them there rather than quoting them
  here. What earns the sequence is a landing worth verifying — an
  order to keep, or a floor the raise must clear; a raise with
  neither needs none of it. Nothing scans for a bare loop, so a
  new ordered raise owes this deliberately. Weigh a teardown
  raise harder than a live one, and buy it a bigger budget: the
  quit-grid restack's raises run after management stops, so no
  later restore can correct a miss and this rule's usual "the
  next restore heals it" does not apply there (#688,
  `KiwiCore+TeardownRaise`). Weigh, for any sequence, what the
  frontmost app's key window costs inside it: a quiet raise
  cannot beat that window, so it never costs only its own slot —
  every window the order puts above it waits out a whole
  `landingLimit` that can never be satisfied. The two shipped
  sequences answer that differently *because its role differs*,
  and a third must say which it is. The teardown restack drops it
  from its TARGETS, since the circle would otherwise order
  windows above it. The float raise and the monocle restore keep
  it out of the FLOOR instead (`raiseFloor`, which owns the
  measurement) — and knowingly leave it among the targets, the
  same class of residue `floatLayerTargets` already records for
  mixed CGWindow layers. Price that residue as **n ×
  `landingLimit`, not one**: the landing check carries the
  unbeatable window in every subsequent comparison, so a plan of n
  raises pays the limit n times and can spend the whole budget
  with the mouse warp held for all of it (architect review,
  2026-08-03). The two guards are
  `ZOrderTeardownDrainTests`
  (`aPinnedMemberIsDroppedNotAbsorbed`) and `ZOrderRaisePlanTests`
  (`floatFloorExcludesTheFocusedWindow`), and
  `ZOrderSequenceWiringTests` pins that the teardown call site
  still drops it.
- A context site that **materializes scrolled-out scrolling
  frames — or monocle's parked frames (#881) — threads
  `screenNeighbors`** (#878):
  `TilingSettings.context` defaults the flags to all-open (the
  single-screen verdict), and nothing scans for the omitted
  parameter, so a new site that computes real scrolling frames
  without threading the engine's per-retile detection
  (`ScreenNeighbors.detect` over the `allScreenBounds` topology
  seam) silently reverts every edge to open — the #878 defect
  returning without a red. `layoutInput` is the threading site;
  capacity probes, bar-strip carves and schematic previews
  rightly omit it and get every edge open. The wall verdicts
  are an input detected fresh each retile, never a cache —
  which is also why a stash or corner consumer reads the same
  seam rather than enumerating screens itself. And a corner
  consumer takes the corner PREFERENCE from
  `TilingEngine.optimalHideCorner(neighbors:)` — the one copy
  the stash and monocle's park share (#881) — never a
  re-derivation beside the flags, or the two answer one
  arrangement differently.
  `ScreenNeighborsPlumbingTests` pins the threading and the
  default; `ScrollingBlockedEdgeTests` the clamp forms.
- **An app-enforced size bound is learned, never assumed
  (#677).** AX exposes no min/max-size attribute, so the engine
  learns a bound from its own asks: `retile` records each issued
  size and reads the settled, echo-fed state frame as the app's
  answer — the same ask refused with the same answer twice
  confirms a per-axis, PER-ASK `EffectiveSizeBound` entry, and
  **only a SETTLED read may cast either of those two votes,
  with one named carve-out** (#1083). A raw echo seeds and
  refreshes a candidate; it promotes one only through #1049's
  comply-then-revoke pair, where an earlier echo reported the
  window AT the asked size and so proved it took it. Every
  other raw promotion is barred, because an echo reporting the
  pre-ask frame is the same bytes whether the app refused or
  has merely not redrawn yet, and under load the second is
  ordinary for any app. A new `SizeAnswerChannel` therefore
  owes an honest `isSettledRead`, and widening what counts as
  settled re-opens #1083 through that door —
  `SizeBoundBaselineTests` holds all three verdicts (the same
  fixture answered by a settled read, by one echo, and by a
  repeated echo) and is what reds if either term is dropped —
  ENTRIES never generalize across asks (a grid-snapping app
  answers each ask differently; the one deliberate exception is
  the compliance contradiction sweep, argued on `complied`) —
  while a CORROBORATED bound does, revocably (#1055, owner
  rulings 2026-08-27/28): `consumedWidth/Height` and `explains`
  answer an ask BEYOND `maxWidth`/`minWidth` with that bound —
  re-resolved once through the entry at the bound's own span,
  since the consume rewrites the ask the ladder sees — a
  per-ask entry outranks the generalization for any ask it
  matches, a FORCED (explicit-apply) pass probes past
  corroborated bounds via `LayoutContext.probesBeyondBounds`
  (never widen its producers past `retile(force:)`),
  corroboration requires asks `corroborationDistinctness`
  apart (a coarse snap's row height beats the entry-keying
  tolerance), and a corroborated ceiling corroborates the
  single floor entry at the same span — the fixed-span lend,
  paired values only. The cap consequence softens: an evicted
  ask beyond a still-corroborated bound consumes without
  re-dancing, while evicting the corroborating pair itself
  silently revokes the generalization until it re-learns. The
  argument and the probe evidence are `EffectiveSizeBound`'s
  header and the issue (`SizeBoundGeneralizationTests`,
  `ScrollingFixedSpanCueTests`, `ScrollingBoundRepackTests`)
  — and
  hold a ladder PER ASK up to `SizeBoundLearner
  .maxEntriesPerAxis` (alternating layouts starved a single
  slot, device QA 2026-08-18; keep that cap sized past every
  real producer, because an evicted candidate re-opens the
  starvation) — after which the
  un-forced skip treats the refused target as "already there"
  (ends the endless re-issue) and the layouts place the residue
  (scrolling re-packs, monocle and a lone scrolling window
  center). And only a SETTLED read — the retile-time gate, the
  settle probe — may clear learning on a compliance (#1049): a
  raw echo's compliance can be the transient half of an app's
  comply-then-snap-back (the Android emulator animates to the
  full ask, holds it ~0.4 s, snaps back), and clearing on it
  wiped the ladder every probe cycle, so "twice in a row" never
  accumulated and the dance re-issued forever
  (`SizeBoundInvalidationTests`,
  `SizeBoundTransientComplianceTests`). Three obligations
  follow. A frame-producing context
  build **threads `sizeBounds`** the way it threads
  `screenNeighbors` — `layoutInput` is the site, probes and
  previews rightly omit it (`SizeBoundPlumbingTests`). A path
  that changes a window's size outside the engine's asks **owes
  the ledger an invalidation** — a genuine resize forgets
  outright, rekey migrates — or a stale bound pins the window
  at a size the app no longer insists on
  (`RetileBoundSkipTests`). A GONE path (destroy, hide) is the
  #1049 carve-out to #152/#158's destroy-forgets: it takes
  `stashSizeBoundOnGone`, never a bare forget — the believed
  ledger parks in a pid-checked tombstone the same window's
  re-add revives before its arrival retile, because a slow-AX
  app flaps (dropped and re-added under the SAME id seconds
  apart) and a plain forget re-ran the whole learn dance on
  every flap and unhide. `SizeBoundReviveTests` pins both gone
  arms and the stand-downs; a NEW gone path joins the stash
  deliberately, since nothing scans for a bare forget beside
  it. And only the layout loop
  **records asks** — a stash park or float restore is not a
  layout ask, and learning from one keys a bound to a frame no
  layout re-issues. Rendering may
  additionally trust an UNCONFIRMED candidate (the overlay pin's
  fallback — cosmetic, self-correcting); geometry never may.
  The ladder is `SizeBoundLearnerTests`; the
  overlay half is [borders.md](borders.md)'s pin row.
- **A scrolling viewport offset travels with the slot it was
  measured against (#966).** One slot size serves the whole
  row, so anything that changes it — a resize, a `swap`, a
  window opening or closing ahead of the focus, a #677 re-pack
  — moves every slot underneath that offset, and `follow` is
  the one anchor that reads it. So `Space.scrollRest` carries
  the offset AND the focused slot it was measured against as
  ONE value: the same focus holds that slot's place on screen,
  a different focus holds the offset and pans minimally (#66).
  "Place" is the slot's leading edge, except where it was
  resting flush against the TRAILING border, which is the edge
  it keeps instead — otherwise a shrink tears it off a border it
  was sitting on, and two situations nothing on screen
  distinguishes (flush-with-more-behind vs last-in-row, which
  the boundary clamp already holds) answer differently. Flush at
  both borders takes the leading edge. Which is why the recorded
  slot carries the VERDICT rather than the geometry behind it —
  the argument for that is three paragraphs down, and is stated
  once.
  Three obligations follow. **Never split the pair into two
  fields** beside each other, and never re-derive the verdict
  at a call site — nothing scans for either, so each new author
  owes it deliberately. **A producer never DESTROYS provenance
  it was handed**: recording no slot is the "nothing has ever
  been measured" verdict, so a pass that carries an offset
  through carries its measurement too, and one that drops it
  silently reverts to the pre-#966 behavior. A new producer of a
  rest joins `ScrollingResizeAnchorEndToEndTests`, because a
  suite that injects the rest by hand cannot see a producer at
  all — which is most of them, and is why that end-to-end suite
  states a skipped host must read as a SKIP rather than a green.
  And a **new id-keyed home inside
  `Space` owes `Space.rekey`**: `scrollRest.slot.window` is a
  bare id in a struct, which `WindowRekeyParityTests`' count
  pin cannot see — only its `String(describing:)` scan can, and
  only because the fixture populates the field.
  And the verdict is reached at the PRODUCER, where the offset
  and the viewport it was measured in are both in hand: a
  consumer comparing a recorded extent against a later `along`
  is deciding flushness about a viewport the slot never sat in,
  which a bar toggle or a gap edit is enough to change.
  `ScrollingResizeAnchorTests` pins the discrimination itself —
  same focus, different focus, no slot, fixed anchor — and the
  row-end clamp that outranks it, that last on a NON-last focus
  deliberately, since a last slot at a legal offset is
  flush-trailing by construction and would let the border arm
  answer in the clamp's place. `ScrollingBorderAnchorTests` is
  the border half: the arm that keeps an edge, the tolerance
  that decides flushness, and the producer's recording.
  `ScrollRestPlumbingTests` pins the carrier. The product
  ruling — including why `swap` is ruled IN rather than
  excluded — is `docs/design-decisions.md`'s.
- **A resize store holding an absolute LENGTH owes a ceiling,
  and since #1057 the whole press DECISION lives in ONE pure
  type (#966/#1057).** `ScrollSlotDomain.decide` — reached only
  from the `writeCapped*` seam, which resolves the base input
  off the ENGINE's computed frame for the focused window
  (#1063, `ScrollingFreshLedgerPressTests`: a reconstruction
  beside the layout asked the ladder at a span no layout
  issued, so a fresh ledger ballooned the press; the consume
  of the layout-floored, viewport-capped store stays as the
  fallback for a focus the engine computes no frame for — a
  floating or native-fullscreen focus, mid-adoption) — owns
  every cap and refusal arm
  (`ScrollSlotDomainTests`); a new arm goes there, never inline
  in a writer. The obligations it holds: the press measures
  from the focused window's DRAWN span; a press the window's
  bound blocks outright refuses IN PLACE (pill, no write, no
  neighbor moved); never-reduce-a-configured-value is
  GROW-only — a shrink is the user's deliberate act and
  rewrites the store from the drawn span; the floor never
  raises the store and wins the narrow-display contradiction;
  the viewport truncation is a silent stop (no pill, no
  bounce). The #966 auto-store trim on the first press is
  RETIRED — the drawn-span base supersedes what it bought.
  The pre-#1057 clauses below stand where they still apply: A ratio or a share is bounded by
  construction; a length is not, so it can bank growth the
  layout never draws (`min(along, …)`) and then charge a press
  per invisible step on the way back. Three obligations for one.
  The ceiling clamps beside the floor at the interactive write
  site, never in the value type — `ScrollSize.minPoints` is a
  property of a slot and an ABSOLUTE-LENGTH maximum is a
  property of the screen (`maxFraction` is rightly in the type:
  a fraction is unitless). It is the area the layout DRAWS,
  taken from the same `windowFrame` carve
  `ScrollingLayout.metrics` caps against, never the layout
  region it is carved from — on a vertical axis the difference
  is the App Bar's own thickness, the same defect in miniature.
  And it never reduces a CONFIGURED LENGTH: an explicit
  `scroll.set_slot_size` above the ceiling is a deliberate
  statement that survives undocking, so a grow refuses rather
  than rewrites. An `auto`/`%` store is deliberately NOT covered
  — it resolves against the region, so leaving it alone would
  re-bank the strip on the first press; that trim is the rule
  working, not a defect to fix back.
  The focused window's learned app MAXIMUM joins the same
  write-site ceiling (#1055): believed only under the floor's
  own two-distinct-asks corroboration
  (`EffectiveSizeBound.maxWidth` / `maxHeight`, read through
  `effectiveMaxSize`), and it may only ever REFUSE a shared
  store, never trim it — one slot serves the whole row, so a
  trim to one window's limit visibly shrinks every neighbor on
  a grow press. A grow the app ceiling truncates cues
  `ownMaximum` on the focused window; one the viewport
  truncates stays wordless (`ScrollingAppCeilingTests` pins
  the refusal, the never-trim and the silence). A second
  absolute-length store, or a new `maxWidth` consumer, owes
  these obligations deliberately — nothing scans for a site
  that never wires the ceiling at all.

  **A press writes FORWARD, never across the store (#1083).**
  The layout draws a bound-pinned window at its learned limit
  and the press measures from that drawn span (#1057) — so
  where the drawn span sits on the far side of the store, that
  base wrote across it: a grow from a pinned 715pt window
  inside a 1160pt auto slot wrote 765 and trimmed the row, and
  the shrink mirror raised a 300pt store to 775. Take the base
  from whichever of the two lies forward of the press — `max`
  on a grow, `min` on a shrink — which keeps both #1057 cases
  and makes the crossing impossible by construction.
  `ScrollSlotDomainTests` holds both directions with the device
  numbers. Do NOT answer this with a guard on the write
  instead: that was tried and swallowed the press with no write
  AND no cue, and a press that does nothing must always say
  why.
  Scrolling is the only such store today, which is an
  observation rather than the rule.
  `ScrollingSlotCeilingTests` pins the drawn area rather than
  the region (on both axes — the vertical one is where the bar
  strip makes the difference visible), the configured-length
  rule, and the floor outranking the ceiling. That the ceiling
  is not in the value type is review's: no suite can see a
  maximum nobody wrote.
- **An interactive resize write goes through the shared capped
  writers (#933).** The keyboard `resize` verb and the mouse
  resize end call the one set of clamped writers — the
  `writeCapped*` family, named by that prefix rather than by a
  file, since it has already outgrown one
  (`KiwiCore+ResizeLimits` and `KiwiCore+ResizeScrollSlot`) —
  never a raw `writeSlotSize`,
  `writeSplitRatio*`, `writeMasterRatio` or `stackWeights`
  write from a resize path, which is exactly how the mouse
  `.scrollWidth` drag crossed the floor the keyboard path
  refused. The writers clamp each side at its members'
  effective minimums (`min_window_size`, raised by a #677
  learned bound) and cue a truncated attempt — a pill on each end
  (the trier names the reason, the blocker marks itself), the
  bounce on the trier
  (`ResizeSizeLimitFeedbackTests`,
  `ResizeNeighborLimitTests`). And a weight clamp divides the
  span the LAYOUT divides — the one
  `StackLayout.weightedSpan` copy, kept `minSizeMargin` above
  exact equality — never the raw region span, which crosses
  the layouts' cascade checks by exactly the gaps it ignored:
  that is how #925's clamp still collapsed a
  clamped-at-minimum track space into a pile
  (`WeightStepOutcomeTests`).
  And a write-time clamp is only half the guarantee (#944): it
  validates against the membership at PRESS time, so a track
  session store also rides the retile-time heal
  (`healTrackSessionWeights`, called from `KiwiCore.retile`;
  the math is `StackLayout.healedWeights`) — a NEW session
  weight store joins that heal in the same change, or a
  membership change after a legal write collapses the space
  into a pile the clamps cannot see coming.
  `TrackWeightHealTests` pins the wiring, `WeightHealTests`
  the math; the ruling and the stack-zone residue are in
  `docs/design-decisions.md`.
  And a track fold consumer — any site needing the folded
  track partition: the render, the `track.swap` guard, the
  heal — takes `TrackLayout.foldedPartition`, never a hand
  assembly of `counts` → `overflowCap` beside it. The hand
  copy shipped at three sites and drifted before the #944
  rounds extracted the one assembly; nothing scans for a new
  hand copy, so each new consumer owes the routing
  deliberately — a fold-rule change that updates the render
  and misses a hand copy re-opens the exact divergence the
  extraction closed.
- **A float safety NET asks `EffectiveFloat.applies`, never the
  flag alone** (#1178). `FloatingLayout` assigns no frames, so a
  `.floating` space's members are unmanaged in exactly the way a
  flag-floating window is — the bar clamp asked the flag, and
  those windows got neither a layout frame nor the correction,
  permanently. A net is a correction that places a window
  nothing else will (the clamp, the stash capture, the
  display-crossing re-anchor); a VERB is the user's own ask and
  keeps the flag until ruled otherwise, which `resize` still
  does. The mode arm names the space the window is judged ON —
  the TARGET for a move, the space a drop LANDED in — and a
  window that is not a member of that space passes nil, or a
  tiled sticky traveler is clamped against a screen it is not
  on. Nothing scans for a new bare-flag net, so each one routes
  deliberately; `EffectiveFloatTests` holds the algebra and
  `FloatingModeBarClampTests` the two consumers, each blind to
  the other by construction.
- **Derive where a float may sit in ONE place, and bound its
  SIZE there rather than its position** (#1091). `KiwiCore.floatBounds` is that derivation — the
  display's visible bounds with every PAINTED strip carved off
  its own edge — and a new consumer takes it rather than
  re-deriving a boundary beside a call site. It carves painted
  chrome rather than routing through `layoutBounds` for the
  reason `LayoutBoundsRoutingTests`' `allowed` map records
  against the float nudge: an empty bar is suppressed while
  `layoutBounds` still reserves its strip, so routing would bound
  a float out of a region no bar occupies. Fold both strip lists
  — a space shows one bar or two, on any edge — and rely on
  `AppBarGeometry.regionClear` being monotonic rather than on an
  ordering rule.
  Three obligations fall out. **Bound the SIZE there and leave
  the POSITION to the user**: the retile-time net fits an
  oversized float back inside the region, but must not enforce
  the screen edge, because it runs for every float on every
  retile and would drag back a window parked half off-screen by
  hand (`FloatRegionFitTests`; the net's own routing is
  `FloatRegionSeamTests`, since no behavioural test can see
  which entry the sweep calls). **A SIZE ask that an app can
  refuse owes a memo** — that net runs every retile, and unlike
  a position, a size is genuinely refusable, so an app whose
  minimum exceeds the region is re-asked forever without one;
  `FloatFitLedger` is #677's shape one subsystem over, and it is
  deliberately NOT an entry in `SizeBoundLearner`, which only
  the layout loop may record into. And **a resize that cannot
  deliver its whole ask owes a cue** — blocked or merely
  TRUNCATED, which is #933's own rule at the other end and was
  missing on the grow side; route it through `cueResizeRefusal`
  like every other (input-and-animation.md's funnel rule), which
  is also what ends a held glide at the wall instead of pilling
  per frame.
  The keyboard resize itself is symmetric with pinned edges, and
  **the pinning binds shrink as well as grow** — pin only on grow
  and grow/shrink stops being reversible at exactly the edge
  people park windows against. `FloatSymmetricResizeTests` holds
  the reversibility table, the both-pinned refusal and the
  accepted contact residue at half a step; the product argument
  is `docs/design-decisions.md`'s.
- An **explicit settings apply must `retile(force: true)`**. The
  engine's "already there" tolerance (±2 pt per edge) absorbs
  AX-echo lag and app-side clamping; un-forced, it swallows a
  small config edit entirely (a 1 pt gap edit visibly did
  nothing). Every retile triggered by an explicit `set_*` from
  Lua/CLI forces — `applyProfileScopedState`, `set_gap_*`,
  `set_min_window_size`, `set_mode`, the whole `layoutCommand`
  dispatch. Event-driven retiles stay un-forced so echo lag can't
  wobble windows. Profile applies classify themselves: see
  [profiles.md](profiles.md).

## Cross-layout logic must account for each layout's navigation model

Anything spanning all layouts — focus/swap navigation, overflow
handling, geometric neighbor search — must consider whether a
layout is *geometric* (a neighbor search over calculated slots) or
*array-order* (steps the flat array), and whether it can produce
an *overflow pile* (an `OverlapStack` cascade). The two models
need different handling (#172: exclude pile-mates from the
geometric candidate set vs skip their array indices; the shared
detector is `Navigation.pileMates`).

The authoritative map is the "Layout navigation & overflow models"
table in `docs/design-decisions.md` — a **new layout must add its
row** there.

## macOS native tabs are one `NSWindow` per tab, coalesced temporally

Finder/Terminal/Ghostty native tabs are separate `NSWindow`s
sharing one on-screen frame, each with its own `CGWindowID`, and
**only the active tab is ever visible to AX** — background tabs
never appear in `kAXWindowsAttribute`, and a fresh id is minted
per switch (#308 probe).

So a tab switch surfaces to reconcile as one window vanishing
while another appears at the same frame; `TabReconciler` coalesces
that pair into a `.windowRekeyed` (id swapped in place — no tree,
one slot per group) instead of a destroy + create. The gate needs
an `AXTabGroup` on **either** side (Ghostty exposes one only at 2+
tabs, so the 1↔2 boundary window has none). Coalescing is
suppressed on the native-Space-switch `reconcileAll`
(`coalesceTabs: false`) — same-app windows across spaces tile to
identical frames and would false-merge.

When editing tracking/reconcile, keep these facts in view: never
assume a window's `CGWindowID` is stable or that every tab is an
AX window.

---

`Commands/**` and `App/**` are in scope because they resolve the
same geometry the layout does (the resize spans, the float nudge
and the bar strips). The bounds, flat-array and space-id rules
apply there as written; the **pure-function** rule does not —
both are `@MainActor` and legitimately call AppKit. That rule
stays scoped to `Layouts/`.
