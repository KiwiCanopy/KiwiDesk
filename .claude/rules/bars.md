---
paths:
  - "Sources/KiwiDeskCore/Bar/**"
  # The title-refresh gate's driver lives in App/, and it is the
  # exact site where the drawn/announced split has twice been
  # reasoned about wrongly — this file must load there too.
  - "Sources/KiwiDeskCore/App/KiwiCore+BarTitles.swift"
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
