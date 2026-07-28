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
- Two env levers exist for device QA of this subsystem —
  `KIWIDESK_STRAND_LOG` (logs a window that did not land on its
  settled target, #47) and `KIWIDESK_NO_WS_TRACKING` (forces the
  overlays' AX-fallback path, #596). Both are documented in
  [tests.md](tests.md), which is scoped to `Tests/**` and so does
  not load while you are editing here.
