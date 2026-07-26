---
paths:
  - "Sources/KiwiDeskCore/State/**"
  - "Sources/KiwiDeskCore/Tiling/**"
  - "Sources/KiwiDeskCore/Layouts/**"
  - "Sources/KiwiDeskCore/Commands/**"
---

# State, tiling & layout

See AGENTS.md §1 and §5 for full rationale. When editing here:

- Windows live in a **flat `[WindowID]` array per space**. Do not
  introduce tree or container structures into state or layout code.
- Layout algorithms are **pure functions** over that flat array —
  keep them actor-free and unit-testable; no AX or AppKit calls.
- Display **bounds** reach layout only through
  `TilingEngine.visibleBounds` (#531) — layout slots, track
  capacity and the resize spans in `Commands/` all read it, never
  `GeometryUtils.axVisibleFrame` directly. A direct call
  re-imports the host's real screen, which is what made identical
  code build different arrangements on a dev Mac and a CI runner
  (#523). `VisibleBoundsRoutingTests` scans these directories and
  fails on an unlisted direct call; the allowlist there names the
  four files legitimately outside the hook, and why.
- Space identifiers are **strings** and case-sensitive; numeric
  strings and integers are equivalent (`"1"` == `1`).

`Commands/**` is in scope because command dispatch resolves the
same geometry the layout does (the resize spans). The bounds,
flat-array and space-id rules apply there as written; the
**pure-function** rule does not — `Commands/` is `@MainActor`
and legitimately calls AppKit. That rule stays scoped to
`Layouts/`.
