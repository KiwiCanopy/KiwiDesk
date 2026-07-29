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
  rather than gating each consumer.
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
- Two env levers exist for device QA of this subsystem —
  `KIWIDESK_STRAND_LOG` (logs a window that did not land on its
  settled target, #47) and `KIWIDESK_NO_WS_TRACKING` (forces the
  overlays' AX-fallback path, #596). Both are documented in
  [tests.md](tests.md), which is scoped to `Tests/**` and so does
  not load while you are editing here.
