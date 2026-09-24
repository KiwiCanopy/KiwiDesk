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
  # The one shelf (#1517): where a bar field lives, the one
  # reservation, the one placement rule, the retired verbs.
  - "Sources/KiwiDeskCore/App/KiwiCore+Shelf.swift"
  - "Sources/KiwiDeskCore/Layouts/KiwiShelf*.swift"
  - "Sources/KiwiDeskCore/Layouts/Shelf*.swift"
  - "Sources/KiwiDeskCore/Layouts/SpaceBarStyle*.swift"
  - "Sources/KiwiDeskCore/Layouts/AppBarStyle*.swift"
  - "Sources/KiwiDeskCore/Layouts/LayoutAppBar*.swift"
  - "Sources/KiwiDeskCore/Commands/Reference/APIReference+Retired.swift"
---

# Bars (App Bar & Space Bar overlays)

Canonical for this subsystem (AGENTS.md §5 indexes it).

## Both bars sit on ONE KiwiShelf (#1517)

The Space Bar and the App Bar share one screen edge, KiwiShelf
(`TilingSettings.kiwishelf`). Two bars on independent edges each
carved a reservation, and the App Bar's came and went with the
layout, so a layout switch reflowed every window; a field both
bars read, stored twice, was a question the user answered twice.
The argument is `docs/design-decisions.md` ▸ One shelf holds both
bars. Obligations:

- **Store a bar field in exactly one of `KiwiShelf`,
  `SpaceBarStyle` and `AppBarStyle`.** A value both bars must
  agree on — where they hang, the strip's depth and look, the
  item gap, the font size — is the shelf's; a value each bar may
  set for itself is that bar's style, even where both bars spell
  it alike (an indicator, a colour). A shelf field takes **no
  per-layout override**: `LayoutAppBar` mirrors `AppBarStyle`
  and nothing else. `KiwiShelfParityTests` ▸ `looksAreDisjoint`
  reds a name on the shelf and on either style, and
  `AppBarParityTests` ▸ `propertyParity` a `LayoutAppBar` field
  that is not `AppBarStyle`'s; whether a NEW field is shared or
  a bar's own is review's, since no guard can tell.
- **Retire a bar verb by adding it to `APIReference.retired`**,
  naming its replacement or nil, and never by an alias (AGENTS.md
  §5). A field the shelf migration moves joins
  `ConfigMigration.shelfMovedKeys`, which the retired list
  derives its setter spellings from, so a verb and its stored key
  retire together. `KiwiShelfRetiredVerbTests` holds the list:
  ▸ `replacementsAreLive` that every replacement is dispatchable,
  ▸ `retiredAreUnregistered` that no retired name is still
  registered, ▸ `retiredCallIsAnIssue` that `init.lua` reports
  one as its own Config Issue.
