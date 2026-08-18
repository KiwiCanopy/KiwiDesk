---
paths:
  - "Sources/KiwiDeskCore/Borders/**"
  # The settle passes below are driven from App/, not Borders/ —
  # scoping this file to Borders/ alone would mean it never loads
  # for the exact file where someone would re-merge the two keys.
  - "Sources/KiwiDeskCore/App/KiwiCore+Borders.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+Settle.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+StickyMarks.swift"
  - "Sources/KiwiDeskCore/App/DeferredTasks.swift"
---

# Focus ring & sticky mark overlays

Canonical for this subsystem (AGENTS.md §5 indexes it). Two
overlay families — the focus ring (#278) and the sticky mark
(#414) — track the same windows through the channels the
table below lists,
so they share their decisions rather than mirroring them.

The *product* rulings about these overlays (who gets a ring, why
glow forces the AppKit renderer, why a fullscreen window gets
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
| `follow(.animationTick)` | always applies — it *is* the truth. One correction (#677): when the animation's target re-asks a size the app has twice refused, the tick renders the commanded origin at the learned answer (`FollowSource.SizePin`, computed by `TilingEngine.animationSizePin`), because the window performs our position sets and refuses the size — `FollowSizePinTests` |
| `follow(.axEcho)` | stands down (#594), and also while WindowServer-tracked (#285) |
| `reconcile` (WS bounds re-read) | stands down (#594) |
| `sync` (`updateBorders()` / `updateStickyMarks()`) | geometry stands down (#596); create, recolor, re-order and retire still run |

`sync` is the easy one to miss, because it reads as a rebuild
rather than a move — its frame is `state.windows[id]?.frame`,
written only by AX echoes, so a retile burst or focus change
landing mid-flight snapped the overlay back to the pre-motion
frame (~31 pt on device) until the next tick dragged it forward.

Whatever holds the frame must also resolve **`screen` from the
same rect**: it selects the backing scale, so a held frame paired
with the spec's screen rasterizes the ring at the wrong display's
scale during a cross-display move.

## Two settle passes, two deferred keys

They do different jobs and want opposite timing, so they are not
one pass and must not share a slot — sharing let whichever landed
second cancel the other:

- **Visibility, early** (`scheduleBorderDropReconcile`,
  `.borderDropSettle`). WindowServer can order a ring out with no
  matching unhide; `sync`'s trailing `order(relativeTo:)` is what
  un-hides it. Landing mid-flight is safe *because* geometry
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
`setFrame` the echo is the **only** carrier of overlay updates
under AX fallback (`onFrameApplied` tees from inside
`animation.apply` alone), so suppressing it freezes the ring in a
case that works today. Re-open only with a device capture of the
backward pull; if one arrives it is an
`docs/accepted-limitations.md` row before it is a new guard.

Caveat worth keeping: that observation was made *with* the grace
in place, so it partly measures the grace. An app whose catch-up
outlasts it would have the re-sync read a partly-caught-up frame —
the same pull, one step smaller. That is a reason to keep the
grace pinned by its test, not a reason to reopen.

## Exercising the fallback path

`KIWIDESK_NO_WS_TRACKING=<anything>` keeps `skyLightActive` false
for the whole run: the subscription never attaches and never
watches, because a live one keeps feeding `reconcile`, which heals
the very drift the fallback path exists to expose. The startup log
line names the lever, so a QA run cannot mistake it for a real
WindowServer failure. Device QA procedure is in
[tests.md](tests.md).
