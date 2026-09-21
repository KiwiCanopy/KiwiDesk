---
paths:
  - "Sources/KiwiDeskCore/State/**"
  - "Sources/KiwiDeskCore/Tiling/**"
  - "Sources/KiwiDeskCore/Layouts/**"
  - "Sources/KiwiDeskCore/Commands/**"
  - "Sources/KiwiDeskCore/App/**"
  - "Sources/KiwiDeskCore/Tabs/**"
  # `Space` and the values it holds live in Models, so the
  # flat-array rule and the per-space session state below govern
  # an editor there. parity-tests.md and config-vocabulary.md
  # glob it too — they own the mirror and the naming halves,
  # this one owns the shape.
  - "Sources/KiwiDeskCore/Models/**"
---

# State, tiling & layout

Canonical for this subsystem (AGENTS.md §1 and §5 index it). When
editing here:

- Windows live in a **flat `[WindowID]` array per space**. Do not
  introduce tree or container structures into state or layout code.
- **Never store which Space a window holds PER DESKTOP; do store
  it per PROFILE (#1230).** The two look alike and are
  opposites, and the discriminator is **when the record is
  authoritative**, not who owns the fact. A window's Desktop is
  read from the compositor continuously, so a copy is read while
  the thing it copies is still moving and every disagreement
  loses or duplicates a window. A profile's partitioning is
  written as that profile goes inactive and read as it comes
  back, so the store and live truth are never both authoritative
  and cannot disagree.
  The weaker form of this — "KiwiDesk's own fact versus the
  WindowServer's" — does NOT hold and must not be restated: the
  away ledger's `AwayWindow.nativeSpace` is a stored copy of a
  WindowServer fact, admitted because a census reconciles it
  continuously. That is the one such WINDOW→Desktop ledger; a
  second owes the same reconciliation and the argument for why it
  needs to exist at all. (`lastDisplaySpaces` copies a compositor
  reading too, and is re-read each switch rather than
  reconciled.) `ProfileSpacesSeamTests` pins one door per axis,
  and pins every `[DesktopKey: …]` map in `KiwiDeskCore` against
  a named register so a new one has to argue for itself — the
  GUI's own binding rows are outside that scan;
  `KiwiCore+DesktopSpaces.swift` carries the argument.
- **Ask `ProfileManager.currentName` for which profile that
  store is filing FOR**, rather than reading or adding a second
  answer beside it. The obligations that fall on moving that name
  are [profiles.md](profiles.md) ▸ "Whose arrangement is live",
  which is where they load: this file's `paths:` do not reach
  `Sources/KiwiDeskCore/Profiles/**`, where every toucher lives.
- **A profile's record beats where a window departed from
  (#1248).** The remembered Space answers ONCE across every
  profile, so for a window not in state the two authorities
  disagree and the ledger wins by default — the same window then
  landing in a different Space depending on whether it happened
  to be on another Desktop at switch time, which the user cannot
  see and did not choose. A profile becoming live therefore
  re-files an absent window it has a record for, through the one
  `StateCoordinator.refileAway`; a window the profile has never
  seen keeps its memory, matching the live half's "stays where
  the prune put it". **Re-filing to the Space a window is ALREADY
  remembered in is refused rather than a no-op** — the #1207
  return rank goes with the move, so a redirect that changes
  nothing spends the slot and the window comes back last after
  any switch (`AwayProfileSpaceTests`).
- It follows that **a new per-`Space` field is keyed by
  `WindowID` or it is SHARED across Desktops** — the Desktop
  partition is emergent from window residence, and a per-window
  record partitions by Desktop for free. Do not restate which
  fields are which — here or in a docstring — since that list is
  true the day it is written and silently false after (#614);
  read `Models/SpaceModel.swift`'s stored properties, the only
  statement of it that cannot disagree with itself.
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
- A retile may **promise** that every window it touches is
  spring-sized (`BatchSizing.allSpringSized`, #593), which lets a
  shrinking pane slide its shared edge instead of snapping. The
  promise is false for any pass that opens, closes or re-slots a
  window — that reintroduces #45 — so it is opt-in and
  allow-listed by `BatchSizingRoutingTests`. The argument lives
  on `BatchSizing`; it is named here because every site that can
  break it is in `Commands/`, `Tiling/` or `App/`, while the
  subsystem rule that owns it
  ([input-and-animation.md](input-and-animation.md)) only loads
  under `Animation/`.
- The **create fold's spawn grant** — the focus a fresh window
  gets for existing, not one macOS reported — consults
  `ManagedWindow.isTransientOverlay`
  first, and asks **state** rather than the incoming snapshot,
  because the create fold clears the flag when a remembered-tiled
  restore heals the window. A popup that surfaces as an AX window
  collected the whole apparatus of being focused, dismissal
  handoff included, from a grant nobody asked for (#671).
  Weigh the reach before widening this to a slot-wide rule: the
  same flag covers layer-0 dialogs and panels, which `#300`
  ruled behave correctly and want their focus, so barring them
  from the slot would put every focused command on the window
  behind the one being typed in.
  `TransientOverlayFocusTests` pins both arms; the product
  argument lives in `docs/design-decisions.md`.
- **A window that lands on another screen takes THAT screen's
  space, through the one shared predicate** (#1010):
  `StateCoordinator.screenHome(of:leaving:landingOn:)`. Two
  call sites ask it about the same defect, and **each must gate
  itself so that exactly one answers a given move**: the create
  fold answers only for a departure it WATCHED (never a
  `.restored` filing), and `moveToDesktop` only for a Desktop
  its screen is ALREADY showing (`target.isCurrent`), which is
  the case that produces no departure at all. Answering a hidden
  target in the verb as well is not redundant but WRONG — the
  destination would be the space that screen shows now, while
  the reveal can activate a different one, and the reap would
  then remember the window on the arrival's own display and
  stand the fold's rule down. A third site that needs "which
  space does that screen show for a window landing on it" joins
  the predicate rather than re-deriving it; the stand-downs —
  float, sticky, same display, nothing shown — live on it,
  once. The product ruling is `docs/design-decisions.md`'s.
- **Resolve the arriving frame's screen ABOVE the pure core,
  and let the fold decide from it** (#1010). `KiwiCore.handle`
  writes `StateCoordinator.arrivalDisplay` inside the
  `.windowCreated` arm and BEFORE `state.apply`, which consumes
  it; the decision itself stays in the fold, on pure state. A
  frame is AX coordinates (y grows DOWN) while `Display.frame`
  is AppKit's (y grows UP), so comparing them inside this
  actor-free core is silently wrong on exactly the topology
  that needs the rule — a second screen at a negative y.
  `TilingEngine.screen(containing:)` resolves the pair
  correctly, over `GeometryUtils.axVisibleFrame(of:)`, which
  owns the flip. Re-home through `workspaces.add` — the fold's
  own, or `addFocusedToSpace` at the command altitude — never
  `moveWindow(_:to:follow:)`: it fires a focus hand-off, the
  move latch and the #446 wallpaper focus yield, and both
  callers have already chosen their own focus policy.
  A command-altitude re-home also owes what `moveWindow` owes:
  the destination's focus stamp (#22 — `workspaces.add` nils
  `lastFocused` and hands the origin's `focused` to a
  successor) and a retile of its own, since the branch it rides
  may stand down without one. `ArrivalScreenHomeTests` and
  `ScreenHomePredicateTests` pin the rule and each stand-down;
  the two production wirings reach no unit test and are pinned
  by `ArrivalDisplayWiringTests` and
  `DesktopMoveRehomeWiringTests`.
- **An explicit `space:` on a Desktop move is a PENDING
  assignment, paid at the DEPARTURE (#1150)** — never an eager
  membership write for a hidden target, which the reveal
  reconcile would fight (#890's arrival ruling). The command
  records the name (`PendingSpaceAssignment`), the gone handler
  claims it and re-files the departure the fold just recorded
  (`StateCoordinator.redirectDeparture`, which also drops the
  #1207 slot rank, meaningful only in the Space it was taken
  in), and the arrival's remembered-space rule pays it; a
  Desktop its screen ALREADY shows files NOW through
  `addFocusedToSpace`, on the same `isCurrent` gate the #1010
  re-home splits on, and the explicit name outranks that
  re-home. A Space assigned to another screen than the
  Desktop's is REFUSED at the parse — the layout would carry
  the window back (#1010) — and a Space no screen owns yet is
  accepted on ONE screen only: with more it has no settled
  screen (the layout falls back to the key window's, the
  placement resolve to the menu bar's — two readings, and
  #1150's review found them disagreeing), so it is refused with
  the pin hint, never hand-assigned, because the next
  `resolveSpaceDisplays` would move it back and re-open the same
  undo. Carry the screen a Space lands on ON the resolution
  (`SpaceTargetResolution.space(_:landing:)`) and hand it to the
  sticky gate as `landingOn` — the gate reads a nil assignment
  as "elsewhere", so the thread is load-bearing exactly where
  the carried value and the ledger read disagree
  (`DesktopMoveSpaceGateTests` ▸ the single-screen landing case
  is that arrangement; the assigned case cannot red it). Create
  the Space where it is FILED — the shown route's filing, the
  hidden route's CLAIM at the departure — never at the parse or
  the record, or a refused move or an expired name leaves an
  empty Space (`DesktopMoveSpaceTargetTests` ▸ the bridge
  refusal and the expired name); `livingRememberedSpace` drops a
  record whose Space is gone. At the ARRIVAL the #1010
  screen-home net outranks the name — a Space moved to another
  screen between the command and the reveal is what that net
  exists for — and a change that lets the name win owes that
  suite's arrival-precedence case a new verdict. The explicit
  Space is a MEMBERSHIP write where a bare Desktop move is not:
  it takes `stickyMoveRefused` before anything moves, and every
  membership filing — this route, `moveWindow`, the #1010
  re-home, the Space Bar spring drop — goes through the one
  `fileMembership` (add, float re-anchor, focus stamp, emit),
  never a hand copy of that list, which is how the re-anchor went
  missing once; no fixture can see a float cross fake screens, so
  `PendingSpaceSeamTests` counts the callers and pins the
  re-anchor inside the helper. The ledger is bounded and per window,
  rekeyed on a tab switch; a new route that produces a departure
  claims through the gone handler rather than beside it, and
  `PendingSpaceSeamTests` is the register of those wirings.
  `DesktopMoveSpaceTargetTests` drives both routes and the
  control through the real dispatch and fold,
  `DesktopMoveSpaceGateTests` the refusals and the gate;
  `PendingSpaceAssignmentTests` holds the record.
- **A follow owes the window it sent away a focus, and pays it
  at the ARRIVAL** (#1007). `move_to_desktop_and_follow` onto a
  Desktop nobody is showing cannot focus the window at the moment
  of the move — AX does not list a window on an unshown Desktop —
  so `FollowFocusIntent` records the debt and the `.windowCreated`
  arm pays it, that being the moment the window is addressable
  again. Three obligations, and violating any of them leaves
  the behavioural suites green — `DesktopFollowTests` drives the
  paid path end-to-end and stays green through all three
  (guard-prover, #1007): the debt is recorded **only** for a
  switch that HAPPENED
  (a Desktop already shown produces no vanish and no reveal, so a
  debt recorded there is never drained); paying it is a space
  SWITCH — activate, focus, emit — because a bare focus leaves
  `focusedWindowID` naming the space the user left, so their next
  command acts there; and the departure stands the close-return
  raise down through the one `closeReturnRaiseStandsDown`
  predicate (the #936 clause below) rather than beside it.
  Key the drain to the arriving WINDOW, never to the reveal: a
  reveal is not scoped to the window that owes, so an unrelated
  switch inside the drain window would pay the debt and yank
  focus mid-swipe.
  `FollowFocusSeamTests` is the register of the production
  wirings — add a site there in the same change, since deleting
  any one of them leaves `FollowFocusIntentTests` fully green
  while the follow silently stops carrying focus. The ruling is
  `docs/design-decisions.md`'s.
- **A Desktop switch is not a close (#1207).** Leaving a Desktop
  folds its windows as destroys, and the close-return walk moves
  `Space.focused` down the departing windows to nil — or onto a
  carried sticky window (#1145), the one member that stays — so
  on the return the first re-track used to take the vacancy
  (#636's nil arm) and the settle asserted it. Each space's last
  HONORED focus is remembered in `DesktopMemory.honoredFocus`,
  written at the focus REPORT (`handleWindowFocused`, after the
  honored verdict) under the native Space the WindowServer hosts
  the window on (`NativeSpaces.nativeSpace(of:)`) — a writer
  other than the report goes through `rememberHonoredFocus` and
  joins `ReturningFocusSeamTests`' register; the frontmost seed
  (`seedStartupFocus`: boot, the AX grant, the wake restore) is
  that one other writer, OS truth about the window focused NOW,
  and so retires a standing return debt as a report does (#1345,
  `StartupFocusSeedTests` ▸ the seed's two cases) — never a fold,
  never the switch handler, and never under a cached
  Desktop: the device showed a fast app's own AX observer folding
  its windows BEFORE the switch notification, so a handler-time
  read remembers a focus the walk already moved, and a report
  that beats the handler would be stamped with the Desktop being
  LEFT (log, 2026-09-02; the same measurement is the #40 caveat
  on `WindowGoneReason.classify`'s stamp). The arrival arm owes
  the target space's entry for the snapshot's `mainCurrentSpace`
  — the main display's current native Space, with the global
  fallback where the topology cannot name that display (shared
  mode) — as
  `DesktopMemory.returnFocus`, a second `FollowFocusIntent`
  INSTANCE (same drain key, the arriving window; same
  cardinality), only for a window GONE from state: a present one
  — a carried sticky, or a window macOS restored and KiwiDesk
  already honored — needs nothing, which is how the restore
  never prefers the sticky and never yanks a focus the OS got
  right; and a focus HONORED in the active space while the debt
  stands RETIRES it (`rememberHonoredFocus`, the third reader of
  the debt) — the report is the OS's or the user's own choice,
  and the owed window's later arrival must not pay over it (CI,
  2026-09-02: `OpenOrFocusRingTests` ▸ the re-track after the
  focus report). The payment claims BEFORE it raises, so its own
  echo finds nothing to retire. The `.windowCreated` fold takes the debt mirrored in as
  `returningFocus` (the `arrivalDisplay` pattern) and rules two
  clauses: the owed RETURNING window takes the focus even beside
  a non-nil one — and into the ACTIVE space only
  (`ReturningFocusFoldTests` ▸ `returnIntoInactiveSpaceIsNotPaid`)
  — and while it is still `.departed` from that space no other
  returning window may claim the vacancy. The arrival arm
  RETIRES the last return's debt before deciding whether to owe
  a new one — a debt lives from one return to the next, never
  across a return that owes nothing — and owes nothing while a
  follow (#1007) stands: the verb named its window, and two
  debts paid on one arm would let the last re-list win. The
  payer runs in the `.windowCreated` arm, where the owed window's
  arrival ENDS the debt either way — raised with the settle's own
  shape (`refocusRetile: false, warp: true`), so the state pick
  becomes the OS's and the arrival retile pans to it, or dropped
  where the fold declined; `desktopSettle` stands its refocus
  down while the debt is owed — raising `Space.focused` there IS
  the first-in-row jump — and an unpaid debt expires at the
  follow's bound, macOS's own restored focus standing (the
  accepted-limitations row); the #634 arrangement reset forgets
  the memory with `rememberedSpaces`. The ROW comes back too: a
  departed window carries its slot in `departedSlots`, and the
  fold re-inserts a `.departed` return by RANK against the
  members already back — never at the index, which a later slot
  already back would overtake (`ReturningSlotFoldTests`) — and
  AHEAD of the track spawn rule, which placed a return as a new
  window, at index 0 in re-track order under `own_track`/`first`
  (#1387). The return takes back the BREAK it had too:
  `Space.remove` hands a departing head's break to its successor,
  so the record carries the break's provenance
  (`Space.BreakProvenance` — member, head, or handed), read off
  the Space's own `handedBreaks` set, which is the LIVE truth for
  a member still in the row — the record is the copy for a window
  no longer in it. The hand-off has ONE door,
  `handTrackBreakToSuccessor`, which every membership writer
  reaches through `Space.remove`, and a handed break is NEVER
  handed on (owner ruling, 2026-09-15) — the door drops it
  instead, so the hand-off is one hop, its head re-inserts its
  own on return, and a stray break lives at most one Desktop
  stay. The door hands as an OWN break; a writer that MARKS one
  handed (`markHandedBreak`) records its holder on the departure
  record first, in the same fold, and marks from THAT record —
  never from a link an earlier departure left
  (`DepartedSlot.handedTo`, read through the one `handOffTarget`
  ahead of the removal, and spent on EVERY arrival whatever the
  route, since a restore or a re-home returns a window outside
  the departed branch and a mode flip while the head was away
  is where a stale link came from) — so a head minimized, quit
  or moved hands for good, no record being able to reclaim it
  (`HandedBreakEnderTests` ▸ `unrecordedHandOffIsOwn`,
  `staleLinkNeverMarks`, `restoredReturnNeverMarks`). The link
  is consumed by the return's
  take-back and by the promotion, which both refuse a holder
  that dropped the break —
  never a positional guess, since a member back ahead of its
  head sits between the two and a head whose successor already
  held a break handed nothing. A head gone for good makes its hand-off permanent: a
  departure record ends only through `retireDepartureRecord`,
  which promotes the named holder — live, in the Space; away, on
  its record — ahead of dropping it, `DepartedSlotRetireSeamTests`
  refusing a bare `departedSlots[id] = nil` anywhere else, the
  gone handler's `.closed` arm being the one promote-without-retire
  since the rank is kept for later arrivals
  (`HandedBreakEnderTests` ▸ `everyEnderPromotes`,
  `ClosePromotesHandedBreakTests`) — while a hide or a Desktop
  departure keeps it revocable. The residue the ruling accepts: a
  departing window of ANOTHER Desktop, live in the same-named
  Space for the settle's beat, hands its break into this row the
  same way, and the stray column lasts until that holder's next
  departure (`docs/accepted-limitations.md`). Keep the rank and the provenance
  ONE value, so every ender and the re-key carry both or neither
  (`ReturningSlotTrackFoldTests` ▸ `rekeyCarriesTheProvenance`).
  The secondary-display arm owes nothing — not because it activates
  no Space, which stopped being true in #1230, but because the
  debt is recorded per SPACE at the focus report and paid by the
  create fold, while that arm moves a DISPLAY
  (`SecondaryDisplaySpaceTests`; `accepted-limitations.md`
  carries the residue). `ReturningFocusFoldTests` pins the fold and
  `DesktopFocusMemoryTests` / `DesktopFocusPaymentTests` the path
  through the real handlers, so
  a DELETED site reds there; `ReturningFocusSeamTests` is the
  register of the wirings' placement and order, which is what it
  adds: a site MOVED or DOUBLED still pays in a fixture whose
  events arrive in one order. Add a site there in the same
  change; the follow's own register pins that the follow
  instance never calls `forget()`. The ruling is on the issue and
  in `docs/design-decisions.md`.
- **A window on an away Desktop is KNOWN, in a ledger beside
  the state — never a member (#1146).** `StateCoordinator
  .awayWindows` (pid, app, bundle id, native Space) is written
  on a compositor-confirmed `vanished` (`KiwiCore.handleWindowGone`)
  and by the boot seed (`seedAwayWindows`) — a new FILING goes
  through one of those two, never an assignment beside a call
  site (review's: nothing scans for one). **The BOOT SEED admits
  only a window that is UP** (#1234, `AwayBootSeedTests` ▸
  `skipsParked`, `allParkedArmsNothing`): every reader requires
  it, so a parked entry serves nobody, and it can only LEAK —
  nothing tracks such a window, so no return ends it, and the
  compositor still hosts it, so no prune does either. An immortal
  entry keeps the 5 s census armed for the life of the process,
  which is why this is a leak with a cost rather than clutter.
  The gone handler needs no such clause and carries no guard for
  one: it writes only for a window that WAS tracked, and a
  tracked window that is minimized stays tracked, so it never
  reaches that path parked. A THIRD writer would owe the seed's
  clause and a case of its own — the two above see
  `seedAwayWindows` alone (measured, `guard-prover` 2026-09-03). The enders differ by
  what they mean: the RETURN pays whatever named the window (the
  create fold and the arrival arms), the #634 reset forgets the
  memory with everything else (`forgetDesktopFocus`), and the two
  enders for a window GONE FOR GOOD — the census prune
  (`pruneAwayWindow`) and the app's exit (the `.appTerminated`
  pre-fold in `KiwiCore+Events.swift`) — retire what still names
  it through the one `retireAwayDebts(of:)`: the #1207 memory
  and every arrival debt (`AwayLedgerTests` ▸ `pruneRetiresDebts`,
  `exitRetiresDebts`); a new gone-for-good ender takes the same
  call. The departure's space and rank stay in #1207's two
  records, and the three are read together. An
  entry ENDS on the return (the create fold), on a census that
  no longer hosts the id (`refreshAwayWindows`, which emits the
  corrective `closed` — at the Desktop settle and on the 5 s
  `awayCensus` task while the ledger is non-empty), on the app's
  exit, on the #634 reset with `rememberedSpaces`, and moves on
  a re-key (`WindowRekeyParityTests`' fixture populates it, so the
  reflection scan discovers the container; `AwayLedgerTests` ▸
  `rekeyFollows` holds the move). A prune retires all three
  records through the one `StateCoordinator.forgetAway`.
  **The ledger is reach and bookkeeping, never a bar row**
  (#1228): the Space Bar draws the Desktop in front of the user,
  so `spaceBarApps` reads `state.effectiveMembers` alone and a
  new bar derivation that merges the ledger is the bug, not a
  feature. A reader that needs a Space's row as it WILL return
  takes `withAwayMembers(_:of:)` — the fold's own rank insert —
  never a hand merge, and a profile's PARTITIONING record is such
  a reader, since a record that omits what is away forgets it on
  every switch (#1248); a reader keyed by app takes
  `awayWindows(bundleID:)`. An entry with NO Space (a boot-found
  window nothing has filed) is UNFILED: every reader carries the
  skip branch — `awayMembers(of:)` omits it, `get_state` lists it
  only at the top level — and a new reader owes the same branch.
  What the ledger must never become: a member of `space.windows`
  with a flag (every `space.windows` consumer would gain an
  exclusion, and the return-by-rank fold above would be
  reworked), or a reason for the sweep to remove anything
  ([accessibility.md](accessibility.md)).
  `AwayLedgerTests` pins the writers, the enders and the merge;
  `SpaceBarAwayTests` the bar's ABSENCE of them (#1228);
  `OpenOrFocusReachTests` the reach and the ring;
  `AwayBootSeedTests` the boot filing order;
  `GoneReasonEventTests` the classification through the handler.
  The ruling is on the issue and in `docs/design-decisions.md`.
  **Two residues on that #1228 clause, both measured by
  `guard-prover` 2026-09-03 and neither closable by a scan.**
  First, `SpaceBarAwayTests` pins `spaceBarApps` and nothing
  else: a merge added in another bar derivation — a new item
  builder, the front-app segment, #1229's overview panel — reds
  nothing, so each new author owes the branch deliberately.
  Second, the bar is kept clean at TWO independent points — the
  member list (`state.effectiveMembers`, which never yields an
  away id) and the resolution (`state.windows[id]`, which drops
  one) — so EITHER alone suffices and restoring only one is
  invisible: re-wrapping the member list in `withAwayMembers`
  left all three cases green until the away-resolving lookup
  came back too. A reviewer reading a half-revert as harmless is
  the failure mode; the pair is the guard, not either half.
- **The ignored-panel distrust mutates through its ONE state
  machine** (#21/#244/#951): `armIgnoredPanel` and
  `shouldConsumeIgnoredPanelReport` in
  `KiwiCore+IgnoredPanel.swift` are the only writers of
  `KiwiCore.ignoredPanel`, and `handleWindowFocused` the one
  consulting site — the #292 command guard is a read-only
  consumer. An inline `.insert` / `.removeAll` beside a focus
  call site is exactly the shape #951's disarm race grew from,
  and nothing scans for a new one, so each new focus-path
  author owes the routing deliberately. The #958
  accessibility-steal return is that machine's SIBLING, not a
  second writer: `KiwiCore+AccessibilityReturn.swift` owns its
  own debt the same one-machine way
  (`AccessibilityReturnTests`), and a new consumer of either
  latch routes through the owning file rather than reading the
  stored state beside a call site. The #1532 menu-bar reveal
  return is the third of the family and takes the same one-home
  shape: `KiwiCore+MenuBarRevealReturn.swift` owns the arm and
  its one-shot stamp, decides at the report — its docstring is
  the roster of what it reads there, and a new stand-down joins
  that roster rather than a call site — and re-asserts with the
  STAMPED raise, `raiseWindow`, so the report that follows is our
  own echo (#1281) and the scrolling placement distrust does not
  bounce it (#1414's class): never a bare `AXHelper.raise(`, and
  never the focus command, whose displacement note would arm
  that bounce against every later report. The
  live strip read stays behind `mouse.pointerInMenuBarStrip`,
  and both `makeTestCore` twins pin it false, since a live default
  reading the developer's pointer would return foreign reports
  in every focus suite. A fourth member of the family takes the
  same one-home shape with its own consulting site in
  `handleWindowFocused`, and a new live host read on any arm
  takes a `MouseTracker` seam pinned in both twins
  (`MenuBarRevealReturnTests` the verdicts,
  `MenuBarRevealSeamTests` the stamped raise and the arm's place
  between #1161 and #958, `MouseButtonSeamGuardTests` the read's
  home and the pins).
  `IgnoredPanelGraceTests` pins the machine's transitions (the
  dismissal grace, the click-provenance escape, expiry, the
  re-arm reset); the trade the grace accepts is argued in
  `docs/design-decisions.md`.
- **The sticky render verdict is DERIVED, never handed in
  (#1225).** `StateCoordinator.stickyRenderSpace(of:)` and the
  three derivations over it — `effectiveTiledMembers`,
  `effectiveMembers`, `floatingFocusCandidates` — read
  `workspaces.activeSpace` themselves. They used to take it as an
  argument, and across 25 production call sites not one wanted a
  different Space: a caller passing something else was never
  configuring the predicate, it was lying to it. #1214 handed each
  display's own shown Space in and every screen's bar was told a ∞
  window rendered on it, twice over (the glyph strip, then the
  `+n` tint) before the argument came out. So a new consumer takes
  the verdict as it is, and a site that believes it needs a
  counterfactual frame — "this row as it would look if that Space
  were active" — states what reads the answer, because the one
  site that had that shape was computing a row no layout ever drew
  (`AppliedEffects.RemovedWindow.tiledSlot`, whose contract still
  scopes it to the `focusLost` path where the two coincide).
- **Sticky Desktop reach is a CARRY, never a membership (#1145).**
  `KiwiCore+StickyReach.swift` MOVES every enabled sticky window onto
  the current Desktop of the screen it RENDERS on — from the switch
  handler's one snapshot, and again from the settle as the net — because
  the bridge MOVE is the one membership write macOS applies cross-app
  ([os-private-apis.md](os-private-apis.md) owns why the ADD is not
  one). Keep the carry ledgerless: where the WindowServer shows the
  window IS the state, so a pass must stay idempotent for the settle to
  repeat, quit owes no undo, and a change that adds a membership record
  to reconcile is the #1205 shape and is refused. Three more
  obligations. A carry is scoped to the screen the window RENDERS on —
  #445's `stickyRenderSpace`, 📌 its home screen and ∞ the active space's
  — so it lands where the retile draws the window and never crosses
  screens because some OTHER screen switched; the eager pass therefore
  runs AFTER the switch handler activates the arriving Space, and a
  screen on a fullscreen or system space is no carry target (#670). A
  verb that changes who is carried (the toggle, the pin, a profile or
  Settings apply) calls the refresh so its windows come to the user NOW;
  a site that merely marks the visible focused window sticky owes no
  refresh, since a carry onto the Desktop it is on moves nothing. And a
  carried window's vanish at the switch is the event loop's to distrust,
  not this machine's ([accessibility.md](accessibility.md), the carried
  arm) — what this machine owes that arm is the in-flight stamp,
  written by this file alone (`StickyReachDispatchSeamTests` ▸
  `ledgerHasOneWriterFile`): per dispatched move, and from
  `switchDesktop` for every window a switch WE dispatch will carry,
  before any notification (#1213, `StickyReachDispatchStampTests`;
  why the stamp must precede the notification is the carried arm's).
  `StickyReachCarryTests` drives the handler, the settle and the
  verdicts through the fake bridge; `StickyReachOverrideTests` the pin.
- A **native-fullscreen window keeps its `space.windows` slot
  but leaves both tiled-member derivations** (#670) — a layout,
  navigation or z-order consumer of the tiled members routes
  through `localTiledMembers` / `effectiveTiledMembers` rather
  than re-checking `isFullscreen` at its own call site; a walker
  whose domain is WIDER than the tiled members — one that parks
  floats, or reads `space.focused` — states its own check
  deliberately and says what it decides from it. macOS moved
  the window to its own Space, so a frame-set, navigation step
  or raise aimed at it fights the fullscreen app or yanks the
  user into its Space. Nothing scans for a fresh open-coded
  `!isFloating` partition, so each new site owes the routing
  deliberately — three shipped without it in this rule's own
  change set. **`resize` is such a walker, and it refuses a
  native-fullscreen focus ONCE, ahead of every path, cued**
  (#1298). Full screen is a fact about the WINDOW, never the
  layout — no layout places it, so no store a resize path
  writes is about it — so put the guard in `resize()` before
  the float branch, never per path: a per-path answer is how
  three paths WROTE for such a focus (bsp's no-slot sign
  fallback, stack's `inMaster` fallback, scrolling's
  focus-blind slot write) and moved the NEIGHBOURS while the
  float route refused silently. The refusal is
  `windowIsFullscreen`, never `layoutHasNoResize`, and it
  DRAWS — a pill reaches a native full-screen Space (owner,
  device, 2026-09-07). `resize()` is the keyboard, CLI and IPC
  entry to the `writeCapped*` writers; the MOUSE entry is
  closed by the drag pipeline's slot gate — `handleDragEnd`
  resizes only a window `calculatedFrames` placed, which a
  full-screen one is not — so a new input path to those
  writers, or a relaxation of that gate, owes the same
  refusal. `FullscreenResizeCommandTests` holds the two float
  arms; `FullscreenResizeTiledTests` holds the tiled ones — the
  four writing paths each with a control proving it WRITES when
  the focus is not full screen, monocle's `default:` arm (grid
  rides the same one) with a control proving it cues
  `layoutHasNoResize` there — and the drop gate, with a control
  proving the drop writes. A fullscreen flip
  is a membership change and retiles (`shouldRetile`), and the
  **fullscreen-space verdict comes from `NativeSpaces.isUser`**
  — never from the nil Mission Control number, which cannot be
  told apart from "SkyLight unavailable", where the
  single-space fallback must keep bars and settles running.
  `FullscreenLayoutExemptionTests` pins the membership half and
  `FullscreenStandDownTests` the verdict and the gated surfaces;
  the argument lives in `docs/design-decisions.md`. **The
  `windowIsFullscreen` refusal closes the class, not one
  cause**: a focus
  `activeSpace.focused` names that `effectiveTiledMembers`
  drops is floating (its own branch) or full screen (refused),
  and never an elsewhere-rendering sticky — `stickyRenderSpace`
  reads the active Space for `.global` and the home display's
  shown Space for `.display`, which `activeSpace(on:)` answers
  with the active Space whenever it lives there, so an ACTIVE
  home keeps its own sticky (#1301,
  `ActiveHomeStickyMembershipTests` ▸
  `activeHomeKeepsItsSticky`, with the hidden-home drop as its
  control). A new way for the active Space to drop a member it
  can hold as `focused` owes one ruling in `resize()` ahead of
  every path — a refusal like full screen's or a branch like
  floating's — never a per-writer answer, so the writers'
  `tiled.contains` stays a construction net rather than a served
  case.
- A mutation that can change **which windows overlap** — a
  reorder, a swap, a focus move that crosses more than one slot —
  **arms the matching z-order restore after its own retile**
  (`scheduleScrollingZOrderRestoreIfOverflowing`,
  `scheduleTrackZOrderRestoreIfOverflowing`, or
  `scheduleZOrderRestore`), or `requestZOrderRestoreAfterDispatch`
  when the retile belongs to the command dispatcher rather than
  the call site. Arming *before* the retile lets the settle
  callback consume the restore off the pre-mutation frames
  (#153). Nothing scans for a mutation that forgot to arm, so
  each new one owes its own arm deliberately — three have now
  shipped without one (#150, #153, #674).
  Arm **narrowly**: a restore drains a verified raise sequence on
  the blocking ordered queue — holding the mouse warp for as long
  as that takes — re-asserts the focus at the end of it, and
  leaves the tiled plane above the float layer until the next
  genuine focus event (#418), so "harmless, it re-raises the same
  order" is not an argument for arming on a mutation that
  scrambled nothing.
  And the close-return stand-down governs the ARM, not only the
  direct raise (#936): a removal whose return raise stood down
  arms no track restore either, because the drain ends in a focus
  re-raise of the very anchor the stand-down refused, one settle
  later; the next genuine mutation's arm heals the pile. **Which
  removals those are is
  `EventLoop.closeReturnRaiseStandsDown(after:departedWithDesktop:)`
  and not a list here** — this row carried one, a third arm landed under it
  (#1007), and a rule file that reads as instructions was
  carrying a false census until review caught it. A new arm goes
  in that predicate rather than beside it, so the raise and the
  arm can never disagree about which removals are exempt.
  Command-driven arms are exempt by ruling — an explicit user
  command is not an event-driven return raise; the product
  ruling (and which arms that covers) is
  `docs/design-decisions.md`'s. `CloseReturnStandDownWiringTests`
  pins both consulting sites.
  An arm in `focusWindow` guards against its own re-arm (the
  restore's closing re-assert calls back in) **semantically** —
  refuse because the focus is unchanged (`previousFocused !=
  id`, the jump test), never by gating on
  `zOrderRestoresInFlight`: that counter is warp-scoped, a
  drain holds it for its whole verified span, and a counter
  gate then drops GENUINE restores for exactly the window a
  double-target correction clicks into — the monocle arm
  shipped that way twice (#689). `ZOrderMonocleArmTests` and
  `ZOrderFocusJumpTests` pin one arm each.
- **An echo ledger is age-bounded and NEVER consumed by its
  echo** — `zOrderRaiseEchoes` (#689) and `selfRaiseStamps`
  (#887) alike. A lazy app reports a raised window's focus
  twice, ~150 ms apart, and the duplicate lands after the
  user's next step; a stamp the first echo consumed left it
  honored as deliberate focus — ring, pan and pointer snapping
  back (#887 device trace, 2026-08-31, on the very ledger the
  #689 fix left consuming). With nothing consumed, a reader
  telling "our raise" from "theirs" asks the ORDER of the
  stamps, never their presence: the #465 sibling distrust fires
  for a sibling raised AFTER the reported window
  (`siblingRaiseOutranks`), and a self-raise vetoes the z-order
  revert only when NEWER than the z-order stamp
  (`selfRaiseVetoesRevert`) — a presence test threads the
  restore's own echo past both nets. A ledger is cleared where
  its id dies (`forgetGoneWindow`) and rekeyed on a tab switch,
  and a CONSUMER of the self ledger reads a stamp's liveness
  through `selfRaiseStamp(_:now:)` rather than comparing the stamp
  itself; every raise MINTS its stamp through the one
  `stampSelfRaise(_:now:)` — `PlacementBounceSeamTests` ▸ the
  write-site census holds the minter, the gone clear and the
  rekey as the only writers — while the click readers
  (`recentClickReached`, `recentClickInside`, `recentLeftPress`)
  borrow the constant as a click window, which is not a stamp
  read;
  nothing scans for a new reading, so a new reader owes the
  routing deliberately. `SelfRaiseDuplicateEchoTests`,
  `RaiseEchoClickTests` and `ActivationReReportTests` hold the
  three arms. One ledger of this shape answers by GEOMETRY
  instead of order, there being no second stamp to rank against:
  `TilingEngine.placements` (#1161), stamped at `applyFrame` and
  `setFrame` — the two leaves the retile, the stash and the
  App-level placers share, so a NEW placement path routes through
  one of them rather than writing a frame beside them (the quit
  teardown's direct `WindowControl.setFrame` is the one ruled
  exception: the app is exiting, no focus report follows) — with
  the window a focus command moved focus OFF noted in the same
  ledger by the one `focusWindow` path (`noteDisplaced`, kept
  across the pan's later placement), and read by
  `KiwiCore.placementBounce`, which `handleWindowFocused`
  consults ABOVE the focus-follow and BELOW the z-order revert.
  It fires for a clickless report, after focus moved on: in the
  ACTIVE scrolling Space on the live entry ALONE — a pan that
  moved the window, on screen or off, or a focus command that
  stepped off it — because every narrower discriminator honored
  a bounce on the device (the argument is the design-decisions
  entry; a narrower arm owes a device sitting that shows the
  case it exempts is not one the app answers) — and anywhere else
  only where the placement lay past the edge AND the window
  refused it by origin, a clickless focus being how a user
  reaches a parked window. It re-asserts the intended window with
  a direct raise, since no sequence's closing re-assert will, and
  RENEWS the placement through the ledger's one `renew` door —
  never a stamp — whose chain ends at a ceiling measured from the
  placement itself, so a user's own retries cannot extend their
  lockout past twice the window (`PlacementLedgerTests`). These
  discriminators are FORGEABLE, unlike #465's ordering, and the
  trade is priced in `docs/accepted-limitations.md`. Its forget
  and rekey pair with the other ledgers' by hand, which review
  checks; `PlacementBounceTests` holds the two arms, the on-screen
  placement bounced, the renewal, the click escape and the bound,
  `PlacementDisplacementTests` the displacement and its wiring,
  `PlacementBounceSeamTests` the two leaves, the renew door, the
  one displacement recorder, the consult, the write-site census
  and the raise. A report the focus command already INTENDED is
  never bounced — `intended != id` is the consult's first clause
  — and `focusOwnWindow(number:)`, beside the arm, is the door a
  GUI raise of an own window takes so its report arrives that way
  (#1281, `PlacementIntentTests`): the command for a tracked
  window, and for a CLOSED one — re-shown under the number it
  kept, so the fold files it as a RETURN that steals no focus
  (#636) — a debt in `ownShowFocus`, the third `FollowFocusIntent`
  instance, paid with that command by `payOwnShowFocus` on the
  `.windowCreated` arm the other two drain on, without the
  refocus retile that arm's own retile makes redundant, judged
  there on the Space the arrival landed in and stood down where
  state already holds the focus (#1380, `OwnShowFocusSeamTests`
  pins the recorder, the drain and the retire by count and the
  payer to that arm). A fourth ledger joins this bullet rather
  than earning its own consume.
- **A raise of a window the compositor is not drawing IS a Desktop
  switch, and no implicit raise performs one (#1345).** macOS
  switches Desktops to show whatever is raised, and the window
  such a raise names is the one the user just LEFT: it is still
  in state because its app's destroy notification runs seconds
  behind the swipe (Electron, measured 2026-09-08 — the argument
  is the design-decisions entry). So the verdict is TWO compositor
  reads, and either refuses (#1410): the draw list's on-screen
  flag (`kCGWindowIsOnscreen`), which composites every
  neighbouring Desktop's windows for the second a gesture runs
  (measured 2026-09-13), AND the Space the compositor hosts the
  window on — ANY of them, since an all-Desktops window is hosted
  everywhere — against the displays' current Spaces, which lag
  the draw list the other way through a switch and let a
  re-assert through on device (2026-09-08); a read that cannot
  answer abstains, so a host without SkyLight keeps the flag's
  verdict — never state, never the away ledger, which that window
  has not reached yet. `KiwiCore.raiseCrossesDesktops` reads them
  through the two seams `windowIsOnScreen` and
  `windowIsOnShownDesktop`, each raw read living in its seam's
  default alone and `makeTestCore` pinning both to nil in both
  twins (`DesktopRaiseGateSeamTests`, `DesktopRaiseGateHostTests`
  holds the two-read verdict over the measured two-display
  topology); `focusWindow` refuses
  the VERB whole on it, ahead of the state write, the warp and
  the pan — a state-only move would split state from key focus
  (#952) — `raiseWindow` re-asks for the deferred raise, and the
  distrust re-asserts (#1161, #465, #958, #1532) stand down
  through the one `reassertCrossesDesktops` and HONOR the report
  instead. Unknown to the server passes: a close in flight raises
  nothing, and a host without the read keeps every raise. A verb
  that means to switch takes `switchDesktop`, never a raise.
  `DesktopRaiseGateTests` holds the gate and both consumers,
  `DesktopRaiseGateArmTests` the three arms each beside a shown
  control, and `DesktopRaiseGateSeamTests` the census of files
  that may spell `AXHelper.raise(` — a new raise site joins it
  and asks the gate in the same file. Further arms follow from
  the same reading that a swipe is not a close — append one here
  rather than opening a bullet of its own: a window that LEFT
  WITH ITS DESKTOP — `vanished`, and not a move verb's own
  departure, which the verb records per window and the gone
  handler claims (`departedWithDesktop`, never the #482 follow
  latch, whose second expires before a slow app's destroy) —
  stands the close-return raise down as one arm of the ONE
  predicate (the #936 clause above says why that predicate, and
  not this file, is the census of its arms), since macOS picks
  the focus on the Desktop it shows
  (`DesktopDepartureStandDownTests`); and a report for a FRESH
  return's remembered focus — returned within
  `restoredFocusWindow` and the #1207 memory's entry under the
  compositor's host, `isRestoredDesktopFocus` — is macOS
  restoring it, so the #1161 placement distrust stands down on it
  rather than bouncing the OS's own restore, and on nothing older,
  where the memory names whatever was honored last
  (`DesktopRaiseGateArmTests` ▸ the restored-focus triple); and
  the settle's own (#1364): `desktopSettle` never re-asserts a
  focus the switch itself removed — a window whose departure
  `departedWithDesktop` filed, through the one
  `fileSwitchDeparture`, no earlier than the switch grace before
  the switch and inside `switchDepartureWindow`, asked through
  the one `departedWithThisSwitch` and never by reading
  `DesktopMemory.switchDepartures` at a call site — and that
  record is re-keyed, retired and #634-forgotten with
  `honoredFocus`, since it is id-keyed like it
  (`DesktopSettleDepartureTests`). The arm reads no on-screen
  flag on purpose: the argument is the design-decisions entry's.
- **Several raises that must land in a given ORDER go through
  `raiseSequentially` / `performZOrderSequence`** — never a loop
  of bare `AXHelper.raiseQuietly` calls. The AX call returns once
  the app has *accepted* the raise, not once it has performed it,
  so a loop issues the whole sequence inside the window where
  none of it has happened yet and the apps land it in whatever
  order they reach it — the pile settles scrambled (#684).
  `ZOrderDrain` owns the verification, the budget and the timings
  they are sized from; read them there rather than quoting them
  here. What earns the sequence is a landing worth verifying — an
  order to keep, or a floor the raise must clear; a raise with
  neither needs none of it. Nothing scans for a bare loop, so a
  new ordered raise owes this deliberately. Weigh a teardown
  raise harder than a live one, and buy it a bigger budget: the
  quit-grid restack's raises run after management stops, so no
  later restore can correct a miss and this rule's usual "the
  next restore heals it" does not apply there (#688,
  `KiwiCore+TeardownRaise`). Weigh, for any sequence, what the
  frontmost app's key window costs inside it: a quiet raise
  cannot beat that window, so it never costs only its own slot —
  every window the order puts above it waits out a whole
  `landingLimit` that can never be satisfied. The two shipped
  sequences answer that differently *because its role differs*,
  and a third must say which it is. The teardown restack drops it
  from its TARGETS, since the circle would otherwise order
  windows above it. The float raise and the monocle restore keep
  it out of the FLOOR instead (`raiseFloor`, which owns the
  measurement) — and knowingly leave it among the targets, the
  same class of residue `floatLayerTargets` already records for
  mixed CGWindow layers. Price that residue as **n ×
  `landingLimit`, not one**: the landing check carries the
  unbeatable window in every subsequent comparison, so a plan of n
  raises pays the limit n times and can spend the whole budget
  with the mouse warp held for all of it (architect review,
  2026-08-03). The two guards are
  `ZOrderTeardownDrainTests`
  (`aPinnedMemberIsDroppedNotAbsorbed`) and `ZOrderRaisePlanTests`
  (`floatFloorExcludesTheFocusedWindow`), and
  `ZOrderSequenceWiringTests` pins that the teardown call site
  still drops it.
- A context site that **materializes scrolled-out scrolling
  frames — or monocle's parked frames (#881) — threads
  `screenNeighbors`** (#878):
  `TilingSettings.context` defaults the flags to all-open (the
  single-screen verdict), and nothing scans for the omitted
  parameter, so a new site that computes real scrolling frames
  without threading the engine's per-retile detection
  (`ScreenNeighbors.detect` over the `allScreenBounds` topology
  seam) silently reverts every edge to open — the #878 defect
  returning without a red. `layoutInput` is the threading site;
  capacity probes, bar-strip carves and schematic previews
  rightly omit it and get every edge open. The wall verdicts
  are an input detected fresh each retile, never a cache —
  which is also why a stash or corner consumer reads the same
  seam rather than enumerating screens itself. And a corner
  consumer takes the corner PREFERENCE from
  `TilingEngine.optimalHideCorner(neighbors:)` — the one copy
  the stash and monocle's park share (#881) — never a
  re-derivation beside the flags, or the two answer one
  arrangement differently.
  `ScreenNeighborsPlumbingTests` pins the threading and the
  default; `ScrollingBlockedEdgeTests` the clamp forms.
- **An app-enforced size bound is learned, never assumed
  (#677).** AX exposes no min/max-size attribute, so the engine
  learns a bound from its own asks: `retile` records each issued
  size and reads the settled, echo-fed state frame as the app's
  answer — the same ask refused with the same answer twice
  confirms a per-axis, PER-ASK `EffectiveSizeBound` entry, and
  **only a SETTLED read may cast either of those two votes,
  with one named carve-out** (#1083). A raw echo seeds and
  refreshes a candidate; it promotes one only through #1049's
  comply-then-revoke pair, where an earlier echo reported the
  window AT the asked size and so proved it took it. Every
  other raw promotion is barred, because an echo reporting the
  pre-ask frame is the same bytes whether the app refused or
  has merely not redrawn yet, and under load the second is
  ordinary for any app. A new `SizeAnswerChannel` therefore
  owes an honest `isSettledRead`, and widening what counts as
  settled re-opens #1083 through that door —
  `SizeBoundBaselineTests` holds all three verdicts (the same
  fixture answered by a settled read, by one echo, and by a
  repeated echo) and is what reds if either term is dropped —
  ENTRIES never generalize across asks (a grid-snapping app
  answers each ask differently; the one deliberate exception is
  the compliance contradiction sweep, argued on `complied`) —
  while a CORROBORATED bound does, revocably (#1055, owner
  rulings 2026-08-27/28): `consumedWidth/Height` and `explains`
  answer an ask BEYOND `maxWidth`/`minWidth` with that bound —
  re-resolved once through the entry at the bound's own span,
  since the consume rewrites the ask the ladder sees — a
  per-ask entry outranks the generalization for any ask it
  matches, a FORCED (explicit-apply) pass probes past
  corroborated bounds via `LayoutContext.probesBeyondBounds`
  (never widen its producers past `retile(pass: .apply)`),
  corroboration requires asks `corroborationDistinctness`
  apart (a coarse snap's row height beats the entry-keying
  tolerance), and a corroborated ceiling corroborates the
  single floor entry at the same span — the fixed-span lend,
  paired values only. **The corroborating second ask is SENT,
  never awaited (#1439)** — the argument is
  `docs/design-decisions.md`'s entry of that name; what binds
  here: a confirmation arms its probe from `promote`, and a
  second arm site owes the same guards (`promote` is its one
  caller today, unscanned); the retile loop issues it
  only in place of an ask the anchor already answers, never a
  new one and never on a forced pass; it is re-issued once and
  only once its first answer seeded a candidate; a probe's own
  confirmation arms none, and an ask that has had its probe
  stays probed for the ledger's lifetime, since the compliance
  sweep re-confirms an anchor a grid app answers inside the
  tolerance; a PERFORMED probe is decided by the SETTLED read
  alone — `wantsProbe` keeps the settle probe wanted for a
  compliance at a pending probe's ask, `complied` is the one
  site that retires a probe on one, and `observe`'s verdict
  raises the placement the sweep would not send, while the raw
  echo retires nothing, so the emulator's snap-back still
  pair-promotes (`SizeBoundCorroborationProbeLifecycleTests` ▸
  `performedProbeIsDecidedSettled`); and a further baseline
  producer beside the retile
  gate's verdict owes the probe's four terms — a settled
  confirming read, consumed by one issue, killed by any ordinary
  `recordAsk`, checked against the anchor's answer at take
  (`SizeBoundCorroborationProbeTests` ▸ `rawPairArmsUntrusted`,
  `ordinaryAskDistrusts`; the rest of the ladder in that suite,
  its lifetime in `SizeBoundCorroborationProbeLifecycleTests`).
  A new per-window store on the learner joins its lifecycle
  hooks — `forget` and `rekey` discovered by reflection
  (`SizeBoundLearnerLifecycleParityTests`), the tombstone's park
  and revive still by hand. The loop's
  substitution through the explained skip (the `close` half is
  `SizeBoundResiduePlacementTests`'), the forced pass, the
  performed probe's retile on both channels, the pin and the
  placement pass —
  bounded to two, since an echo-quiet pass can confirm the
  answer it issued, and its flag clear afterwards — are
  `SizeBoundCorroborationProbeEngineTests`'; the drain after
  that loop is belt, unguarded. The cap
  consequence softens: an evicted
  ask beyond a still-corroborated bound consumes without
  re-dancing, while evicting the corroborating pair itself
  silently revokes the generalization until it re-learns. The
  argument and the probe evidence are `EffectiveSizeBound`'s
  header and the issue (`SizeBoundGeneralizationTests`,
  `ScrollingFixedSpanCueTests`, `ScrollingBoundRepackTests`)
  — and
  hold a ladder PER ASK up to `SizeBoundLearner
  .maxEntriesPerAxis` (alternating layouts starved a single
  slot, device QA 2026-08-18; keep that cap sized past every
  real producer, because an evicted candidate re-opens the
  starvation) — after which the
  un-forced skip treats the refused target as "already there"
  (ends the endless re-issue) and the layouts place the residue
  (scrolling re-packs, monocle and a lone scrolling window
  center, bsp and stack land a floor's residue inward through
  `SplitOverflow.placed` on the issued frames, #934). And only
  a SETTLED read — the retile-time gate, the
  settle probe — may clear learning on a compliance (#1049): a
  raw echo's compliance can be the transient half of an app's
  comply-then-snap-back (the Android emulator animates to the
  full ask, holds it ~0.4 s, snaps back), and clearing on it
  wiped the ladder every probe cycle, so "twice in a row" never
  accumulated and the dance re-issued forever
  (`SizeBoundInvalidationTests`,
  `SizeBoundTransientComplianceTests`). Three obligations
  follow. A frame-producing context
  build **threads `sizeBounds`** the way it threads
  `screenNeighbors` — `layoutInput` is the site, probes and
  previews rightly omit it (`SizeBoundPlumbingTests`). A path
  that changes a window's size outside the engine's asks **owes
  the ledger an invalidation** — a genuine resize forgets
  outright, rekey migrates — or a stale bound pins the window
  at a size the app no longer insists on
  (`RetileBoundSkipTests`) — and the gate tells our echo from
  that resize by the applier's recently-set stamp (and, past its
  grace, by `ledgerExplainsResize`), so the stamp is written at
  ENQUEUE ahead of the set and AGAIN after it, never only after
  it returns (#1254): an app posts its notification while
  performing the set, and the notification's read reached the
  main actor 57–74 ms after a press, before the per-app queue
  had stamped, so the gate wiped the ask on our own spring's
  first frame — every press learned nothing, the floor was
  corroborated late and only through the baseline arm, and a
  bound already refusing vanished on the next performed ask
  (`FrameApplierStampTests` pins the enqueue stamp,
  `SizeBoundGateNeedleTests` the pair; the measurement is on
  the issue). What that fix leaves is the learner's own latency
  — `docs/accepted-limitations.md`'s split-layout row states
  it. A GONE path (destroy, hide) is the
  #1049 carve-out to #152/#158's destroy-forgets: it takes
  `stashSizeBoundOnGone`, never a bare forget — the believed
  ledger parks in a pid-checked tombstone the same window's
  re-add revives before its arrival retile, because a slow-AX
  app flaps (dropped and re-added under the SAME id seconds
  apart) and a plain forget re-ran the whole learn dance on
  every flap and unhide. `SizeBoundReviveTests` pins both gone
  arms and the stand-downs; a NEW gone path joins the stash
  deliberately, since nothing scans for a bare forget beside
  it. And only the layout loop
  **records asks** — a stash park or float restore is not a
  layout ask, and learning from one keys a bound to a frame no
  layout re-issues. Rendering may
  additionally trust an UNCONFIRMED candidate (the overlay pin's
  fallback — cosmetic, self-correcting); geometry never may.
  The ladder is `SizeBoundLearnerTests`; the
  overlay half is [borders.md](borders.md)'s pin row.
- **A scrolling viewport offset travels with the slot it was
  measured against (#966).** One slot size serves the whole
  row, so anything that changes it — a resize, a window opening
  or closing ahead of the focus, a #677 re-pack — moves every
  slot underneath that offset, and `follow` is the one anchor
  that reads it. So `Space.scrollRest` carries the offset AND
  the focused slot it was measured against as ONE value: the
  same focus holds that slot's place on screen, a different
  focus holds the offset and pans minimally (#66). **A REORDER
  releases the slot in the model (#1353)** — every `Space`
  primitive that rewrites the order calls
  `Space.releaseScrollSlot`, so the next pass holds the viewport
  and the pair visibly trades places — because the layout cannot
  tell a swap from a neighbour closing ahead of the focus, and
  only the model knows which happened. So **write the window
  order through a `Space` primitive, never beside a call site**:
  `ScrollSlotReleaseSeamTests` scans `KiwiDeskCore` outside
  `Models/` for an order write and its `allowed` map is the one
  copy of the mode-bound exemptions; `ScrollSlotReleaseTests`
  holds each primitive and the arrival that keeps the slot;
  `ScrollingResizeAnchorEndToEndTests` holds the keyboard swap
  and the bar drop on screen, and skips on a headless host.
  "Place" is the slot's leading edge, except where it was
  resting flush against the TRAILING border, which is the edge
  it keeps instead — otherwise a shrink tears it off a border it
  was sitting on, and two situations nothing on screen
  distinguishes (flush-with-more-behind vs last-in-row, which
  the boundary clamp already holds) answer differently. Flush at
  both borders takes the leading edge. Which is why the recorded
  slot carries the VERDICT rather than the geometry behind it —
  the argument for that is three paragraphs down, and is stated
  once.
  Three obligations follow. **Never split the pair into two
  fields** beside each other, and never re-derive the verdict
  at a call site — nothing scans for either, so each new author
  owes it deliberately. **A layout PASS never DESTROYS provenance
  it was handed**: a nil slot is the "no provenance to re-anchor
  from" verdict, so a pass that carries an offset through
  carries its measurement too, and one that drops it silently
  reverts to the pre-#966 behavior — the model's reorder release
  above is the one sanctioned drop, and it is not a pass. A new producer of a
  rest joins `ScrollingResizeAnchorEndToEndTests`, because a
  suite that injects the rest by hand cannot see a producer at
  all — which is most of them, and is why that end-to-end suite
  states a skipped host must read as a SKIP rather than a green.
  And a **new id-keyed home inside
  `Space` owes `Space.rekey`**: `scrollRest.slot.window` is a
  bare id in a struct, which `WindowRekeyParityTests`' count
  pin cannot see — only its `String(describing:)` scan can, and
  only because the fixture populates the field.
  And the verdict is reached at the PRODUCER, where the offset
  and the viewport it was measured in are both in hand: a
  consumer comparing a recorded extent against a later `along`
  is deciding flushness about a viewport the slot never sat in,
  which a bar toggle or a gap edit is enough to change.
  `ScrollingResizeAnchorTests` pins the discrimination itself —
  same focus, different focus, no slot, fixed anchor — and the
  row-end clamp that outranks it (a clamp that is `follow`'s
  ALONE since #1388: `center`, `start` and `end` rest the focus
  where they say whatever the row's extent, and under them the
  slot the anchor places is the one `ScrollingLayout.subject` —
  the tiled focus, or while a float holds focus the window the
  rest remembers — so a scrolling metrics consumer reads
  `subject` and never `context.focused`; a held rest is bounded
  only once that window has left the row —
  `ScrollingAbsoluteAnchorTests` ▸
  `floatFocusAnchorsTheRememberedWindow`), that last on a
  NON-last focus
  deliberately, since a last slot at a legal offset is
  flush-trailing by construction and would let the border arm
  answer in the clamp's place. `ScrollingBorderAnchorTests` is
  the border half: the arm that keeps an edge, the tolerance
  that decides flushness, and the producer's recording.
  `ScrollRestPlumbingTests` pins the carrier. The product
  ruling — including why a reorder is ruled OUT at the model
  rather than in the layout — is `docs/design-decisions.md`'s.
- **A scrolling share is a share of the PITCH, resolved in ONE
  place (#1382).** `ScrollSize.resolved` — and `editablePoints`,
  the press base — take the inner gap of the axis they resolve
  on as a REQUIRED argument, so `f·(along + gap) − gap` tiles n
  slots of 1/n exactly; a consumer hands the resolver that axis's
  inner gap and never `0`, which reinstates the bare-axis
  reading the compiler cannot see (`ScrollingPitchTests`, and
  `LayoutSchematicPitchTests` for the preview, which calls the
  resolver rather than copying it). A count↔fraction inverse
  or a "how many fit" door is Core's, homed beside `pitched`,
  never GUI arithmetic over a screen frame.
- **A resize store holding an absolute LENGTH owes a ceiling,
  and since #1057 the whole press DECISION lives in ONE pure
  type (#966/#1057).** `ScrollSlotDomain.decide` — reached only
  from the `writeCapped*` seam, which resolves the base input
  off the ENGINE's computed frame for the focused window
  (#1063, `ScrollingFreshLedgerPressTests`: a reconstruction
  beside the layout asked the ladder at a span no layout
  issued, so a fresh ledger ballooned the press; the consume
  of the layout-floored, viewport-capped store stays as the
  fallback for a focus the engine computes no frame for — a
  floating or native-fullscreen focus, mid-adoption) — owns
  every cap and refusal arm
  (`ScrollSlotDomainTests`); a new arm goes there, never inline
  in a writer. The obligations it holds: the press measures
  from the focused window's DRAWN span; a press the window's
  bound blocks outright refuses IN PLACE (pill, no write, no
  neighbor moved); never-reduce-a-configured-value is
  GROW-only — a shrink is the user's deliberate act and
  rewrites the store from the drawn span; the floor never
  raises the store and wins the narrow-display contradiction;
  the viewport truncation is a silent stop (no pill, no
  bounce). The #966 auto-store trim on the first press is
  RETIRED — the drawn-span base supersedes what it bought.
  The pre-#1057 clauses below stand where they still apply: A ratio or a share is bounded by
  construction; a length is not, so it can bank growth the
  layout never draws (`min(along, …)`) and then charge a press
  per invisible step on the way back. Three obligations for one.
  The ceiling clamps beside the floor at the interactive write
  site, never in the value type — `ScrollSize.minPoints` is a
  property of a slot and an ABSOLUTE-LENGTH maximum is a
  property of the screen (`maxFraction` is rightly in the type:
  a fraction is unitless). It is the area the layout DRAWS,
  taken from the same `windowFrame` carve
  `ScrollingLayout.metrics` caps against, never the layout
  region it is carved from — on a vertical axis the difference
  is the App Bar's own thickness, the same defect in miniature.
  And it never reduces a CONFIGURED LENGTH: an explicit
  `scroll.set_slot_size` above the ceiling is a deliberate
  statement that survives undocking, so a grow refuses rather
  than rewrites. An `auto`/`%` store is deliberately NOT covered
  — it resolves against the region, so leaving it alone would
  re-bank the strip on the first press; that trim is the rule
  working, not a defect to fix back.
  The focused window's learned app MAXIMUM joins the same
  write-site ceiling (#1055): believed only under the floor's
  own two-distinct-asks corroboration
  (`EffectiveSizeBound.maxWidth` / `maxHeight`, read through
  `effectiveMaxSize`), and it may only ever REFUSE a shared
  store, never trim it — one slot serves the whole row, so a
  trim to one window's limit visibly shrinks every neighbor on
  a grow press. A grow the app ceiling truncates cues
  `ownMaximum` on the focused window; one the viewport
  truncates stays wordless (`ScrollingAppCeilingTests` pins
  the refusal, the never-trim and the silence). A second
  absolute-length store, or a new `maxWidth` consumer, owes
  these obligations deliberately — nothing scans for a site
  that never wires the ceiling at all.

  **A press writes FORWARD, never across the store (#1083).**
  The layout draws a bound-pinned window at its learned limit
  and the press measures from that drawn span (#1057) — so
  where the drawn span sits on the far side of the store, that
  base wrote across it: a grow from a pinned 715pt window
  inside a 1160pt auto slot wrote 765 and trimmed the row, and
  the shrink mirror raised a 300pt store to 775. Take the base
  from whichever of the two lies forward of the press — `max`
  on a grow, `min` on a shrink — which keeps both #1057 cases
  and makes the crossing impossible by construction.
  `ScrollSlotDomainTests` holds both directions with the device
  numbers. Do NOT answer this with a guard on the write
  instead: that was tried and swallowed the press with no write
  AND no cue, and a press that does nothing must always say
  why.
  Scrolling is the only such store today, which is an
  observation rather than the rule.
  `ScrollingSlotCeilingTests` pins the drawn area rather than
  the region (on both axes — the vertical one is where the bar
  strip makes the difference visible), the configured-length
  rule, and the floor outranking the ceiling. That the ceiling
  is not in the value type is review's: no suite can see a
  maximum nobody wrote.
- **An interactive resize write goes through the shared capped
  writers (#933).** The keyboard `resize` verb and the mouse
  resize end call the one set of clamped writers — the
  `writeCapped*` family, named by that prefix rather than by a
  file, since it has already outgrown one
  (`KiwiCore+RatioWriters` and `KiwiCore+ResizeScrollSlot`) —
  never a raw `writeSlotSize`,
  `writeSplitRatio*`, `writeMasterRatio` or `stackWeights`
  write from a resize path, which is exactly how the mouse
  `.scrollWidth` drag crossed the floor the keyboard path
  refused. The writers clamp each side at its members'
  effective minimums (`min_window_size`, raised by a #677
  learned bound) and cue a truncated attempt — a pill on each end
  (the trier names the reason, the blocker marks itself), the
  bounce on the trier
  (`ResizeSizeLimitFeedbackTests`,
  `ResizeNeighborLimitTests`). And a weight clamp divides the
  span the LAYOUT divides — the one
  `StackLayout.weightedSpan` copy, kept `minSizeMargin` above
  exact equality — never the raw region span, which crosses
  the layouts' cascade checks by exactly the gaps it ignored:
  that is how #925's clamp still collapsed a
  clamped-at-minimum track space into a pile
  (`WeightStepOutcomeTests`).
  And a write-time clamp is only half the guarantee (#944): it
  validates against the membership at PRESS time, so a track
  session store also rides the retile-time heal
  (`healTrackSessionWeights`, called from `KiwiCore.retile`;
  the math is `StackLayout.healedWeights`) — a NEW session
  weight store joins that heal in the same change, or a
  membership change after a legal write collapses the space
  into a pile the clamps cannot see coming.
  `TrackWeightHealTests` pins the wiring, `WeightHealTests`
  the math; the ruling and the stack-zone residue are in
  `docs/design-decisions.md`. **The split stores joined that
  heal with #934/#1430**: `healSplitFloors`, beside the track
  heal inside the same forced-pass scope, moves a bsp split
  ratio or the stack master ratio so a side draws its members'
  LEARNED floor — `SplitDomain.healedRatio` is the math, the
  `flooredWeights` shape, judging the stored ratio where the
  render pins it and sinking a side only for a learned floor,
  since the global floor is the render clamp's (#383) — written
  through the capped writers with NO focus, so the write clamps
  like a press and cues nothing, over the LOCAL members and the
  render's own `layoutInput`. A floor the yield cannot fit is
  the `unfit` verdict: cued ONCE per (space, axis, window)
  episode with the neighbour-minimum pill on the overhanging
  window, the memo in `KiwiCore.splitFloorCues` re-armed when
  the window fits again or its bound is forgotten, and the
  frame lands INWARD through the one `SplitOverflow.placed`
  post-pass on the frames the retile ISSUES
  (`TilingEngine.placedFrames`), never inside the layout
  algorithms, which stay pure — and that cue takes the pill
  funnel's retile door (`refuseFloorUnfitAtRetile`, `fromPress:
  false`): the pills and the border report without a press's
  glide note or bump (the sound keeps the speaker's own
  press-in-flight gate), and only for a space shown this pass,
  since a pill draws on a window. **A pass now produces
  TWO frame sets, and a new reader says which it takes**: a
  reader that CLASSIFIES slots — a side, a drop target, a
  neighbour, a cascade order — keeps `calculatedFrames`, and one
  that acts on where a window IS — a cue drawn on it, the
  unsolicited-resize check — takes `placedFrames`, because an
  inward frame overlaps its neighbour by construction and a
  classifier handed it reads a pile (`BspSplit.sides` dropped
  both windows of the first unfit pair that way), while a cue
  handed the slot draws beside the window.
  `FrameSetReaderCensusTests`' `allowed` map is the one copy of
  who reads which and why. The stack zone's own shares
  stay out (#944). `SplitFloorHealTests` holds the math,
  `SplitOverflowTests` the post-pass, `SplitFloorHealWiringTests`
  the retile wiring and the traveler stand-down,
  `SplitFloorCueTests` the cue and the inward landing over a
  real core, `SplitFloorHealNeedleTests` the routing; the
  ruling is in `docs/design-decisions.md`.
  And the AUTOMATIC track count is
  derived from the members' corroborated floors on the cross
  axis, never from `min_window_size` alone (#1355): the one
  `TrackLayout.geometricCap(for:of:)` reads the tiled list and
  the context's `sizeBounds` through the reading the cap and the
  heal share, `learnedFloor(of:in:)` — the pure twin of the
  clamps' `KiwiCore.effectiveMinSize`, two homes until a pure
  static both can route through — stands down on a forced pass like
  every corroborated-bound consumer, and a FIXED limit stays the
  user's number (`TrackLearnedCapTests`) — while the count is
  only feasibility, so the heal's second pass re-shares the
  track weights until each track draws its floor and no wider
  than its members' corroborated ceiling, read through the one
  `trackCeiling(of:in:)` over `learnedCeiling(of:in:)` — the
  floor reading's mirror, and the pure twin of the clamps'
  `KiwiCore.effectiveMaxSize` the same way, two homes until a
  pure static both can route through
  (`TrackLayout.flooredWeights`, `TrackFloorHealTests`,
  `TrackCeilingHealTests`, #1488) — and the resize clamp reads
  that ceiling too, refusing a grow AT it with the own-maximum
  pill rather than landing a write the heal un-writes
  (`TrackCeilingHealTests` ▸ `growAtCeilingIsRefused`). A
  consumer of the LEARNED cap takes the render's own input
  through `layoutInput`, never a context built beside it, over
  the LOCAL list where it WRITES stored weights, since a
  traveler's floor must not rewrite them (#944) — and a
  retile-time writer runs inside `KiwiCore.retile`'s
  `withForcedPass` scope, the one writer of the pass flag, so
  an apply's render and its heal fold alike, while a press-time
  READER (the resize clamp) takes the unforced verdict, which is
  what the next event pass draws
  (`TrackCapPlumbingNeedleTests`); the ruling is in
  `docs/design-decisions.md`.
  And a track fold consumer holding a `LayoutContext` — the
  render, the heal, the resize clamp, the `track.swap` gauge —
  takes `TrackLayout.renderPartition(of:in:)`, the one assembly
  of the cap and the fold over one list, so a refusal names a
  share the screen draws (#1488, `TrackResizeFoldTests`); a
  consumer with no context in hand at that moment (the swap's
  headless fall-through) takes `TrackLayout.foldedPartition`,
  never a hand assembly of `counts` → `overflowCap` beside it. The hand copy shipped at
  three sites and drifted before the #944 rounds extracted the
  one assembly, and a fourth grew before #1488 extracted the
  cap beside it; nothing scans for a new hand copy, so each new
  consumer owes the routing deliberately — a fold-rule change
  that updates the render and misses a hand copy re-opens the
  exact divergence the extraction closed.
  And **a refusal names a window the write could have MOVED**
  (#1259). The own-minimum wording is owed only to a focused
  window ON the side that could not shrink, so a writer STATES
  that (`focusedIsBinding`, the one discriminator
  `reportResizeRefusal` takes) from its own partition rather
  than inferring it from the gesture's direction — including
  the case where the focused window is in NO group of it, which
  every writer has: a stack zone and a track partition the
  TILED members, and no live focus is outside them — a
  construction net, since the #670 bullet's `resize` clause
  rules every droppable focus ahead of the writers (#1298,
  #1301) — while bsp's sides are
  geometric and a window spanning the whole tiled extent on the
  axis sits above every split of that orientation, so no ratio
  move can resize it. That window is dropped from both sides by
  the one `BspSplit.sides` authority — which also keeps
  its floor out of the CAP, where it blocked a write no window
  on the split was constraining — and the binding side is then
  read off the WRITE's own direction, never the focused
  window's side, which says nothing when the window is on
  neither.
  The empty case is the CUE's alone, and the write is not part
  of it: a ratio is a stored per-space value whose caps protect
  the REGION rather than the windows currently in it, so an
  empty or unsplit space still records what a later split opens
  at (#383/#44/#458, `SessionRatioTests`, whose cases drive
  exactly that: a change that refuses the write to silence an
  "invisible ratchet" reds them). Two obligations on
  the cue there, because the sentence it draws is a claim about
  the arrangement rather than a limit reached: it is owed on the
  FIRST press rather than whenever the clamp happens to bite,
  and `noAxisHere` says the OTHER axis divides, so a group with
  ONE member takes `nothingToDivide` instead (#1258) — the count
  is the reason there, not the arrangement, and the sentence
  says which of the two it is because the caller states whether
  the other axis divides.
  Two obligations on that judgement, both learned the same way.
  **Judge it on what the layout DREW, never on a member count**:
  a bsp region too small for two minimum-size windows piles them
  and answers to no ratio at all, which a cardinality test
  cannot see, and the extent test cannot either — the pile's
  cascade offsets each copy, so the union outgrows every slot
  and the whole pile reads as a participant. And **a refusal
  that draws nothing is a claim that nobody needed telling**, so
  every `.fail` a resize path returns is either cued or named in
  `ResizeRefusalCensusTests`' register with the reason it stays
  wordless — derived from source, because a hand-listed set of
  arms is exactly what let a fifth silent site survive the
  change that went looking for it. That census reads
  `.fail`-SHAPED refusals only, and the residue is this rule's
  own subject: a path that refuses by returning `.ok()` after a
  write nothing renders is invisible to it, which is the shape
  two of #1258's own sites now have, so `NothingToDivideCueTests`'
  per-site arms are their only net.
  A new writer of this shape states which kind of partition it
  has; `ResizeRefusalTargetingTests` holds the verdicts, one
  per arm, bsp and stack alike.
  The classification models the FIRST split of an orientation,
  which is what the shared scalar makes reachable: a deeper
  split reusing it is not separately classified, so at depth ≥
  2 a participant can still be named on the wrong side of it
  (pre-existing, and the same under-clamp the cap already
  documents).
- **A minimum pill says WHOSE floor bound — the configured
  one or the app's — and derives that ONCE** (#1261). The
  remedy differs (a setting can be lowered, an app's own
  minimum cannot), so `.ownMinimum` and `.neighborMinimum`
  carry `appBound`, carried for the SENTENCE — a consumer that
  ACTS on it owes a ruling here first; the builders in
  `KiwiCore+SizeLimitPill` answer it through the one
  `minimumIsAppBound`, from the same `effectiveMinSize` every
  clamp measured against — a floor a clamp adds beside the
  setting (the scrolling slot's `ScrollSize.minPoints`) rides
  `raisedBy`, never the verdict — and a call site never hands
  the verdict in, which `RefusalCueSeamTests` holds by spelling:
  every call site answering by hand is the #1258 shape one
  level down. The anchor's floor is the pair's verdict, since
  the anchor is the window whose floor bound; the learned
  maximum needs none, being only ever the app's. Accepted
  residue: the scrolling writer raises the verdict by the slot
  floor on BOTH domain arms, so a window drawn UNDER 100 pt
  (a `%` slot that small, `min_window_size` under 100) refused
  at an app floor under 100 reads the setting's sentence —
  wrong by name, right by remedy, and not worth a domain case.
  `ResizeRefusalAppBoundTests` builds the fixtures where the two
  terms disagree; the config-floor suites stamp the flag their
  fixtures earn.
- **A float safety NET asks `EffectiveFloat.applies`, never the
  flag alone** (#1178). `FloatingLayout` assigns no frames, so a
  `.floating` space's members are unmanaged in exactly the way a
  flag-floating window is — the bar clamp asked the flag, and
  those windows got neither a layout frame nor the correction,
  permanently. A net is a correction that places a window
  nothing else will (the clamp, the stash capture, the
  display-crossing re-anchor); a VERB is the user's own ask, and
  **a verb — or a reader that is no verb, a ring or a raise —
  the `EffectiveFloat` docstring does not name as ruled asks the
  flag until it is ruled the same way** — one at a time, that
  docstring being the one roster. The reason a verb
  crosses at all is that a
  floating-mode member has no layout answer to give and a frame
  of its own to change, so refusing it while resizing its
  flag-floating neighbour is a difference with nothing behind it
  (#1184, `FloatingResizeCommandTests`). A native-fullscreen
  focus never reaches the float route — that is the #670
  bullet's `resize` clause (#1298), and a guard inside the float
  branch alone leaves the tiled paths writing. #1286 swept the
  flag's readers (the census is the comment on the issue): the
  float-tier raise crossed — its focus guard and its FLOOR
  alike, since standing down the per-focus arm and leaving the
  switch-time arm a plane of floating-mode members is the
  one-arm trap — while the raise's TARGETS did not (no tiled
  plane to lift over); the unfocused ring asks NEITHER, reaching
  every float by owner ruling; and the Space Bar badge with its
  group-breaking stays on the flag by ruling — it marks the
  exception to a layout, and a floating-mode space has none
  (`FloatingModeRingTests`, `FloatingModeRaiseTests`,
  `SpaceBarBadgeTests`; the argument is
  `docs/design-decisions.md`'s). What the sweep leaves is a
  RULING per reader, and `FloatFlagReaderCensusTests` is the
  census that makes a new bare `.isFloating` read red until it
  is classified — identity, routed, a "tiled member" negation
  the docstring refuses, or ruled to stay, which is where
  `screenHome`'s float stand-down (#1010) went with #1362 (the
  bullet below). Nothing scans for a
  bare-flag NET beyond that count, so a new net still routes
  deliberately. **The mode arm
  names the
  space whose SCREEN the
  correction targets** — the TARGET for a move, the space a drop
  LANDED in, the RENDER space for the traveler re-home whose
  destination is that screen, the active space for a raise on a
  MEMBER, through the one `isEffectiveFloatOnActiveSpace` door
  the drop clamp shares — and a correction whose strips
  are the HOME space's passes nil for a window that is not a
  member there, or a tiled sticky traveler is clamped against a
  screen it is not on. The predicate must be the
  DECISION rather than a decoration beside a hand-spelled
  `.floating` check; `EffectiveFloatTests` holds the algebra and
  the consumer suites — `FloatingModeBarClampTests`,
  `TravelerRehomeConsumerTests`
  — hold the nets, each blind to the algebra by construction. The
  traveler re-home (#1217): `FloatingLayout` draws nothing, so a
  tiled sticky traveler rendering on a floating-mode space of
  ANOTHER display kept the frame its previous space gave it —
  `KiwiCore+TravelerRehome` moves it onto that display from the
  retile, through the one `FloatReanchor.target` and the one
  `GeometryUtils.rect(mostlyContaining:among:)` it shares with
  `screen(containing:)`, from the COMMANDED frame (never the
  in-flight echo), fitted and clamped through the render-space
  arm of the one float region (`floatBounds(on:)`, since the
  home-keyed nets never see a traveler); a
  same-display floating target moves nothing and a tiled target
  keeps the layout's placement (`TravelerRehomeTests`,
  `TravelerRehomeSeamTests`). The frame is transient by ruling:
  the next tiled space on that screen re-tiles the traveler.
- **A corner is never a float's original (#1352).** A parked
  float's capture can be lost while it still sits at the corner
  — a late echo, a relaunch, a profile switch — and the next
  stash then captured the corner as the place it belongs. So
  `stash` refuses to capture a frame that `looksStashed`, and
  `KiwiCore.recoverStrandedFloats` seeds a centred capture for
  an effective float on a shown space that has none, ahead of
  the retile whose restore delivers it — one delivery path, so
  a new way to lose the capture needs no new arm. A consumer
  asking "is this frame parked" takes the ONE instance
  `TilingEngine.looksStashed(_:)` over the `allScreenBounds`
  seam, never a screen enumeration of its own; its lift band
  is derived from `visibilityFloor` and argued in that
  docstring, the one home of the measurement. A window that
  left WITH ITS DESKTOP keeps its capture — the restore sweep
  spares every id the away ledger knows — so it comes back to
  its place, not the middle. And a `captureState` consumer
  takes `sessionSnapshot`, never `state.snapshot()`, which
  writes a parked float's corner into the session file. Held by
  `StashCornerLiftTests`, `FloatStrandRecoveryTests` (the
  decision) and `FloatStrandSeamTests` (every consumer above,
  the `captureState` wirings included).
- **A space entering floating mode gathers by REACHABILITY
  (#1177), and an entry is a change in what was DRAWN.** A
  floating layout assigns nothing, so the switch inherits the
  last layout's frames — scrolled-out columns, a parked
  monocle pile. `KiwiCore.gatherIntoFloating` seeds EVERY
  member a `QuitGridLayout` target — the exit gather's own
  function and depth, never a second grid — through the stash
  seed once any member is partly or fully outside
  `floatBounds(on:)` OR piled — its frame contained by another
  member's, the monocle stack — and nothing otherwise (owner
  rulings 2026-09-14: the visible members staying put laid the
  gathered ones behind them, and a stack piles the same); the
  pile test is containment, never overlap or z-order, and no
  previous-mode list may enter the decision (`FloatGather` is
  pure and holds the algebra).
  The JUDGMENT takes that correctness bound — a float flush
  with a bare screen edge, where no clamp pushes, is inside —
  while the GRID is laid in `floatGrowBounds(on:)`, the ring
  reserved on every edge, so the clamp has no push left to
  make on a cell flush with a strip (`FloatGatherRegionTests`);
  an UNSHOWN space paints no strips, so its grid meets the bar
  at the activation's clamp, which is the stated residue.
  `SpaceForwardingSeamTests` holds forwarding to one home by
  the Space DROP's spelling, so a copy that moves windows and
  leaves the Space alive is review's. The seed lands AHEAD of
  `recoverStrandedFloats`, which defers to a pending capture,
  so a shown corner pile takes the grid and never a second
  centring (`FloatGatherEntryTests` ▸
  `shownCornerPileTakesTheGrid` holds the order). **Two
  entry seams now exist, and an entry-time effect picks by
  what it READS**: one that reads FRAMES judges
  `drawnSpaceModes`, the mode each space was last drawn in,
  since the frames on screen are that layout's; one that seeds
  STATE (#437's track partition) judges the write in
  `setSpaceMode`; and a replay that re-states modes with no
  pass between settles the drawn ledger rather than arming it
  (`restore` → `settleDrawnSpaceModes`). So a space no pass has
  drawn (the boot's) and a snapshot replay gather nothing, and
  a config reload's reset-and-redeclare gathers nothing for
  the reason that matters — the passes between (Lua's
  `set_mode` retiles per call) leave in-region frames or kept
  captures — while a RE-FILE into a floating space IS an
  entry: a profile switch's partitioning restore and a prune's
  forwarding (#1230) each record the WINDOW they moved at the
  primitive (`refiledWindows`, never at the apply, since the
  Settings-Save deletion prunes with no switch at all), and
  the pass gathers the floating space each one SITS in — never
  a space it merely passed through, which a prune's fallback
  is when the restore moves the window on — so a member's
  frame is the layout's of the Space it came from whatever the
  receiver's own drawn mode was. A forwarding out of a dropped
  Space goes through the ONE `forwardWindows(of:to:)`, which
  the prune and `delete_space` share and which carries the
  record — `SpaceForwardingSeamTests` holds the Space drop to
  that one home, since a hand copy of the step list is how the
  delete verb shipped without it; a re-file primitive of a NEW
  shape records into the same set, and `refiledWindows`' own
  docstring is where the doors ruled OUT (the move verb, the
  away re-file) are named (`FloatGatherRepartitionTests`
  drives the doors, the receiver-only scope and the transit; a
  float parked half-off by hand beside a re-filed window is
  gathered with it, the priced trade). A member's frame
  is the one it WOULD show, `wouldBeFrame`'s four rungs, stated
  there once. And `clampFloatsClearOfBars` judges a pending
  capture rather than the state frame the window is leaving,
  correcting the capture WITH the window, or a fit of the stale
  frame lands after the restore's delivery and undoes it. A
  NEW writer of the seed states what it seeds, why it is no
  corner and where in the pass it lands, and joins
  `StashSeederCensusTests`' map, which reds an unclassified
  `seedStash(` in Core. Held by `FloatGatherTests` (the
  decision), `FloatGatherEntryTests` (the ledger, the seed, the
  order, the unshown arm), `FloatGatherRegionTests` (the two
  regions and the strip), `FloatGatherRepartitionTests` (the
  re-file arm) and `FloatClampPendingCaptureTests`.
- **A restore pays an untracked window's frame at its arrival
  (#1362).** The replay sets frames on TRACKED windows only; a
  slow app's window adopted later kept the boot scan's tile on
  the main display while its Space, a floating one on the
  other display, assigned nothing. `restore` files
  `state.restoredFrames` for every untracked id `adopt`
  remembered (a corner record is no original there either);
  the create fold consumes it ONCE into
  `AppliedEffects.restoredFrame`, and `payRestoredFrame` seeds
  it — never sets it, since the park that follows would capture
  the tile as the original — so the arrival retile's restore
  delivers it on a shown Space and the park keeps it for the
  activation; a layout frame outranks it on a tiled Space. It
  is id-keyed like `rememberedSpaces` and shares its lifetime
  and its rekey (`WindowRekeyParityTests` counts it). The
  screen-home stand-down stays on the FLAG by ruling: a
  floating-mode member returning on another display follows
  the screen — the flag travels with the window and survives a
  re-file, while floating-mode membership is the space's and is
  exactly what a re-file changes (`FloatFlagReaderCensusTests`,
  whose `ruledToStay` class is the site's census entry). Held
  by `RestoredFrameDebtTests`.
- **Derive where a float may sit in ONE place, and bound its
  SIZE there rather than its position** (#1091). `KiwiCore.floatBounds` is that derivation — the
  display's visible bounds with every PAINTED strip carved off
  its own edge — and a new consumer takes it rather than
  re-deriving a boundary beside a call site. It carves painted
  chrome rather than routing through `layoutBounds` for the
  reason `LayoutBoundsRoutingTests`' `allowed` map records
  against the float nudge: an empty bar is suppressed while
  `layoutBounds` still reserves its strip, so routing would bound
  a float out of a region no bar occupies. Fold both strip lists
  — a space shows one bar or two, on any edge — and rely on
  `AppBarGeometry.regionClear` being monotonic rather than on an
  ordering rule.
  Three obligations fall out. **Bound the SIZE there and leave
  the POSITION to the user**: the retile-time net fits an
  oversized float back inside the region, but must not enforce
  the screen edge, because it runs for every float on every
  retile and would drag back a window parked half off-screen by
  hand (`FloatRegionFitTests`; the net's own routing is
  `FloatRegionSeamTests`, since no behavioural test can see
  which entry the sweep calls). **A SIZE ask that an app can
  refuse owes a memo** — that net runs every retile, and unlike
  a position, a size is genuinely refusable, so an app whose
  minimum exceeds the region is re-asked forever without one;
  `FloatFitLedger` is #677's shape one subsystem over, and it is
  deliberately NOT an entry in `SizeBoundLearner`, which only
  the layout loop may record into. And **a resize that cannot
  deliver its whole ask owes a cue** — blocked or merely
  TRUNCATED, which is #933's own rule at the other end and was
  missing on the grow side; route it through `cueResizeRefusal`
  like every other (input-and-animation.md's funnel rule), which
  is also what ends a held glide at the wall instead of pilling
  per frame.
  The keyboard resize itself is symmetric with pinned edges, and
  **the pinning binds shrink as well as grow** — pin only on grow
  and grow/shrink stops being reversible at exactly the edge
  people park windows against. `FloatSymmetricResizeTests` holds
  the reversibility table, the both-pinned refusal and the
  accepted contact residue at half a step; the product argument
  is `docs/design-decisions.md`'s.
- An **explicit settings apply must `retile(pass: .apply)`**. The
  engine's "already there" tolerance (±2 pt per edge) absorbs
  AX-echo lag and app-side clamping; un-forced, it swallows a
  small config edit entirely (a 1 pt gap edit visibly did
  nothing). Every retile triggered by an explicit `set_*` from
  Lua/CLI applies — `applyProfileScopedState`, `set_gap_*`,
  `set_min_window_size`, `set_mode`, the whole `layoutCommand`
  dispatch. Event-driven retiles stay on the `.event` default so
  echo lag can't wobble windows. Profile applies classify
  themselves: see [profiles.md](profiles.md). **A Space or
  Desktop activation takes `retile(pass: .reissue)`, never
  `.apply`** (#1488): an apply is also the probe past
  corroborated bounds (#1055), under which the automatic track
  count and every heal stand down, so a switch that forced
  redrew the count's overlap on every return. `.reissue`
  re-issues every frame and probes nothing; a new caller that
  activates a Space and is not an explicit apply takes it, and
  every site that spells either case is pinned with its reason
  in `RetilePassRoutingTests`' `allowed` map — the one copy of
  who chooses what (`SpaceSwitchReissueTests`,
  `RetileBoundSkipTests` ▸ `reissueIssuesTheBound`).
- **A resize nobody asked for is corrected on its own event
  (#1358)** — the `.windowResized` arm's outcomes are four and a
  new arm keeps them so: our ask's ECHO goes to the #677 answer
  channel, a LATE echo the ledger explains is left alone, a hand
  GESTURE goes to the drag pipeline, and what is none of those
  (a title-bar zoom, an edge double-click's expand, an app
  re-sizing itself) to `KiwiCore.correctUnsolicitedResize`. That
  door retiles only where the window is off the frame a SHOWN
  space gives it, and asks the owners rather than copying them:
  `calculatedFrames` for a tiled slot (every display's shown
  space, beyond `retileTolerance`), `floatFitCorrection` — the
  bar sweep's own per-window verdict, one copy for both — for a
  float. It stands down while `defersEventRetiles` holds (#672)
  and past `UnsolicitedResizeMemo`'s bound, since a correction
  wipes the #677 ledger and an app reverting past the echo grace
  would otherwise be corrected forever. The gesture reading
  refuses a press whose `clickCount` is 2 unless `drag.hasGesture`
  already holds that window — asked FIRST, so the verdict does
  not ride the release's main-actor hop — because an edge
  double-click is the one OS resize that looks like a fast
  drag's trailing event from inside; `recordDown` takes the
  count with no default and both monitor arms pass the event's
  (`OwnPressProvenanceSeamTests`). `UnsolicitedResizeTests`
  drives the arm; its echo control asserts on the log, since the
  #677 channel retiles on its own and a frame sink cannot tell
  the two apart; a secondary display's shown space is placed by
  the same frame set and is not pinned, since every fake display
  resolves to the one host screen.

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