- **Reserve the shelf ONCE, through
  `TilingSettings.layoutBounds(from:)`, in every layout while
  `shelfShows`** — never a layout, a bar or a mode carving a
  strip of its own, and never a second "does the shelf show"
  predicate beside `shelfShows`. A per-layout reservation is the
  reflow this section exists to remove. `ShelfGeometryTests` ▸
  `reservesWhileAnyBarShows` and `ShelfDriverTests` ▸
  `layoutSwitchReflowsNothing` hold it; `LayoutBoundsRoutingTests`
  holds the route (#537).
- **Place every bar along the edge through the one
  `ShelfArrangement`** — the live drivers through
  `KiwiCore.shelfPlan`, and the Settings preview and the
  alignment note by asking it too
  (`ShelfArrangement.spaceBarMoves`), never by arithmetic of
  their own: a picture that places the bars by hand can claim a
  placement the engine does not make (gui.md, #702). The Space
  Bar's front-app segment stands down on the same App Bar content
  the plan is built from. `ShelfArrangementTests` holds the rule,
  `ShelfDriverTests` ▸ `bothBarsShareTheStrip` the disjoint
  segments and ▸ `frontAppYieldsToTheAppBar` the stand-down; no
  suite scans the Settings tree for a hand placement, so the GUI
  callers are review's.
- **Refresh both bars through the one `KiwiCore.updateBars()`,
  never a single-bar sync.** It builds each display's plan once
  from both bars' content and syncs both managers from it, so a
  change to either bar's need moves the other in the same pass;
  a path refreshing one bar leaves the other in a segment the
  plan no longer gives it. `ShelfDriverTests` drives the pair
  through it.
- **Keep a bar's `naturalLength` equal to what its render
  draws** — the need the plan hands `ShelfArrangement` restates
  the render's padding, so a change to either side moves both:
  handed a segment exactly that long, the run fits with no arrow
  and its plate reaches the segment's end.
  `ShelfNeedParityTests` holds both bars to it.

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
- **An arm that moves a glass among its siblings ends by calling
  `GlassTint.apply` and never re-orders the backdrop beside it.**
  `apply` repairs the order only where it is wrong: a sibling
  move of the glass — the Space Bar's `spanBackdrop` arm — left a
  backdrop inserted once above it for the rest of the process
  (#1314), and a per-render reparent would be the churn #1315
  names. `GlassTintOrderTests` holds the order through the real
  arm via `SpaceBarManager.sync`, requiring the arm rather than
  trusting the fixture's arithmetic, and holds the no-reparent
  half on a counting parent — AppKit fires no view-level callback
  for a re-add, so only a parent can see one. Residue, stated
  because it fails OPEN: an arm that inserts its own sibling
  DIRECTLY beneath its glass makes the repair fire every render,
  silently; the no-reparent clause is not through the arm.
- **A steady-state bar render reparents nothing into a glass
  subtree.** A view moves only on a host CHANGE, and the arm that
  changes the host is the one that names it — the Space Bar's
  `prepareGlassHosting` creates the hug run and picks the
  segment's host in the same arm, with no fallback — while a
  z-order need is met by the positioned insert at that change,
  never by a per-render re-add: the segment is laid out after the
  last item, so it and the items never overlap (#1315,
  `SpaceBarFrontViewChurnTests`, whose add count is the one
  clause that sees a wrong hug host, since `hugRun` re-hosts any
  stray). A same-parent re-add fires no AppKit hook and is a
  reorder, so a guard against one counts inserts at the PARENT or
  pins subview identity, never a view-side callback (#1314 too).
  The pinned arm's plate move is order-guarded the same way, and
  its ORDER half is `GlassTintOrderTests`' index pin; its
  no-reparent half has no counting clause — stated, fails OPEN.
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
- **The glass's light/dark variant is PINNED from the Fill in
  `GlassTint.apply`, never left to the OS per view.** macOS
  decides a Liquid Glass view's variant from the backdrop that
  view samples and holds the verdict, so two bars sharing a Fill
  diverged with identical KiwiDesk state, and every eyeball
  reading blamed whichever bar was in the dark state (#1308; the
  numbers are in `docs/design-decisions.md` ▸ Liquid Glass). A
  dark Fill pins `.darkAqua`; a light Fill pins nothing, so the
  glass carries `NSApp.appearance`, which the Settings Appearance
  pick writes (#678) — two writers reach one view, and the
  precedence is the Fill's where it is dark and the pick's for
  the rest, ruled in that entry. Only dark can be pinned, and
  that fact is scoped to the ambient it was measured in by
  `GlassTint.pinnedAppearance`'s docstring, never restated here.
  The threshold is `wantsLightInk`'s — one copy with the mark
  glyphs — and `GlassTintPinTests` holds the consumer,
  including that a light Fill LIFTS a pin the previous Fill left.
  Nothing else in Core writes `.appearance =` on a view
  (`GlassTintSeamTests` ▸ one-home clause, allow map empty by
  design); a surface that needs to owes `docs/design-decisions.md`
  an argument first.
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
- **Reduce transparency stands the glass down at the one
  render-time read, and never by moving the stored value**
  (#1374). `NSGlassEffectView` ignores the setting — measured
  2026-09-13, live and at creation — so each overlay's `render`
  resolves its stored style through `LiquidGlassGate.rendered`
  exactly once — glass off AND the Fill at full alpha, since the
  setting asks for opaque backgrounds — and every consumer
  downstream (`glassEnabled`, `hasBox`, `GlassHosting`, the
  plate painters) reads the copy; `GlassTint` refuses a
  colour beneath it as the net, and the observer that re-draws
  BOTH bars on the flip is wired in `start()` and retired in
  `stop()`, its token owned per core and never a static — a
  stopped core draws nothing, and the next core must not inherit
  the last one's observer. A new bar surface's render takes
  the same read — the roster is DERIVED Core-wide from every type
  reaching `GlassHosting.resolve(`, the one hosting decision —
  spelling its stored style nowhere but as the
  gate's argument, and a new reader of the OS flag in Core is a
  second gate free to disagree with the first
  (`ReduceTransparencySeamTests`: one home per tree, one read per
  render on a stored style read once, both bars in the handler,
  every glass fixture pinned; `ReduceTransparencyTests` holds the
  behaviour and the observer's delivery). Why the OFF shape rather
  than an opaque glass is `docs/design-decisions.md` ▸ Reduce
  transparency.

## A Space Bar text glyph is framed through the one `BarTextGlyph.frame`

A label's `cellSize` carries ~8 pt of cell padding around the
advance, so at a thin bar it exceeds the square glyph cell for
every App Font ligature — and `NSTextFieldCell` then draws the
string LEFT-aligned whatever `alignment` says, so a frame the
size of the cell clipped the trailing quarter of the ink at the
thickness floor (#1529). The vertical-centring block that came
with that frame had already been hand-copied once, from the
item's `place` into the front-app segment, which is how both
sites clipped alike.

- **Place a text glyph in a Space Bar cell through
  `BarTextGlyph.frame` and nowhere beside it**: the frame takes
  the label's own width, centred on the cell so the alignment
  holds, shifted so the INK is centred rather than the advance
  (the neighbours are image cells, whose pixels centre; a
  ligature's slack sits on its trailing side), and a glyph whose
  ink would reach past the cell by more than the SLACK its site
  states is scaled to fit — an app cell states none, since its
  neighbour abuts; the identifier states the item's pad, so a
  three-digit id or a monogram keeps the ladder's size and
  reaches into the pad rather than shrinking beside a one-digit
  neighbour. The helper returns unaligned geometry and the site
  rounds ONCE to its backing. A new site owes
  `SpaceBarGlyphCellTests` a clause of its own — the suite pins
  the item's and the front-app segment's fields by rendering
  them, and reads no site list, so a third site that framed by
  hand would stay green there.
- **Anchor a bar text glyph by its INK, through
  `BarTextGlyph.Metrics`' placements, never by its advance or its
  frame** (#1543): centring the advance drew an App Bar glyph a
  sixth of the slot to the left, and snugging the frame's
  trailing edge to the name left the slack between glyph and
  name. The App Bar's icon slot (`AppBarItemView+GlyphSlot`)
  keeps its own font-scaling and `snugToName` rulings and takes
  `originX(centringInkOn:)` / `originX(inkTrailingAt:)` /
  `originX(inkLeadingAt:)`; a badge hangs on `glyphInkFrame`,
  whose x-span is the ink's — the label's frame carries the
  cell's padding on that axis. `AppBarGlyphInkTests` renders both anchors
  and holds their OUTPUT — a hand-copied CoreText read that
  anchored the ink correctly would stay green there, so the
  routing is review's.
