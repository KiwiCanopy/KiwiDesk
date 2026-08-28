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
- **KiwiDesk's own windows are discriminated per WINDOW, never
  per process (#678 item 18).** `shouldForceFloat`'s own-process
  arm reads the tiling mark
  (`OwnWindowTiling.identifier`, through the
  `ownWindowIdentifier` seam) rather than floating everything
  the app itself opened: the Settings window tiles, and the
  tour and the Config Issues window do not. So **never widen
  that arm back to a bare `isOwnProcess(pid)`** — the two
  windows the mark separates want opposite fates, and the
  polarity is what keeps the failure cheap: an own window is
  chrome unless marked, so forgetting the mark costs a stray
  float, never a chrome window taking a layout slot. The
  census of which own window is which lives on
  `OwnWindowTiling` — cite it, do not re-list it, since a new
  own window falsifies every copy and reds none of them.
  Two guards, reading different halves:
  `SelfWindowExclusionTests.forceFloatConsultsTheMark` injects
  the seam and pins that the verdict follows it (the flag is
  otherwise unobservable, so a call site that stops consulting
  it reds nowhere else), and `OwnWindowTilingSeamTests`' map is
  the one copy of who may stamp the mark. The product argument
  is in `docs/design-decisions.md`; the GUI half of it, in
  [gui.md](gui.md).
- **A held resize chord repeats through one tally, one refusal
  funnel and one release channel (#1056).** Three obligations,
  each with the same failure mode — the feature silently stops
  meaning what it claims while every fake-driven suite stays
  green — and one guard suite, `HoldRepeatSeamTests`:
  - Every command a hotkey fire runs reaches the repeat engine
    through the ONE `KiwiCore.execute` wrapper. Eligibility is
    "what the press DID", so a second `dispatchCommand` caller
    runs commands the tally never sees; the suite pins the
    single call site.
  - A new size-limit refusal cue routes through
    `cueResizeRefusal` (`KiwiCore+SizeLimitPill.swift`) — the
    funnel is what ends a held run, so a cue beside it pills
    once per TICK instead of once per hold. The suite holds
    every `refuse*` function to the funnel and the funnel as
    the one `borders.onResizeRefusal` caller.
  - The engine arms only when its registrar conforms to
    `HotkeyReleaseReporting` — a repeat with no stop channel
    must never start — so a wrapper or replacement registrar
    that drops the conformance turns the feature off with no
    red anywhere else; the suite pins the production default's
    conformance. A run is additionally bounded by
    `HoldRepeat.maxRunSeconds` against a lost release event —
    the #611 force-settle shape, reported through the
    manager's log seam, never silent (the overrun-to-log
    wiring is pinned by `HoldRepeatWiringTests`, since the
    seam defaults silent and every machine harness assigns it
    by hand).

  The product rulings (resize-only, the tally, acceleration)
  are argued in `docs/design-decisions.md` ▸ "A held resize
  chord repeats"; widen `HoldRepeat.repeatableCommands` only
  with a ruling of that shape, and the set's members must name
  real commands (the suite derives them from the API census, so
  a §5 verb rename reds there).
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
  against that for every ζ > 0, and **its margin — including the
  minimum, where that minimum sits, and the two shipped springs'
  values — is computed and asserted by
  `SpringStabilityMarginTests`**, which also proves the halving
  is load-bearing by showing the looser `2/max(ω, c)` lands
  outside the bound at the damping the engine ships. Read the
  numbers there rather than from this paragraph. What the numbers
  are *for*: the engine's spring and `DeadEndBump`'s sit on
  opposite sides of which term `max` selects, so neither can
  stand in for the other. Substepping rather
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
  rather than gating each consumer — and read the #611 bullet
  below, which is the net for whatever gets past it.
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
  guard — and the inverse is guarded twice, because a watchdog
  that fires on healthy motion is worse than none:
  `healthyMotionNeverTrips` sweeps the real `animate` path, and
  `slowestHealthySettleIsPinned` covers the same ground with no
  `NSScreen` — the first returns vacuously on a headless host,
  so the second is what keeps the inverse guarded there:
  - **Both terms of the bound**
    (`bothTermsOfTheBoundBind`). Not for the reason it is
    tempting to give: the floor is *not* slack for a slow-AX
    app, because a blocked app costs wall-clock and ages an
    animation by at most one tick's worth. It is a margin
    argument — each term is the thin one at the end the other
    covers, so keeping both is what holds the worst case clear
    of the slowest healthy settle. Neither term alone would fire
    on today's measurements, so this is headroom against a
    future change to the clamp, the mapping or the integrator
    rather than a live fix. **The ratios are computed and
    asserted by `slowestHealthySettleIsPinned`** — do not
    transcribe them back into this file. A ceiling caps the
    multiple, or a spring built with a large response opts out
    of the watchdog entirely (`hugeResponseStillTrips`).
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
  which sees one retarget and no history, and the first target a
  storm stops on ages normally. Do not answer it with a second,
  non-resetting accumulator: it cannot tell a storm from a long
  drag either, so it only relocates the threshold and buys a
  false snap during the interaction the reset exists to protect.
  If it ever needs a real fix, that belongs at the retile path,
  which can see retiles per unit time. And the
  watchdog is only as live as the clock it rides: nothing ages
  while a display's `DisplayLink` is stopped, so **never stop a
  driver while animations are still resident on its display** —
  that is the precondition the whole net rests on. Stated as an
  obligation on purpose: "every teardown path drains first" is
  true today and nothing keeps it true, so it is the caller's
  job to hold, not a fact to rely on.

  `DeadEndBump` is deliberately outside this net. It feeds no
  global signal (`BorderBumpAnimator` keeps its own map), its
  input space is closed — clamped impulse, constant target, a
  hardcoded spring `SpringStabilityTests` already pins — and
  `flushAll()` is a real, wired escape hatch. Do not widen the
  engine's watchdog to cover it.

  Report both nets through `AnimationEngine.onLog` (wired in
  `KiwiCore+Bootstrap`, asserted end-to-end by
  `AnimationNetLoggingTests`, in `engineLogReachesTheCore` — a
  seam declared and never wired bypasses the sink in production
  while every unit test that sets it by hand stays green). A rescue
  that fires silently removes the symptom that made #599
  findable and leaves only a visible jump.
- **A shrinking axis snaps to target on frame 1 unless the
  caller promised `BatchSizing.allSpringSized` (#593), and that
  promise is opt-in, never inferred.** The full argument — why
  the discriminator is "does this pass place any window at its
  final size in one frame" rather than "is this a resize", and
  why the default has to be the pessimistic one — is the doc
  comment on `BatchSizing` itself, which is where a caller
  reaches it. Do not restate **the discriminator argument or the
  default's asymmetry** here or at a call site — that is the part
  which was three prose copies once. Site-specific eligibility
  reasoning (why *this* pass may or may not promise) belongs at
  the site, because it is not in the type.
  Two things worth knowing before you edit this directory:
  a promise is **enforced**, not trusted, at
  `TilingEngine.retile` (a pass carrying `newlyCreatedWindow`
  is forced back to `.mayInstantSize` whatever it asked for),
  and entering `.allSpringSized` from `.mayInstantSize`
  mid-flight must go through `FrameAnimation.reseatSize` —
  a structural shrink renders its target from frame 1 while the
  size springs keep travelling, so the spring is not a claim
  about the window until it is re-seated.
- `AnimationEngine.cancelAll(snapToTargets:)` is a **test drain
  primitive**; production has no global cancel by design (`stop()`
  tears down differently on purpose, `displaysChanged()` covers
  the per-display case, `cancel(window:)` the per-window one).
  Read its doc comment before filing it as dead code, and if a
  lifecycle event ever does want it, wire it deliberately and give
  it a test — an untested escape hatch is discovered not to work
  at exactly the moment it is needed.
- **A press on one of our own windows is recorded per WINDOW,
  and records the press only (#953).** A **global** monitor
  never sees an event routed to our own windows, which left the
  one tiled own window with no recorded press to classify its
  gesture by — so `isResizeGesture`'s trailing-event branch and
  the resize-vs-move ghost gate both went blind on it while
  working for every other app. `MouseTracker`'s local arm closes
  that, under two obligations:
  - **Gate the recorded press on `OwnWindowTiling.identifier`**,
    read from the pressed window
    (`OwnPressMonitorSeamTests`, and
    `OwnWindowGestureDeliveryTests` for the decision itself).
    This is #678 item 18's per-window discrimination, not an
    exemption from it: the bars' item views take `mouseDown`, so
    do the tour, Config Issues and every `NSOpenPanel`, and only
    the marked window can be in a TILED gesture — an ungated arm
    lets a click aimed at chrome overwrite the one press slot
    the classifiers read.
  - **Close a press only from the arm that opened it**, which is
    `Press.Origin`, never the release event's own window
    (`OwnWindowGestureDeliveryTests`). `press` outlives every
    gesture — only `stop()` clears it — so an ungated release
    re-stamps `upAt` on whatever press is still sitting there,
    and once the down half discriminates that means a click on
    chrome refreshing a third-party press recorded minutes
    earlier, which `isResizeGesture` then reads as a gesture
    that just ended. Fail-closed is the safe direction here and
    the reasoning is easy to invert: the classifier reads the
    press only through `guard let up = press.upAt`, so a press
    left open is INERT while one closed by the wrong arm is
    acted on. Provenance also survives an up delivered with no
    window at the end of a frame-resize tracking loop, which a
    mark-gated release would drop.
  - **Fire `onLeftMouseDown` for a `.otherApp` press alone**
    (`OwnWindowGestureDeliveryTests`; `OwnPressMonitorSeamTests`
    is the net beside it, holding the gate to one call site).
    Argue the stand-down from the press's own origin rather
    than from which arm called — that fan-out's consumers are
    built ON the blindness — `followDisplayUnderClick` takes its
    bar-overlay exemption from it (#446), and `lastLeftClick` is
    the click provenance the sibling distrust and the
    ignored-panel escape read (#496, #687, #951). Widening the
    fan-out is a ruling of its own, not a side effect of making
    a gesture classifiable.

  The delivery half of the same defect — why our own window's
  gesture was not observed at all — is
  [accessibility.md](accessibility.md)'s, because it constrains
  a file under `AX/` that this rule's `paths:` do not reach.

- Env levers for device QA of this subsystem are **listed and
  explained in [tests.md](tests.md)**, which owns that table.
  Named here only because that file is scoped to `Tests/**` and
  so will not load while you are editing this directory. One
  thing from it is repeated because it changes what you are
  looking at rather than merely adding output:
  **`KIWIDESK_NO_WS_TRACKING` kills a production fast path**,
  forcing the overlays onto their AX fallback for the whole run
  (#596). `KIWIDESK_STRAND_LOG` is inert by comparison — it only
  logs (#47).
