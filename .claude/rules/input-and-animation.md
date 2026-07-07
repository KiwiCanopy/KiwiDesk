---
paths:
  - "Sources/KiwiDeskCore/Keys/**"
  - "Sources/KiwiDeskCore/Events/**"
  - "Sources/KiwiDeskCore/Animation/**"
---

# Input & animation

See AGENTS.md §5 for full rationale. When editing here:

- Hotkeys use the **Carbon API** (`RegisterEventHotKey`), not
  CGEventTap — this avoids the Input Monitoring permission. Event
  taps are only for mouse drag tracking.
- Use **one `DisplayLink` per monitor** (mixed refresh rates).
  Never drive animations from a single global timer.
