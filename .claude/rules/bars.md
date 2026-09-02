---
paths:
  - "Sources/KiwiDeskCore/Bar/**"
  # The title-refresh gate's driver lives in App/, and it is the
  # exact site where the drawn/announced split has twice been
  # reasoned about wrongly — this file must load there too.
  - "Sources/KiwiDeskCore/App/KiwiCore+BarTitles.swift"
  # Both bars are built per display, and that is where #1214
  # substituted each screen's own shown Space for the focused
  # one — the two drivers and the item builders they call must
  # load this file too.
  - "Sources/KiwiDeskCore/App/KiwiCore+SpaceBar.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+SpaceBarItems.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+AppBar.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+AppBarGroups.swift"
---

# Bars (App Bar & Space Bar overlays)

Canonical for this subsystem (AGENTS.md §5 indexes it).

## A bar item's title is SHOWN on two channels: drawn and announced

A `count == 1` item resolves its window title into `item.text`
whatever the content style, and the item view builds its
accessibility label from that text unconditionally — so an
icon-only or vertical bar ANNOUNCES the title it does not draw,
and **a title that is announced stale is as wrong as one drawn
stale**. Any consumer reasoning "content draws no text ⇒ the
title is not consumed" re-opens this defect; the class has now
been review-caught three times (Space Bar 2026-08-20, App Bar
#937, and the Settings title-cap grey-out in #937's review
round).

Obligations:

- A gate standing a title consumer down asks "does the title
  reach EITHER channel", never `showsText` alone. The refresh
  gates (`AppBarManager.showsTitle(of:)`,
  `SpaceBarManager.showsTitle(of:)`) are the worked cases —
  `BarTitleRefreshTests` pins the arm under icon content, and
  `AppBarAccessibilityTests` /
  `BarTitleRefreshOutputTests` pin the announce channel and the
  rebuilt text under `.icon`, so a downstream re-derivation of
  the retired gate reds one of those three, not zero.
- The one place the two channels legitimately diverge is a
  collapsed group (`count > 1`): it draws AND announces its app
  name, never a member's title (`KiwiCore.barItemText`,
  `AppBarItemView.updateAccessibilityLabel`), so a member
  rename is not a title consumption on either channel —
  `BarTitleRefreshTests` pins that at two group sizes.
- Per-title-change cost is bounded by the refresh pipeline's own
  debounce (`KiwiCore+BarTitles`), never by consumers
  pre-filtering on content — the old `showsText` gate was that
  pre-filter, and it is what dropped the announced channel.

## A per-display bar asks the RENDER question with the one active Space

A bar is built per display, so a per-display value sits in easy
reach of every derivation inside it — and the sticky presence
question is not one of them. #445 answers "which Space does this
sticky window render on" from the FOCUSED Space, so handing a bar
its own shown Space in as if it were focused tells every screen at
once that a ∞ window renders there: the Space Bar listed one under
the current Space of both screens while the layout drew it on one
(#1214, and the retired `isCurrent` flag is what spelled the lie).

Obligations:

- A bar derivation answering *which windows are present*, or
  *which one holds the SYSTEM focus* — the glyph strip's members,
  a focus anchor, a traveler injection, the `+n` badge's tint —
  passes `activeSpace?.id`, never `currentSpace(on:)` and never a
  per-item flag standing in for it. Nothing scans for a fresh
  per-display substitution, so each new derivation owes the
  routing deliberately.
- `currentSpace(on:)` is not retired and must not be: it answers
  *which Space is this screen showing*, which is the right
  question for the item that draws as active, for the space a
  bar is BUILT for, and for chrome coverage. So a new read of it
  **states which of the two questions it is answering**, in a
  word beside the call — the two are one token apart and read
  identically at a glance, which is how #1214 shipped and how
  the `+n` tint beside it shipped a second time.
- `SpaceBarStickyScreenTests` pins the two-screen half from the
  driver: the ∞ arm on both sides of a switch, the 📌 arm that
  refuses the over-broad "prune every sticky off an unfocused
  screen" fix, and the `+n` tint. The single-screen suites stay
  blind to all three by construction — one display makes the
  shown Space and the active Space the same value — which is why
  these are their own file rather than added expectations.
