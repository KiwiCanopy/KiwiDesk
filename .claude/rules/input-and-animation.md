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
  against that, with a margin of 1.24×–1.81×, **not** 2× — so
  the halving is load-bearing, and removing it at ζ = 0.85 is
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
- Two env levers exist for device QA of this subsystem —
  `KIWIDESK_STRAND_LOG` (logs a window that did not land on its
  settled target, #47) and `KIWIDESK_NO_WS_TRACKING` (forces the
  overlays' AX-fallback path, #596). Both are documented in
  [tests.md](tests.md), which is scoped to `Tests/**` and so does
  not load while you are editing here.
