---
paths:
  - "Sources/KiwiDeskCore/State/**"
  - "Sources/KiwiDeskCore/Tiling/**"
  - "Sources/KiwiDeskCore/Layouts/**"
  - "Sources/KiwiDeskCore/Commands/**"
  - "Sources/KiwiDeskCore/App/**"
  - "Sources/KiwiDeskCore/Tabs/**"
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
