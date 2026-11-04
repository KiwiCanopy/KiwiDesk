---
paths:
  - "Sources/KiwiDeskCore/Keys/**"
  - "Sources/KiwiDeskCore/Events/**"
  - "Sources/KiwiDeskCore/Animation/**"
  - "Sources/KiwiDeskCore/OS/HyperKeyRemap*.swift"
  - "Sources/KiwiDeskCore/Tiling/FrameApplier.swift"
  - "Sources/KiwiDeskCore/Tiling/FrameApplier+Hold.swift"
  - "Sources/KiwiDeskCore/Commands/KiwiCore+SpaceSlide.swift"
  - "Sources/KiwiDeskCore/Commands/KiwiCore+SpaceTransition.swift"
---

# Input & animation

Canonical for this subsystem (AGENTS.md §5 indexes it). When
editing here:

- Hotkeys use the **Carbon API** (`RegisterEventHotKey`); the one
  keyboard tap is the side tap below (`docs/design-decisions.md` ▸
  *Left and right modifiers are told apart by one keyboard tap*).
  Mouse presses are read through `NSEvent` monitors.
- **A menu row drawing a Carbon-bound chord drops only that
  chord's own keyDown, asked of the one `KeyCombo.isCarbonTwin`**
  — Carbon's hotkey already acted, and every other keyboard
  firing, Return on an arrow-picked row, is the row's (#2869). The
  bar menus and the status item read it through an injected
  keyDown defaulting to `KeyCombo.menuKeyDown`, never a check of
  their own (`CarbonTwinSeamTests` ▸ `callersAreNamed`, whose
  map a new caller joins; `BarMenuChordTests`,
  `QuickMenuHubRowTests` ▸ `hubRowOpens` for the behaviour).
