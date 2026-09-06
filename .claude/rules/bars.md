---
paths:
  - "Sources/KiwiDeskCore/Bar/**"
  # The title-refresh gate's driver lives in App/, and it is the
  # exact site where the drawn/announced split has twice been
  # reasoned about wrongly — this file must load there too.
  - "Sources/KiwiDeskCore/App/KiwiCore+BarTitles.swift"
  # Both bars are built per display, and each reads the focus
  # for itself — #1214 shipped that reading wrong twice, in the
  # drivers and in the item builders they call.
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

## A per-display bar answers the SHOWN question, never the render one

A bar is built per display, so a per-display value sits in easy
reach of every derivation inside it. #1214 reached for one: the
Space Bar handed each screen's own shown Space into #445's render
verdict as if it were the focused one, and every screen's bar was
told a ∞ window rendered there while the layout drew it on one.
The `+n` badge's focus tint beside it was the same substitution a
second time.

The presence half is no longer policed here at all: the
derived-verdict obligation in
[state-and-layout.md](state-and-layout.md) owns it (#1225), and
this file would only be a second copy to rot. What is left is the
reading a bar still makes for itself:

- **A bar derivation reads `state.windows`, never the away
  ledger** (#1228). The bar draws the Desktop in front of the
  user: a window KiwiDesk parked is its to draw, a window macOS
  is showing on another Desktop is not. The obligation and its
  two residues are
  [state-and-layout.md](state-and-layout.md)'s — this line
  exists because that file does not load when you edit
  `Bar/**`, and the next new bar surface (#1229's overview
  panel) is written here.
- A bar derivation answering *which window holds the SYSTEM
  focus* — the glyph tint, the `+n` badge's — reads
  `workspaces.lastFocused` and gates on the active Space, never
  on the display's own shown one and never on a Space's
  remembered `focused` slot. Those diverge on an injected ∞
  traveler, which holds `lastFocused` and can never be the
  membership-guarded `space.focused` (#431), and that is the one
  case the `+n` tint exists for.
- `currentSpace(on:)` answers *which Space is this screen
  showing*: the item that draws as active, the Space a bar is
  BUILT for, chrome coverage. It is a bare alias of
  `activeSpace(on:)`, so a new read states which of the two
  questions it means in a word beside the call — they are one
  token apart and read identically at a glance.
- `SpaceBarStickyScreenTests` pins the two-screen half from the
  driver: the ∞ arm on both sides of a switch, the 📌 arm that
  refuses the over-broad "prune every sticky off an unfocused
  screen" fix, and the `+n` tint — which on 2026-09-02 was the
  only test in the tree that redded when that gate was reverted.
  The single-screen suites
  stay blind to all three by construction, which is why they are
  their own file rather than added expectations.

## The bars start motion in one file, and that file gates it

A bar animation is gated on Reduce Motion, and `BarMotion` is
where every one of them lives (#1078). `Sources/KiwiDesk`'s gate
is spelled per call, in the argument, because a SwiftUI
animation carries one to name; an AppKit frame write does not
(`view.animator().frame = f` takes no animation argument at
all), so the bars take the other shape tests.md sanctions — one
home, routed through the seam, applied exactly once.

Obligations:

- **A new bar surface animates through `BarMotion`**, never
  beside it. `BarMotionSeamTests` holds that: the
  motion-starting AppKit and Core Animation spellings appear
  under `Bar/` only in `BarMotion.swift`, its `allowed` map is
  the one copy of who is exempt, and a second clause holds the
  wrappers to consulting their own decisions — deleting the gate
  inside a shared helper ungates every caller at once while the
  routing clause stays green, which is the failure
  [gui.md](gui.md) ▸ the Reduce Motion gate rejected an
  abstraction over.
- **A decision takes the flag as an argument**, so it is
  assertable: `BarMotionTests` pins the collapsed group
  duration, the frame write that lands instead of travelling and
  both shapes of the drop ring, and none of them reads the live
  setting. `BarMotion.isReduced` is the one expression a test
  cannot reach, deliberately — it is the whole of what is left.
- **The gate drops the MOTION, never the affordance.** The two
  rulings that shape cost, both in `docs/design-decisions.md` ▸
  the bars honour Reduce Motion: an item run LANDS in its new
  frames rather than sliding to them, and the Space Bar's
  pending-spring ring MARKS its item — it keeps the quiet
  pre-delay, which is a delay and not motion, then appears whole
  for the rest of the dwell, losing only the countdown.
