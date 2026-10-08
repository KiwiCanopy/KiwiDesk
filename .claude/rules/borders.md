---
paths:
  - "Sources/KiwiDeskCore/Borders/**"
  # The settle passes below are driven from App/, not Borders/ —
  # scoping this file to Borders/ alone would mean it never loads
  # for the exact file where someone would re-merge the two keys.
  - "Sources/KiwiDeskCore/App/KiwiCore+Borders.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+BorderSettle.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+Settle.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+StickyMarks.swift"
  - "Sources/KiwiDeskCore/App/DeferredTasks.swift"
  # The window stroke below is derived and stored beside the drag
  # markers, where a per-stroke store would be re-added.
  - "Sources/KiwiDeskCore/Tiling/WindowStroke.swift"
  - "Sources/KiwiDeskCore/Tiling/DragVisual.swift"
---

# Focus ring & sticky mark overlays

Canonical for this subsystem (AGENTS.md §5 indexes it). Two
overlay families — the focus ring (#278) and the sticky mark
(#414) — track the same windows through the channels the
table below lists,
so they share their decisions rather than mirroring them.

A new `BorderStyle` field owes a look ruling (#1739) — styling
joins `LookKeys.all`, anything else `LookKeys.leftOut` with its
reason; the obligation is [bars.md](bars.md)'s and
`LookKeysCensusTests` reds an unruled field.

The *product* rulings about these overlays (who gets a ring, why
the ring draws on an AppKit panel, why a fullscreen window gets
none) live in `docs/design-decisions.md`. This file is the
engineering side: which input owns an overlay's frame, and when.

## One type owns "which frame does an overlay render"

`FollowSource` holds both decisions — `renderFrame` for a
*reported* frame (which also corrects a #677 size pin, below),
`syncFrame` for the steady-state rebuild — and the ring and
the mark call the same code for each. Do not re-implement either
beside a call site, and do not bolt a guard on next to one: that
is the drift the type exists to prevent, and it is invisible in
review because each manager reads fine alone.

**A new decision INPUT is what the compiler can enforce.** Adding
an input changes the signature and drags both managers through the
change. Adding an enum *case* does not — exhaustiveness fires
inside `FollowSource`, never at a call site, so wiring one manager
and forgetting the other still builds green. That is why
`syncFrame` is a whole-choice hoist (one body, called from both)
rather than a case on `applies`: `sync` asks a different question
and returns a frame, not a bool.

## The frame writers, in descending authority mid-animation

While *our own* animation drives a window, the commanded per-tick
frame is the leading truth — every other channel trails it, by
100–300 ms on slow-AX apps (Electron/WebKit). So:

| Writer | Mid-animation |
|---|---|
| `follow(.animationTick)` | always applies — it *is* the truth. One correction (#677): when the animation's target re-asks a size the app has twice refused, the tick renders the commanded origin at the learned answer (`SizePin`, computed by `TilingEngine.animationSizePin` — from the confirmed bound, or provisionally from the first refusal's candidate, because a render self-corrects at settle while geometry must stay confirmed-only), because the window performs our position sets and refuses the size — `FollowSizePinTests` |
| `follow(.axEcho)` | stands down (#594), and also while WindowServer-tracked (#285) |
| `reconcile` (WS bounds re-read) | stands down (#594) |
| `sync` (`updateBorders()` / `updateStickyMarks()`) | geometry stands down (#596); create, recolor and retire still run, and so does re-order where the section below says it does (#1925) |

`sync` is the easy one to miss, because it reads as a rebuild
rather than a move — its spec frame is `state.windows[id]?.frame`,
written only by AX echoes, so a retile burst or focus change
landing mid-flight snapped the overlay back to the pre-motion
frame (~31 pt on device) until the next tick dragged it forward.
Since #881 the steady state has a second input: a just-issued
`applyInstant` target leads the echo-fed spec while its echo is
pending (`syncFrame`'s `commanded`, stamped by the applier,
cleared by the first self-echo or the echo grace) — monocle
park's instant switch has no ticks, so without it the ring
drew a whole switch behind.

Whatever holds the frame must also resolve **`screen` from the
same rect**: it selects the backing scale, so a held frame paired
with the spec's screen rasterizes the ring at the wrong display's
scale during a cross-display move.

## The focused ring consults the own-key-window seam

While the process holds an own key or modal window that is NOT
the focus anchor, the anchor is stale and the focused ring
stands down — the anchor draws an unfocused ring instead
(#933). A path deciding which ring is the focused one takes
that answer from the one `EventLoop.ownKeyWindow` seam. Since
#935 that seam returns ONE reading with two facets: the ring
reads the broad `number` — ANY own key window stales the
anchor — while the #929 close-return raise reads the narrow
`isDialog` facet. One closure resolves both, so the two
stand-downs can never disagree about WHICH window is key —
only about the ruled class. The why (Sparkle's alert flow, why
a number rather than a Bool, and the split's argument) lives
on that seam's own doc; the guard is
`BorderOwnKeyWindowTests`.

## Two settle passes, two deferred keys

They do different jobs and want opposite timing, so they are not
one pass and must not share a slot — sharing let whichever landed
second cancel the other:

- **Visibility, early** (`scheduleBorderDropReconcile`,
  `.borderDropSettle`). WindowServer can order a ring out with no
  matching unhide; this pass's re-stack of every ring is what
  un-hides it, since a steady `sync` orders only a ring
  `needsOrder` flags (#1925). Landing mid-flight is safe *because* geometry
  stands down above — precisely, and only, for a window **our own
  animation** is driving. It still re-reads state for every other
  ring, exactly as the `updateBorders()` at the end of each
  `retile()` does, and that includes the residual named below: a
  window the user is dragging under a live WindowServer stream is
  not guarded here either.
- **Geometry, late** (`scheduleBorderResync`, `.borderResync`).
  Rides `AnimationEngine.onAllAnimationsEnded`, never a duration
  guess — a spring's visual settle is ~2× its response, so
  `durationMS + 50` lands mid-flight. Then a grace sized to a slow
  app's post-settle catch-up, not to the animation: read sooner
  and it reads bounds the app has not reached yet, which is the
  same backward snap one moment later. This is the heal for a
  window whose app accepted no AX write at all — the ring rode our
  commanded frames to the target while the window never moved, and
  no echo and no WindowServer event is coming.

## The switch path adds no ring round trip beyond its ruled re-stacks

A WindowServer call a ring makes on the main actor waits for its
answer, and while WindowServer is GPU-bound one answer took
390 ms (#1925, 2026-10-03). A re-stack is such a call that a ring
cannot drop (#1962), so a change to the ring's switch path keeps
these:

- **A ring `sync` retires goes dormant, never ordered out** —
  alpha 0, still ordered in, its corner radius kept — and comes
  back for its window, its held frame dropped on retire or an
  animated return flashes it where it rested
  (`BorderDormantRingTests`). Only a window outside `alive`
  (state plus the away ledger; nothing while borders are off)
  drops its ring.
- **The WindowServer request names dormant rings too**, so a
  switch leaves it unchanged (`BorderDormantRingTests` ▸
  `watchRequestSurvivesSwitch`).
- **A steady `sync` orders only a ring `needsOrder` flags** —
  new, revived or hidden — unless no WindowServer stream reports
  its target moving; the two settle passes re-stack every ring
  (`BorderOrderReassertTests`).
- **A ring re-stacks through AppKit's `order(_:relativeTo:)`, and
  only from a ruled trigger** — `sync`'s `ordersOverlay` gate
  (`needsOrder`, a settle pass, no WindowServer stream), the
  WindowServer reorder and unhide events, the unhide's restore of
  visibility, and the dead-end ring. A new caller is a new round
  trip on the switch path and owes its ruling in
  `BorderOrderCensusTests`' `allowed` map; a front-order ring's
  level read is a second one (`levelOf`). The order is AppKit's
  because WindowServer applies no SkyLight order to an AppKit
  panel ([os-private-apis.md](os-private-apis.md), #1962) — that
  it MOVES the ring is `BorderStackingTests` ▸
  `reorderMovesTheRing`, which reads the stack back. This orders
  the AppKit panel and draws nothing: the `.transient` section
  below still binds. A sticky mark stacks under the same rule —
  `sync`'s `ordersOverlay` gate and the reorder events'
  `reassert`, a carry owing its mark a stack — and a new caller of
  its `order()` owes its ruling in the census's mark clause (#2026,
  `BorderOrderCensusTests` ▸ `markOrderSitesAreCensused`,
  `StickyMarkOrderTests`).
- **A ring panel that keeps the ring's size moves through
  `SkyLight.moveWindow`, never AppKit's `setFrame`** — mid-animation
  too, so it takes no room — once WindowServer has its window and
  AppKit has not set its frame in the current main run loop pass
  (`MainRunLoopPass`). `setFrame` ties the move to the next commit
  with a fence, and while another app's window transaction held
  WindowServer up the ring's commit waited ~500 ms on it (#1956);
  a SkyLight move issued in a pass where AppKit set the frame, or
  first ordered the panel in, reaches WindowServer first and is
  overwritten at that pass's commit, while an alpha, level or
  order change in the pass leaves it standing (device-checked
  macOS 27.0.1, 2026-10-05). The first show, a size change and a missing symbol
  take AppKit (`BorderPanelMoveTests`; the move landing is
  `BorderPanelMoveLiveTests`', the seams `BorderPanelSeamTests`').
  **Keep the backend's `placedFrame` the panel's frame of record,
  and read no decision off `panel.frame`**: AppKit's cache follows
  a SkyLight move only once WindowServer's moved event reaches its
  event loop, and a `setFrame` equal to a stale cache is skipped.
  The sticky mark's panel still takes `setFrame` per tick,
  unmeasured on the switch path. **A second panel moved this way
  shares the ring's whole placement** — the frame of record, the
  pass gate, the stamp on the order-in that creates the window —
  never the move alone, which a same-pass `setFrame` or
  `orderFrontRegardless` loses; its move is a closure over
  `BorderManager.movePanel` wired once in Core, not a second
  live seam.
- **An animating ring that changes size moves inside its panel
  rather than resizing it** — a panel resize hands WindowServer a
  fenced transaction the main actor waits on, every frame, GPU
  idle or not (#1937, device 2026-10-03). Every ring writer takes its
  room from the one `BorderManager.room(for:screen:)`: while
  `isAnimating` holds, the ring's screen outset by up to one
  screen plus the widest ring's reach per axis, capped by
  `roomLimit` points and `roomPixelLimit` pixels — so on a
  screen the caps leave whole, a ring parked in the stash corner
  or sliding in from it fits — one that also changes size, or
  moves where the SkyLight move is missing — whose exact-panel
  moves the main actor waited ~500 ms on mid-switch before the
  bullet above (#1956,
  `BorderMovingRoomTests` ▸ `roomHoldsParkedRing`); on a wider
  desk the caps cut first and a parked ring can fall outside.
  The panel takes the room once and the ring's layers move
  inside; a ring outside it takes an exact panel for those
  frames. A live ring's panel returns to the ring's own frame at
  the first render after `isAnimating` ends — the late resync at
  the latest — while a ring retired mid-flight keeps the room,
  alpha 0, until it returns, since shrinking it would put the
  resize back on the switch path (`BorderMovingRoomTests`). A
  room-sized panel spans its screen, so a reader of the front
  windows leaves KiwiDesk's chrome out — every own window but a
  tiled one (`FloatDetection.normalFrames`,
  `BorderMovingRoomTests` ▸ `ownWindowsLeaveFrontFrames`).

The WindowServer `.hide` arm still orders a ring out. A
KiwiDesk Space switch parks windows by moving them, so it raises
no `.hide` (no order-out on the 1↔2 runs' panel polls, macOS 27,
2026-10-03); a minimize, a hidden app or a Desktop switch does,
and those stay off the path above until a measurement says
otherwise.

## After a Space switch the focused ring arrives with its window

The ring leads a focus move inside a Space — there the moving ring
is the cue for where focus went — but after a Space switch it would
sit on an empty spot while a slow app's window catches up (#1959,
owner ruling). So a switch that brings its anchor out of the park
holds that anchor's ring through `BorderManager.holdArrival`,
armed in the one door that knows it, `spaceSwitchRetile`
(`BorderOrderCensusTests` ▸ `arrivalHoldHasOneDoor`); a window
already shown — a focus follow onto a Space a screen shows, a
wake, a restore — keeps its leading ring, and native Desktop
switches never hold (`BorderArrivalWiringTests`). It keeps to
these:

- **The held ring is ordered in dormant and revealed, never
  created late** — `sync` orders it with `revealing: false`, so the
  reveal is an alpha change and costs no round trip. The hold
  lives on the overlay, so NO order shows it — the switch's own
  raise fires a reorder and an unhide, and on the device those
  showed the ring ~300 ms early — only `reveal` or a retire ends
  it (`BorderArrivalTests` ▸ `windowServerOrderKeepsTheHold`).
  Being ordered in, a held ring needs no further order, so a
  steady sync costs it no round trip (`heldRingTakesNoFurtherOrder`).
  A ring already showing (a window travelling with the user) is
  not held, and a hold a burst replaces RELEASES its ring rather
  than showing it.
- **Only the window's own report reveals it**: an AX echo
  (`.axEcho`) or a WindowServer reconcile landing within
  `arrivalTolerance` of the frame the switch sent, which the hold
  KEEPS from its first read: a stale echo from the corner retires
  the commanded frame before the window lands (device,
  2026-10-05). Our own animation ticks are not the window
  arriving. A window that never reports gets its ring at
  `arrivalCap` (`BorderArrivalTests`).
- **Never ahead of the slide's plates lifting**: the hold reads
  `spaceSlide.play?.liftAt` live, since a burst press moves it
  (`BorderArrivalTests` ▸ `liftGatesTheReveal`,
  `BorderArrivalWiringTests` ▸ `holdReadsTheSlidesLift`).
- **The reveal fades through `BarMotion.slideFade`, handed the
  manager's `reduceMotion` read**, so Reduce Motion cuts it in —
  stated, not guarded, as the section on a cue's Reduce Motion
  read below says of every cue. Both `makeTestCore` twins pin the
  hold's clock, timer and that read.

## The overlay panels join every Space

Both overlay panels carry `.canJoinAllSpaces` in their
collection behavior — the bars' recipe, and the reason the
Space Bar spans Desktops. A sticky window the Desktop reach
carries (#1145) changes macOS Desktop under its overlays, and a
single-Desktop panel strands the mark and the ring on the
origin (device-observed 2026-09-01). Keep the flag on any new
overlay panel that follows a window; `StickyOverlaySpanTests`
pins the two that exist.

## The ring draws on the `.transient` panel, never a raw window

**A ring renders through `AppKitBorderOverlay` in both draw
orders, and a new drawing path for a window overlay keeps
`.transient`** (#1917). On macOS 27.0.1 (measured 2026-10-02) a
raw SkyLight window stays composited over the Mission Control
overview at its desktop frame, pinned to its target's Space or
not, with no window call found that hides it; `.transient`
does. Do not bring a private
drawing backend back for a crisper front order —
`BorderMissionControlTests` reds a non-AppKit ring or a panel
without the flag, and whether the flag still hides is a device
check no test can make.

## Never gate an overlay pass on the global animation count

`AnimationEngine.activeCount` is a poor proxy for "is *this*
window moving?", and the per-window predicate (`syncFrame`,
`isAnimating`) is always available. Two concrete reasons:

- A global gate discards a whole pass because of one window,
  stranding every window that did settle.
- The count has an **absorbing state**: an animation that never
  settles keeps the count above zero forever, and the settle
  signal dies with it — see
  [input-and-animation.md](input-and-animation.md), which owns
  that mechanism. Note what this does *not* mean: ungating a
  consumer does not rescue it, because the arming path is behind
  the same signal. The fix belongs in the engine and is there:
  #599 removed the known cause, and #611's watchdog force-settles
  an animation that outlives its age bound rather than letting it
  hold the count above zero for the session
  (`AnimationSettleWatchdogTests`). Netted is not the same as
  impossible, and the absorbing state is still the reason not to
  use the count as a per-window proxy.

This is scoped to using the count as a **proxy**. Waiting on it
for a genuinely global precondition is correct and stays —
`scheduleZOrderRestore` and the deferred focus raise both do,
because a raise issued while any frames are still landing arrives
late on slow apps.

## No echo is suppressed to smooth the settle tail

The untreated case is the post-settle echo that arrives while the
app is still catching up: in principle it pulls the overlay
backward before later echoes walk it forward. Leave it alone.

It did not appear under `KIWIDESK_NO_WS_TRACKING` (the QA lever
that forces the AX-fallback path on a healthy Mac, since the
symptoms are fallback-only) at the default duration, at the
shortest, or with an app frozen across the whole flight and
resumed after settle — the harshest case the mechanism allows,
where its catch-up echoes walked the ring *forward* onto the real
frame. And the guard has a known cost: after an instant
`setFrame` the echo is the only carrier of overlay updates
under AX fallback once the commanded stamp clears
(`onFrameApplied` tees from inside `animation.apply` alone, and
`syncFrame`'s `commanded` lead lasts only until the first
self-echo or the grace, #881), so suppressing it freezes the
ring in a case that works today. Re-open only with a device capture of the
backward pull; if one arrives it is an
`docs/accepted-limitations.md` row before it is a new guard.

Caveat worth keeping: that observation was made *with* the grace
in place, so it partly measures the grace. An app whose catch-up
outlasts it would have the re-sync read a partly-caught-up frame —
the same pull, one step smaller. That is a reason to keep the
grace pinned by its test, not a reason to reopen.

## A cue's animation names its Reduce Motion read at its site

The cues honour the setting, and nothing holds them to it. The
bars next door were routed into one home so a scan could watch
them (#1078, [bars.md](bars.md) ▸ the bars start motion in one
file); the cues were left where they are, deliberately — they
already stand down, so a conversion would remove no defect and
buy churn. What that leaves is an obligation with no guard
behind it, which is exactly why it is written down:

**A cue that starts an animation names its Reduce Motion read at
the site that starts it** — read in the overlay
(`StickyMarkOverlay`, `SizeLimitOverlay`) or handed in as an
argument (the dead-end bump takes one from
`KiwiCore+DeadEndCue`). A new cue that names it in neither place
ships ungated, and no suite in the tree will say so; review is
the whole net.

One thing IS held, and it is narrower than it looks: the three
overlay files that animate today are ruled entries in
`BarMotionSeamTests`' `allowed` map, which scans all of Core —
so a FOURTH file here that starts motion reds until someone
rules it, and a ruling whose file stops animating reds too. What
that map cannot see is a second ungated starter added to one of
the three already in it, which an entry exempts wholesale. So
the obligation above is the net for the inside of those files,
and the map is the net for the next one.

## The sheen is one ramp, painted by the surface that owns the stroke

`border.sheen` (#1644) reaches the focused ring, the shelf's
highlight and border, and the drag borders. **A surface paints it
from `BorderSheen`'s colours** — `SheenRimView` for a view, the
shared `BorderSheen.draw` for a context, a Settings picture
through `SheenPaint` — never a ramp of its own, and reads the
leaf as its only gate: the sheen is not glass, so it takes
neither `LiquidGlassGate` nor the platform floor. **While the ramp paints, the surface clears its flat
stroke or fill**, or a translucent colour stacks twice
(`BorderSheenSurfaceTests`). **The ramp's flat band stays the
configured colour**, which carries #578's contrast; only the ends
move (`BorderSheenFlatBandTests`).

## Every window stroke is the border's

**A stroke KiwiDesk draws around a window takes its width and
corner style from the focus border, and stores none of its
own** (#1742): the drag markers read them through
`TilingSettings.windowStroke`, and a new marker surface reads
the same. Do not re-add a per-stroke width or radius, in the
model, a verb or a look — the split drifted three times, each
fix a fan-out to keep the stores agreeing (#754, #1739), and the
store it drifts in is the defect. `WindowStrokeTests` ▸
`dragVisualStoresNoStroke` pins the stores and
`WindowStrokeTests` ▸ `dragPathsReadTheStroke` the two render
paths. The product
ruling is `docs/design-decisions.md` ▸ One width and one corner
style for every window stroke.

## Exercising the fallback path

`KIWIDESK_NO_WS_TRACKING=<anything>` keeps `skyLightActive` false
for the whole run: the subscription never attaches and never
watches, because a live one keeps feeding `reconcile`, which heals
the very drift the fallback path exists to expose. The startup log
line names the lever, so a QA run cannot mistake it for a real
WindowServer failure. Device QA procedure is in
[tests.md](tests.md).
