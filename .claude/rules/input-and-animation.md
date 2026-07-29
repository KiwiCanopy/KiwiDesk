---
paths:
  - "Sources/KiwiDeskCore/Keys/**"
  - "Sources/KiwiDeskCore/Events/**"
  - "Sources/KiwiDeskCore/Animation/**"
---

# Input & animation

Canonical for this subsystem (AGENTS.md §5 indexes it). When
editing here:

- Hotkeys use the **Carbon API** (`RegisterEventHotKey`), not
  CGEventTap — this avoids the Input Monitoring permission. Event
  taps are only for mouse drag tracking.
- Use **one `DisplayLink` per monitor** (mixed refresh rates).
  Never drive animations from a single global timer.
- **The spring integrator must stay inside its stability bound
  (#599).** `Spring.step` is semi-implicit Euler, which amplifies
  instead of damping once the step is large relative to the
  spring's response — so a 60 Hz tick diverged for every duration
  below ~80 ms, and the position ran away to infinity. It
  substeps to stay under `maxStableStep`; do not "simplify" that
  loop away. **If you re-derive the bound, use the real
  condition** — `k·h² + 2·c·h < 4`, i.e.
  `ωh < 2(√(1+ζ²) − ζ)` — not either term alone; `k·h² < 4` is
  the undamped special case and `|1 − c·h| < 1` is necessary but
  not sufficient. The shipped `1/max(ω, c)` is conservative
  against that, with a margin never below **1.24×** (its minimum,
  at ζ = 0.5) that approaches 2× only as ζ → 0 or ζ → ∞ — 1.57×
  at the engine's ζ = 0.85 and 1.29× at `DeadEndBump`'s ζ = 0.45.
  So the halving is load-bearing, and removing it at ζ = 0.85 is
  immediately divergent again. Two springs ship (the engine's at
  ζ = 0.85, `DeadEndBump`'s at ζ = 0.45) and they sit on
  opposite sides of which term `max` selects. Substepping rather
  than a duration clamp because there is one `DisplayLink` per
  monitor at mixed rates and a spring outlives a cross-display
  move — 120 Hz was always inside the bound, which is why this
  reproduced on some machines only.
  **Why it mattered far beyond one janky window:** a diverged
  animation never satisfies `settled`, so it never leaves the
  engine, `activeCount` never returns to zero and `notifyIfIdle`
  stops emitting `onAllAnimationsEnded` — killing the deferred
  focus raise, the z-order restore and the overlay re-sync for
  the rest of the session. Anything new that waits on that signal
  inherits the same exposure, so keep the integrator honest
  rather than gating each consumer — and read the next bullet,
  which is the net for whatever gets past it.
- **Force-settle non-convergence rather than waiting it out
  (#611).** The bullet above is the one *known* way to wedge the
  settle signal; the watchdog in `tick` is the net under it, so
  the next one — a pathological Lua-supplied spring, an
  integrator change — costs one window a jump instead of three
  subsystems for a session. Past `max(5s, min(12 × response, 60s))`
  of motion an animation snaps to its target and leaves the engine
  through `FrameAnimation.forceSettle`, the same exit a clean
  settle and the non-finite net take. Keep it one recovery shape:
  that is the shape already proven to release the signal.

  Three things about it are load-bearing, each with its own
  guard — and the inverse is guarded too
  (`healthyMotionNeverTrips`), because a watchdog that fires on
  healthy motion is worse than none:
  - **Both terms of the bound**
    (`bothTermsOfTheBoundBind`). Not for the reason it is
    tempting to give: the floor is *not* slack for a slow-AX
    app, because a blocked app costs wall-clock and ages an
    animation by at most one tick's worth. Measured against the
    worst travel at 30/60/120 Hz
    (`slowestHealthySettleIsPinned`), 50 ms settles in 0.20 s
    and 1000 ms in 2.80 s — so the multiple holds the slow end
    (6.0× there, where the floor has only 1.8×) and the floor
    buys back the fast end's 4.2×, the thinnest margin either
    term has. A ceiling caps the multiple, or a spring built
    with a large response opts out of the watchdog entirely
    (`hugeResponseStillTrips`).
  - **Age is simulated, never wall-clock**
    (`ageIsSimulatedNotWallClock`). `step` accumulates
    `Spring.integratedSpan(dt)`, so a stalled `DisplayLink`
    ages an animation by what it moved rather than by how long
    the display slept. That span deliberately does **not**
    share `Spring.step`'s other refusal (an unusable
    `maxStableStep`): such a spring integrates to a standstill
    without settling, and ageing it anyway is the only reason
    the watchdog can reach it
    (`aFrozenSpringIsStillRescued`).
  - **`retarget` restarts the clock only on a changed target**
    (`retargetResetsAge`, `unchangedRetargetKeepsAgeing`). A
    live make-room drag retargets its siblings for as long as
    the user holds the mouse, so a new target must reset; a
    retile loop re-issuing the *same* placement must not, or it
    blinds the watchdog to the one wedge it could plausibly
    meet in production.

  Two known holes, both accepted rather than overlooked. A storm
  of genuinely *different* targets defers the bound indefinitely
  — indistinguishable from a long drag from inside the engine,
  and the first target a storm stops on ages normally. And the
  watchdog is only as live as the clock it rides: nothing ages
  while a display's `DisplayLink` is stopped, so **never stop a
  driver while animations are still resident on its display** —
  every teardown path drains first, and that is the precondition
  the whole net rests on.

  `DeadEndBump` is deliberately outside this net. It feeds no
  global signal (`BorderBumpAnimator` keeps its own map), its
  input space is closed — clamped impulse, constant target, a
  hardcoded spring `SpringStabilityTests` already pins — and
  `flushAll()` is a real, wired escape hatch. Do not widen the
  engine's watchdog to cover it.

  Report both nets through `AnimationEngine.onLog` (wired in
  `KiwiCore+Bootstrap`, asserted end-to-end by
  `engineLogReachesTheCore` — a seam that is declared and never
  wired logs nothing in production while every unit test that
  sets it by hand stays green). A rescue that fires silently
  removes the symptom that made #599 findable and leaves only a
  visible jump.
- `AnimationEngine.cancelAll(snapToTargets:)` is a **test drain
  primitive**; production has no global cancel by design (`stop()`
  tears down differently on purpose, `displaysChanged()` covers
  the per-display case, `cancel(window:)` the per-window one).
  Read its doc comment before filing it as dead code, and if a
  lifecycle event ever does want it, wire it deliberately and give
  it a test — an untested escape hatch is discovered not to work
  at exactly the moment it is needed.
- Two env levers exist for device QA of this subsystem —
  `KIWIDESK_STRAND_LOG` (logs a window that did not land on its
  settled target, #47) and `KIWIDESK_NO_WS_TRACKING` (forces the
  overlays' AX-fallback path, #596). Both are documented in
  [tests.md](tests.md), which is scoped to `Tests/**` and so does
  not load while you are editing here.
