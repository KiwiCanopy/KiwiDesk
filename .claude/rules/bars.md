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
  beside it. `BarMotionSeamTests` holds that, and it scans ALL
  of `Sources/KiwiDeskCore` rather than the bar paths: a bar
  surface lands wherever it lands — #1229's overview panel is
  the next one — and a guard scoped to the directories bar code
  occupies TODAY cannot see the one that arrives outside them.
  Its `allowed` map is the one copy of who is exempt, and a
  ruling that fires on nothing reds, so an entry cannot outlive
  its site.
- **A member added to `BarMotion` owes a census entry** naming
  the gate its body reaches, and one that starts motion may not
  be censused as starting none. That clause is the fail-shut
  half: the routing clause exempts the home file by design, so
  without it a fourth ungated wrapper is invisible to every test
  in both suites — which is where a hand-listed case list left
  it (guard-prover). Deleting the gate inside a shared helper
  ungates every caller at once while the routing clause stays
  green, which is the failure [gui.md](gui.md) ▸ the Reduce
  Motion gate rejected an abstraction over.
- **A decision takes the flag as an argument**, so it is
  assertable: `BarMotionTests` pins the collapsed group
  duration, the frame write that lands instead of travelling and
  both shapes of the drop ring, and none of them reads the live
  setting. `BarMotion.isReduced` is the one expression a test
  cannot reach, deliberately — it is the whole of what is left.
  **Every entry point takes the same shape** — a `@MainActor`
  wrapper that reads, a pure decision that is handed the answer
  — because a second shape beside it owes the seam suite a
  second clause, and the clause a caller-fed gate needs cannot
  be the one a wrapper-read gate needs.
- **The gate drops the MOTION, never the affordance**, and **a
  DELAY is not motion** — a quiet window before something
  appears survives the gate at its full length, because
  shortening it changes what the affordance MEANS rather than
  how it travels. What a stand-down costs the user is a product
  ruling and not this file's: `docs/design-decisions.md` ▸ the
  bars honour Reduce Motion argues the two that `BarMotion`'s
  decisions implement, and a third is argued there, not here.

## A stored Fill becomes a colour on glass in ONE place

The same shape, one subsystem over, and for the same reason it
was needed there. `GlassTint.apply` clamped the coloured backdrop
to `GlassTint.maxAlpha` while `GlassPlate.update` set
`NSGlassEffectView.tintColor` from the raw Fill beside it — and a
clamp with an unbounded sibling is not a clamp. Every bundled
palette ships a bar fill at `…B3`, so the ungoverned channel ran
at 0.70 on a default install and the plate rendered as a
near-solid slab for as long as the finish shipped (#1297).

Obligations:

- **A glass surface takes its colour from `GlassTint.apply`**,
  which is handed the Fill's **hex** and never an `NSColor`. The
  narrower parameter is the rule, not an accident: while it took
  a colour, a call site could substitute one for the capped one
  and every guard stayed green — the same bypass one level up
  from the one that was being closed. A surface that genuinely
  needs a non-Fill colour on glass earns a second mint inside
  `GlassTint`, never a colour parameter.
- **`GlassPlate` takes no colour at all.** It is geometry. The
  channel it used to drive carries none of a Fill's hue — see
  `docs/design-decisions.md` ▸ Liquid Glass for the measurement —
  so a surface reaching for it is asking for a dimmer while it
  looks like it is asking for a tint.
- **A member added to `GlassTint` owes a census entry** naming
  what its body reaches, and one that paints without routing
  through the clamp may not be censused as routing.
  `GlassTintSeamTests` is the fail-shut half — every other clause
  in it exempts the home file by design, so without the census a
  second unclamped painter inside `GlassTint` is invisible to
  both suites, which is exactly the hole the equivalent
  `BarMotion` clause exists to close.
- **The number is retuned against a ground with STRUCTURE in
  it**, and the argument lives in `GlassTint.maxAlpha`'s
  docstring rather than here (tests.md ▸ #1021). A flat wallpaper
  shows no refraction at any alpha, so it cannot answer the
  question it looks like it is answering; and what actually binds
  the cap is the bar's own ink, which is fixed palette hex with
  no vibrancy path, so the plate is its legibility floor.
- **A `Sources/KiwiDesk` surface that tints glass owes this suite
  a root.** `GlassTintSeamTests` scans Core alone, so the GUI
  tree is not covered by it — a Fill→colour derivation that lands
  there is invisible until someone widens the roots. Note the
  reason to think twice before writing one, which is not a
  capability limit: SwiftUI's `Glass.tint(_:)` **does** work, and
  the near-colourless finding above is AppKit's. What the bars
  lack is a vibrancy path for their ink, which a SwiftUI surface
  drawing `.primary` / `.secondary` over a material has — so the
  argument that forces a tinted fill onto a bar does not reach
  that tree, and a tint there is a design choice needing its own
  ruling rather than an inherited one.