- **The running hotkey table is written only from saved files.**
  A new writer — a caller of `applyStructuredKeybindings`, of
  `KeybindingManager.replaceLayers`, or of `keys.bind` /
  `defineLayer` / `reset` — reads what is on disk, and joins
  `ShortcutsApplyOnSaveTests`' census with that source named.
  No Settings control registers a hotkey ahead of Save: a chord
  in effect but not saved outlives the window that shows it and
  dies at the restart (design-decisions ▸ "The recorder stages
  like every control"). The recorder's suspend (#213) is the one
  live touch, and it resumes the saved table.
- **Hover focus is armed by USER pointer motion alone (#1869),
  held by two safeguards that both stay.** The `PointerRest` dwell
  starts on a global mouse-moved event, and KiwiDesk moves the
  pointer with a bare `CGWarpMouseCursorPosition`, which posts none
  — a change that synthesizes a mouse event (a moved event after
  the warp, to refresh apps' hover states, is the common one)
  arms the rest from our own move, and owes a stamp the rest
  refuses first (`HoverFocusWiringTests` ▸ `warpPostsNoMotion`).
  And a rest carries the focus its user move ARMED with — a re-arm
  for motion the monitor did not hear keeps it — and stands down
  when the focus has moved since, which is what keeps a warp
  landing inside a dwell from looping (`PointerRestTests` ▸
  `reArmKeepsTheArmedFocus`, `HoverFocusStandDownTests` ▸
  `movedFocusStands`). And after a focus the pointer did not make,
  the windows it is left over are held until a move leaves them,
  read from state frames on the move (`PointerRest.held`,
  `HoverFocusHoldTests`). A new trigger for hover focus is a user
  event too, never a reading of where the pointer IS.
  While KiwiDesk is active, the local monitor hears the pointer
  leave Settings only because that window accepts mouse-moved
  events (#2381), and the flag breaks SwiftUI hover in a popover
  over it (#2501). So the flag is written by `SettingsWindow`'s
  derivation alone — off while a window hangs from it, which
  stands hover focus down out of Settings for that while, as
  KiwiHub does (#2378) — and never beside it
  (`SettingsWindowMouseMovesTests`).
- **Scroll gestures take the ONE active scroll-wheel tap,
  `ScrollGestureTap`, reached only through `MouseTracker.scroll`
  (#1656, #1519).** Its creation asks macOS for the
  Accessibility-class `PostEvent` service alone, never
  `ListenEvent` (tccd log, device build, 2026-09-28). Seven
  obligations:
  - **One tap, scroll-only.** A mask widened past `.scrollWheel`
    asks macOS for more than the gesture needs; the only other tap
    is the side tap below (`ScrollTapSeamTests` for one tap per
    file and each one mask constant, `ScrollSampleTests` for the
    scroll constant's value).
  - **The tap installs on its own thread and decides there.**
    Every scroll on the Mac waits on the callback, and the main
    actor can block on a slow app's AX reply for seconds; the
    decision is the pure `ScrollGestureRouter`'s, and consumers
    hear it on the main queue (`ScrollTapSeamTests` for the
    thread, `ScrollGestureRouterTests` for the decision).
  - **A consumer's timing reads `ScrollGestureEvent.time`**, the
    tap's clock the router stamps, never a main-actor clock,
    which a busy switch compresses into a burst (#1519;
    `ScrollGestureRouterTests` ▸ `stampsTheClock`).
  - **A step on a row layout goes through `navigate`, never a
    layout helper beside it** (#1656): a helper's `nil` means
    "not mine, fall through", and read as a wall it strands a
    floating focus the arrow keys would carry to the float tier
    (`ScrollGestureDeadEndTests` ▸ `floatFocusFollowsTheKeys`).
    The #292 preflight in `execute` is skipped on purpose — the
    gesture acts on the Space under the pointer — which the
    pan's docstring states.
  - **A plain scroll is never consumed**: `ScrollGestureSettings`
    drops an empty chord, the router never owns one whatever it
    is handed, and a chord matches exactly
    (`ScrollGesturesTests`, `ScrollGestureRouterTests`).
  - **Key chords by CONSUMER, and set them through the one
    `configure` door** — handlers are wired once with
    `setHandler`: a profile switch can hand the two gestures each
    other's chords, and one resolved settings value lands both;
    and no tap exists while no wired consumer has a chord, the
    live factory pinned inert in both `makeTestCore` twins
    (`ScrollGesturesTests`, `ScrollTapSeamTests`).
  - **Resolve the settings in ONE home,
    `KiwiCore.applyScrollGestures`, the one caller of the front's
    door `ScrollGestures.adoptResolution`** (#1656): the global base with
    the live profile's override on top, run through
    `ScrollGestureBase.sanitized` — the verdict the Settings
    entry reads too — since a hand-edited file reaches what the
    recorder refuses. A path that changes either input reaches
    the tap by calling it; the one deferred writer is the config
    load's `resetInputs`, whose load configures at its tail. The
    inputs stay `private(set)`, and a `ScrollGestureSettings` is
    built only through `tapSettings`, read by the door alone, or
    a path hands the tap a value that skipped the override
    (`ScrollGestureConfigureSeamTests`).
- **Left and right modifiers take ONE keyboard tap,
  `ModifierSideTap`, owned by `KeybindingManager` (#2601).**
  The tap answers only the chords a sided row names, the
  either-side row on such a chord included, and only while
  `modifierSides` is on; every other shortcut stays a Carbon
  hotkey (`ModifierSideRoutingTests` ▸ `onRoutes`). Obligations:
  - **No sided row, no tap.** `armSideTap` stops it with its last
    row; a new path that routes rows to it goes through
    `tappedChords`, never a row list of its own
    (`ModifierSideRoutingTests` ▸ `onWithoutSidesHasNoTap`).
  - **A refused tap hands its chords back to Carbon** either-side
    and is asked again only when the switch moves or at
    `KiwiCore.start()`, the grant's door
    (`ModifierSideRoutingTests` ▸ `refusedTapFallsBack`).
  - **A suspended manager answers nothing** — `deactivate` empties
    the rows, or the tap swallows the sided press the recorder
    reads (`ModifierSideRoutingTests` ▸ `offStopsTheTap`).
  - **Key-down only, on its own thread**, deciding from the rows
    `setRows` handed it and passing every press no row answers;
    the live factory is pinned inert in both `makeTestCore`
    twins (`ScrollTapSeamTests` ▸ `installsOffMain`,
    `keyboardMask`, `liveFactoryPinned`).
  - **Carbon reads a sided chord either-side**: `carbonMask` and
    `KeyCombo.registered` strip the side bits
    (`ModifierSideComboTests` ▸ `carbonReadsEitherSide`,
    `registeredIsEitherSide`), so the
    switch off fires every sided shortcut through Carbon and a
    collapsing pair is refused as a duplicate
    (`ModifierSideRoutingTests` ▸ `offCollapses`) and named a
    `sideCollapse` conflict (`ModifierSideConflictTests`).
- **A keypad digit is the same key as its number-row twin
  (#1074), and `KeypadKeys` is the one place that says so.** Both
  readers come to it — hotkey registration and `KeyCombo.keyName`
  — so never re-derive the relation beside a call site. Keep the
  aliased set **closed to the ten digits**; register a twin only
  once the authored key has LANDED, or the keypad keeps firing a
  binding the Settings caption calls ungranted; and never report
  a twin's own refusal, which is not the binding's. The argument
  for each of those is `docs/design-decisions.md` ▸ "The keypad's
  ten digits ARE their number-row twins" — do not restate it here
  (`KeypadKeysTests`).
- **The Hyper remap's ownership record is minted only by
  `HyperKeyRemap`'s set or the user's explicit take-over (#2471),
  never inferred from a mapping's shape** — Caps Lock → F18 is a
  common Hammerspoon setup, so a writer judging by shape would
  claim and later clear another tool's entry. A take-over re-reads
  the mapping at the click and answers through the ordinary
  `apply` when it changed, and whether a mapping is offered is
  Core's `claimable` verdict, never a key comparison in the GUI
  (`HyperRemapRecordWriterCensusTests`, `HyperKeyTakeOverTests`,
  `HyperTakeOverOfferTests`).
- **A chord's admissibility is `SystemShortcuts.map`'s to state,
  never prose's (#1075).** That map is the one derivation the
  conflict ring and the Settings keyboard board already share
  (`KeyboardCensus.reservedKeys`), so a modifier base newly
  opened to bindings adds that base's reserved chords THERE in
  the same change — `⌥⌘` did, when size took it. **Enumerate a
  base by reading `com.apple.symbolichotkeys`, not from
  reputation, and date what you read:** `⌥⌘`'s Zoom trio (`8`,
  `-`, `=`) ships gated on an Accessibility setting and OFF,
  which is precisely how a reputation-based list misses it, and
  `RegisterEventHotKey` ACCEPTS a chord macOS holds — a refusal
  (`eventHotKeyExistsErr`) is intra-process only — and an
  enabled symbolic hotkey is then answered by macOS before the
  binding hears the press, with nothing said (#1126, measured
  2026-09-03). The product ruling is
  `docs/design-decisions.md` ▸ "Size is not a positional verb"
  (`SizeLayerSeedTests`).
- **KiwiDesk's own windows are discriminated per WINDOW, never
  per process (#678 item 18).** `shouldForceFloat`'s own-process
  arm reads the tiling mark
  (`OwnWindowTiling.identifier`, through the
  `ownWindowIdentifier` seam) rather than floating everything
  the app itself opened: the Settings window tiles, and the
  tour and the Config Issues window do not. So **never widen
  that arm back to a bare `isOwnProcess(pid)`** — the two
  windows the mark separates want opposite fates, and the
  polarity is what keeps the failure cheap: an own window is
  chrome unless marked, so forgetting the mark costs a stray
  float, never a chrome window taking a layout slot. The
  census of which own window is which lives on
  `OwnWindowTiling` — cite it, do not re-list it, since a new
  own window falsifies every copy and reds none of them.
  Two guards, reading different halves:
  `SelfWindowExclusionTests.forceFloatConsultsTheMark` injects
  the seam and pins that the verdict follows it (the flag is
  otherwise unobservable, so a call site that stops consulting
  it reds nowhere else), and `OwnWindowTilingSeamTests`' map is
  the one copy of who may stamp the mark. The product argument
  is in `docs/design-decisions.md`; the GUI half of it, in
  [gui.md](gui.md).
- **A held resize chord glides through one tally, one refusal
  funnel and one release channel (#1056, retimed #1082).** Three
  obligations, each with the same failure mode — the feature
  silently stops meaning what it claims while every fake-driven
  suite stays green — and one guard suite,
  `HoldGlideEligibilitySeamTests`:
  - Every command a hotkey fire runs reaches the hold engine
    through the ONE `KiwiCore.execute` wrapper. Eligibility is
    "what the press DID", so a second `dispatchCommand` caller
    runs commands the tally never sees; the suite pins the
    single call site. Since #1082 that wrapper also carries the
    ARGUMENTS, because the glide re-issues the press's own
    `resize` rather than re-running the binding.
  - A new size-limit refusal cue routes through
    `cueResizeRefusal` (`KiwiCore+SizeLimitPill.swift`) — the
    funnel is what ends a held run, so a cue beside it pills
    once per FRAME instead of once per hold. The suite holds
    every `refuse*` function to the funnel and the funnel as
    the one `borders.onResizeRefusal` caller.
    **A hold can also end with no refusal, through
    `KeybindingManager.endGlide` (#2709):** only for a glide step
    that would push a window into a run, or that meets a weight's
    limit above the floor, each of which is no limit the window
    has. Anything else that stops a window routes through the
    funnel.
    **Since #1258 the funnel also DRAWS, bumps and sounds**, so
    a new refusal adds a CASE and a sentence, never a body: the
    case carries what the drawing decides from (its axis, its
    discriminators), `ResizeRefusal+Rendering` maps case →
    glyph, sentence and the paired second pill, and a `refuse*`
    function names a case and nothing else. The shape earns its
    keep by making a wrong choice READABLE — a sentence chosen
    inside a `refuse*` body was a wrong CALL rather than a wrong
    value, which no test could see, and five review rounds each
    found one. So a discriminator added to a case owes an
    assertion on BOTH its values; `NothingToDivideCueTests` and
    `RefusalCueSeamTests` (▸ the funnel never sounds ahead of
    its drawing) are where those live. The gate on that
    funnel is `isFiring || isGliding`, not `isFiring` alone: a
    glide runs outside any binding fire, so dropping the second
    term makes the cue unreachable exactly where the hold needs
    it (`HoldGlideRefusalWiringTests`).
  - The engine arms only when its registrar conforms to
    `HotkeyReleaseReporting` — a hold with no stop channel
    must never start — so a wrapper or replacement registrar
    that drops the conformance turns the feature off with no
    red anywhere else; the suite pins the production default's
    conformance. **The arm additionally refuses when the press's
    own registration did not survive its fire** (#1082): a body
    that calls `bind` mints fresh ids, so no release for the
    pressed id will ever arrive. The repeat ladder caught that
    one layer down, because a tick looked its registration up in
    order to re-fire the binding; the glide looks nothing up, so
    the question is asked at the arm or nowhere
    (`HoldGlideWiringTests`). A run is also bounded by
    `HoldGlide.maxRunSeconds` against a lost release event —
    the #611 force-settle shape, reported through the
    manager's log seam, never silent (the overrun-to-log
    wiring is pinned by `HoldGlideWiringTests`, since the
    seam defaults silent and every machine harness assigns it
    by hand). That bound is spent in SIMULATED frame time,
    accumulated from frames actually delivered, so a starved
    main queue cannot age a hold it never ticked — the same
    idiom the #611 bullet below states for the animation
    watchdog. It differs from that bullet in owing a SECOND
    net: the watchdog's clock is the animation's own
    integration, while the glide's is a `DisplayLink` bound to
    one `NSScreen`, which display sleep or a disconnect
    mid-hold simply STOPS. So a wall-clock backstop of the same
    length sits under the frame bound — a net must not depend
    on the thing that died — and it can never truncate a
    healthy glide, since frame time is at most wall time
    (`HoldGlideRunTests` ▸ `wallClockBackstopEndsAFrozenGlide`).
    Keep both, or the primary is unreachable in exactly the
    failure it exists for.

  **The glide's two seams are INVERTED, and take the two-sided
  guard** (`HoldGlideSeamTests`): `applyGlideStep` and
  `startFrames` default inert on `HoldGlide` and are opted into
  live by `KiwiCore+HoldGlide`, because a live default would
  build a `CADisplayLink` on a real screen in every suite that
  arms a hold. The inert default is a working no-op rather than
  a crash, so a deleted wiring is the silent direction — which
  is tests.md's inverted-seam rule, and the reason both needles
  are pinned by exact count rather than by "no strays". The two
  are not equally exposed, and that suite's docstring is the one
  copy of which is which: state the asymmetry there when you
  change either seam, rather than averaging the two into one
  claim here.

  **A glide's writes are INSTANT, on every resize path** (#1082,
  extended to the floating one by #1090). The bit a write
  consults is `HoldGlide.isApplyingGlideStep` (read as
  `keys.isApplyingGlideStep`), set around ONE re-issued command
  and cleared on every exit — never `keys.isGliding`, which is
  the hold's lifetime and answers the per-write question wrongly
  in both directions: an unrelated Lua/CLI/IPC resize arriving
  during a hold would lose its animation, and a hold whose frame
  clock dies would leave the bit stuck on for the session. Who
  may read that scope is pinned by count
  (`HoldGlideSeamTests`), because a reader in the resize command
  file inherits two behaviours at once — write instantly, AND
  stand per-frame work down. Springing a glide frame smooths an
  already-smooth signal and generates the #611 retarget storm
  below deliberately — a changed target every frame is what the
  watchdog cannot tell from a long drag — so writing instantly is
  a safety property, not only feel.

  **What each path measures from is what made this conditional,
  and the floating one needed a record built for it.** A tiled
  path writes a stored ratio, weight or length and re-derives
  geometry from it, so an instant write leaves the next frame's
  base exact. `resizeFloating` measures from a FRAME, and its
  only commanded base was the in-flight animation's target
  (#129/#1056) — which an instant write does not create, and
  which `AnimationEngine.animate` never creates at all under
  Reduce Motion, with animations off, or with the engine
  disabled, since it opens `guard isEnabled, !reduceMotion()`.
  That is why Reduce Motion was the configuration where the
  FLOATING path was worst: at glide rate most frames re-based on
  the same stale echo and 71% of a held resize was lost
  (measured, #1090).

  So a floating write now records what it commanded, in
  `GlideCommandedBase` on the animation engine — beside the
  target it stands in for, so a caller asks ONE accessor
  (`commandedFrame(window:includingHeldGlide:)`) rather than
  branching on which store holds the answer. **A commanded base
  stored here must be BOUNDED at both ends of its life, and the
  two bounds do different jobs — keep both.** Only a glide STEP
  may read it, which is what stops a press measuring from another
  press's record (the #1057 objection that refused the #881
  instant stamp as this base). And it is CLEARED at the start of
  every physical press, which is what stops a record an unrelated
  earlier press left behind being read by a later hold that
  reaches the same window.

  **Hang that clear off the PRESS, never off the glide's end.**
  `onGlideEnd` fires only for a run that actually glided, so a
  tap's record would stand forever; and on the refusal path it
  fires synchronously from inside the command that then records
  (`refuseShrinkAtMinimum` → `noteRefusal` → `cancelRun`), so a
  held shrink parked on a floor clears before the write it meant
  to undo. `HoldGlide.onFireBegan` is the seam, pinned by count
  from both sides in `FloatGlideSeamTests` ▸
  `fireBeginSeamClearsTheFloatingBase`, with the sequence driven
  end to end in `FloatGlideAccumulationTests` ▸ `A stale record
  from an earlier press is not read`. That same suite carries
  the headless net for the INSTANT WRITE — a floating write that
  re-decides its animation beside the call site instead of
  taking `resizeWritesAnimated` reds exactly one assertion in
  the whole tree, and that one is display-gated, so the routing
  is pinned by a source scan as well (guard-prover, 2026-08-29).
  One ruled narrowing: an aspect-locked float's press writes
  instantly too, since a locked app fits each spring step into its
  box and lands short (#2973, `FloatAspectJudgementTests` ▸
  `lockedPressIsInstant`). A new resize
  