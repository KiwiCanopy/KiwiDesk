---
paths:
  - "Sources/KiwiDeskCore/AX/**"
  - "Sources/KiwiDeskCore/Events/EventLoop+BootScan.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+AppObservation.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+Reconcile.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+ReconcileAll.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+RemovalDistrust.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+Tabs.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+Heal.swift"
  - "Sources/KiwiDeskCore/Events/EventLoop+WindowPolicy.swift"
  - "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
---

# Accessibility (AX) bridge

Canonical for this subsystem (AGENTS.md §5 indexes it). When
editing AX code:

- AX calls are slow and can block. Never call them inside tight
  loops or layout math — snapshot state first, then compute.
- Electron/WebKit apps answer AX queries lazily (100–300 ms).
  `AXEnhancedUserInterface` is set to `true` on managed apps to
  keep their AX tree warm; do not remove it without a replacement.
- `AXObserver` callbacks arrive on the run loop of the thread that
  registered them; keep observer registration on the main thread.
- **Register the OWN process's observer in the event-tracking
  mode as well as the default one, and never widen it to
  `.commonModes` (#953).** Those callbacks arrive on OUR run
  loop whichever app they are about, so a source registered in
  `.defaultMode` alone is deaf while that run loop runs a
  tracking loop. For a third-party app that costs nothing — its
  gestures run a tracking loop in ITS process while ours is
  idle. Our own window's live resize or move runs one in THIS
  process, for exactly the seconds the gesture exists, so the
  tiled Settings window resized with no `windowResized` ever
  reaching the drag pipeline and its neighbours never moved.
  That AppKit runs a live frame resize in
  `NSEventTrackingRunLoopMode` is a macOS observation no guard
  can hold — seen working on macOS 26.6.2, 2026-08-24, on the
  narrowed two-mode shape. It is what stands between this and a
  silent return to #953: a source added to the common modes
  would join any mode AppKit tracks in later, and the named
  pair would not, with only the symptom to say so. Re-verify a
  drag on device when this registration changes.
  Two obligations, one guard each:
  - The widening stays the own process's alone
    (`OwnWindowGestureDeliveryTests`) — every other observer
    keeps the default mode, or a third-party AX storm re-enters
    our own menu and slider tracking loops.
  - **The add and the remove iterate one stored list, and no
    registration site names a mode of its own**
    (`ObserverRunLoopModeSeamTests`). Getting the CHOICE right
    guards nothing on its own: hardcoding the default mode back
    at the `CFRunLoopAddSource` call restores the whole defect
    with the chooser still correct (guard-prover, 2026-08-24),
    and an add and a remove covering different modes leave the
    source installed past `invalidate()`, which nothing
    observes.

  Name the two modes rather than taking `.commonModes`: the
  common set additionally carries `NSModalPanelRunLoopMode`,
  which delivers own-pid callbacks — the create fold included —
  inside every `runModal()` session, with the action that
  opened the panel still suspended on the stack. Reading
  `isOwnProcess` here is not the per-window widening
  [input-and-animation.md](input-and-animation.md) bans: a run
  loop mode is a property of this process's main run loop,
  which every own window shares, and what each of them then
  does with a delivered notification is still decided per
  window, by the mark. The press half of the same defect is
  that file's.
- **Keep the boot's process-global AX messaging timeout.**
  `EventLoop.beginScan()` bounds every AX message at ~1 s
  (`AXHelper.setGlobalMessagingTimeout`) before its first
  per-app call — without the bound, an unresponsive app costs
  the ~6 s system default per call, and the scan's serial
  main-thread calls turned one stopped helper into a ~60 s boot
  (#672). `StartupAXTimeoutTests` pins the wiring and the
  value. Red-prove the stall itself on-device (`kill -STOP` any
  GUI app, then boot), never with a real SIGSTOP in CI —
  tests.md's hang-guard rule.
- **Boot may not hold the main actor, and one app may not spend
  the whole budget (#801/#803).** The scan's AX calls are serial
  and blocking, so it runs as a queue drained a chunk at a time
  (`EventLoop+BootScan`) with the run loop handed back in
  between — that run loop is what serves the menu-bar item and
  the ⌃⌥K panel, and an accessory app the user can see must
  answer. Three obligations fall on a change here. **A new pass
  over every app takes the chunked path** rather than a bare loop:
  the startup sweep already did this to itself once, blocking
  5285 ms one second after boot and re-breaking the menu the scan
  had just freed. **A pass that budgets drains the deferral
  ledger in its own epilogue** — the sweep budgeted and did not,
  so an app it cut short sat there until `stop()` discarded it,
  abandoned to #675's heal, which is the outcome deferral exists
  to spare it. And **any abort added inside `reconcile` returns
  before `reconcileTabsAndSweep`** — that sweep derives destroys
  from the live list, so a mid-read exit with the sweep still
  running untracks every window the abort never reached.
  `BootScanChunkTests` pins the queue and its once-only epilogue;
  `BootAppBudgetTests` pins the per-app bound, the abort-before
  -sweep pair, and the scoping that matters most: the budget is
  raised for a queued STEP, never for the pass, because the run
  loop is live between chunks and an activation reconcile or a
  Desktop-switch `reconcileAll` landing inside a pass must never
  be cut short. The budget's value is argued on
  `EventLoop.bootAppBudget` against the band in this file's
  second bullet and `EventLoop.axMessagingTimeoutSeconds`; read
  it there rather than quoting a number here. What the user
  is told while this runs is `BootPhase`'s (#802), and the
  publications no test can drive are needled by
  `BootPhaseWiringTests`.
- **Never assume an installed observer delivers (#675).**
  `AXObserverAddNotification` can refuse a fresh-launch app whose
  AX tree is not ready, and the refusal used to be discarded —
  the observer then sat installed and deaf (no `windowCreated`,
  no `focusedWindowChanged`) while its non-nil `observers[pid]`
  entry blocked any re-attach, which is how a Spotlight-launched
  app's windows were never adopted. `AXApplicationObserver`
  records the failed adds; every reconcile touchpoint and the
  adoption-heal sweep call `repairRegistration()`, and the sweep
  (`EventLoop.healSweep`) is the pass *guaranteed* to come —
  census-gated so a healthy tick costs one WindowServer snapshot
  and no AX. `AdoptionHealTests` pins the gate and both repair
  funnels; `AdoptionHealScheduleTests` pins the scheduled tasks.
  Nothing machine-checks that the boot tail (`finishBoot`, in
  `KiwiCore+Boot`) still calls `scheduleAdoptionHeal()`, so do
  not drop or re-time that call without adding the pin and
  re-deriving the `docs/accepted-limitations.md` heal-latency
  row. The sibling link below is no longer in that state —
  `StartupSweepWiringTests` needles it — and pinning this one
  takes the same shape: a needle anchored to `finishBoot`'s own
  closing brace, since the tail is not test-drivable but a call
  MOVED out of it heals nothing.
- **A bulk pass asks the WindowServer before it asks AX
  (#1037).** `reconcileAll` — the Desktop-switch re-sync and the
  config reload's — reads one on-screen census and skips an
  observed app that tracks no window and shows none: it has
  nothing to remove and nothing to adopt, and if it is not
  servicing AX (App-Napped with its windows on other Desktops, a
  headless agent) the list read costs the whole messaging
  timeout. Device-traced 2026-08-26: eight such apps × ~1 s, in
  series, on EVERY switch — an empty target Desktop included —
  with the arrived window's ring, retile and raise queued behind
  them. The gate skips whole apps and never cuts a reconcile
  short, so the abort-before-sweep obligation above is
  untouched. What the census cannot see at the notification is a
  window still compositing (the #1023 measurement), so the
  Desktop settle sweeps arrivals — `reconcileOnScreenArrivals`,
  the heal's gate WITHOUT its quieting ledger, because quieting a
  window whose app has not re-listed it yet is what left the
  #1023 window unmanaged. A bulk pass reads the gate through
  `EventLoop.reconcileAllTargets` rather than re-deriving it,
  and `ReconcileAllPrefilterTests` pins the gate's verdicts,
  `reconcileAll`'s reading of it, the sweep's three arms and
  the settle's call — not who calls `reconcileAll`, which the
  suite enters directly. A new bulk pass over every observed
  app takes the gate too, or argues on its own doc why it must
  read a silent app: `beginSweep` is the one that does, because
  its warm is the #662 promise and the boot prefilter it
  answers counts windows on EVERY Desktop. The follow's own
  700 ms reap (`departEagerly`) and this sweep both adopt the
  followed window ungated; each doc names the other.
- **A hidden app contributes NO live windows, and the read is
  `appIsHidden` rather than anything in the AX list (#913).**
  ⌘H — and an app hiding itself as its last window closes,
  which is Discord's red X — leaves every window in `kAXWindows`,
  un-minimized, at its last frame, and sends no AX notification
  at all (probed on device 2026-08-21, macOS 26.6.2), so a
  reconcile that only reads the window list keeps tiling windows
  nobody can see. Four obligations.

  **The drop reaches the sweep with an empty `live`** — the one
  path in `reconcile` that does so without reading the window
  list, which does not weaken the abort-before-sweep rule
  above, because an abort holds a PARTIAL list while "hidden"
  is a total answer about the app. **Adoption refuses a hidden
  app at `track`**, the one door every caller comes through —
  attach's scan, reconcile's sweep, and the created and
  deminiaturized arms — because a rule enforced at three of
  four doors is not a rule; a new adoption site takes that door
  rather than restating the refusal beside itself. **A hidden
  app is still WARMED** though never adopted: #662's promise is
  that a following reconcile warms what attach skipped, and
  both hidden paths return before that warm, so an app hidden
  across boot would meet its first unhide with a cold AX tree —
  which for an Electron app is an empty window list. And **the
  drop reports `.windowHidden`, never a destroy**: the window
  was not closed, so the public `window_destroyed` reason must
  not say it was, and the close-return raise must stand down
  rather than race the frontmost app macOS itself picks
  (`HiddenAppRaiseTests` holds the event classification; since
  #935 the hide is one arm of
  `EventLoop.closeReturnRaiseStandsDown(after:)`, whose raise
  site `CloseReturnStandDownWiringTests` pins — a needle,
  because that site is gated on live AX).

  Do not re-base the drop on the WindowServer's on-screen
  census: it omits a window on another Desktop exactly as
  readily, so it would untrack every window parked on a Desktop
  the user is not standing on (`docs/design-decisions.md`
  ▸ *A hidden app holds no tiles* argues the choice). Note too
  that the backstops differ by direction — `healSweep`'s gate
  opens on that same on-screen census, so it can only ever
  catch a missed UNHIDE, while a missed hide is caught by
  `appActivated`'s reconcile of the app just left.

  **A hidden app's windows are not counted alike everywhere,
  and that is deliberate.** `KiwiCore.readAppWindowCensus`
  (`Commands/KiwiCore+LaunchRestore.swift`) counts them as UP,
  and its docstring argues why at length for #673: it answers
  "what will `activate()` bring back", where a hidden app's
  windows are exactly what is about to reappear, while this
  bullet answers "what occupies a tile", where they are not.
  Do not route Open-or-Focus through `appIsHidden` to make the
  two agree — that re-breaks #673.

  `HiddenAppWindowTests` pins the drop, its `.windowHidden`
  reporting, the warm-while-hidden, the hide/unhide arm and its
  observer guard. The `track` refusal is pinned in
  `HiddenAppTrackNeedleTests` (`SourceScan`), because no behavior
  test can reach it without live AX.
  What `HiddenAppWindowTests` cannot reach is the pair of
  workspace notifications that fire that arm at all: it drives
  the arm directly, with `registersWorkspaceObservers` off so no
  live observer outlives the test, and stays green if either
  registration is deleted. Keep those pinned in
  `HideObserverWiringTests`.
- **A sweep removal distrusts one missing AX read while the
  WindowServer still shows the window (#1157).** Under fast
  focus churn a lazy-AX app transiently UNDER-reports its
  window list — the #913 defect's mirror image — and the sweep
  took that absence as a close: a never-closed window lost its
  slot, close-return raise and all, until the ~20 s adoption
  heal re-tracked it (log-proven, 2026-08-31). So a non-hidden,
  non-minimized close candidate is checked against ONE
  on-screen census before its destroy is emitted, and a listed
  window is refused. The asymmetry is the rule: **the census
  may REFUSE a removal, never cause one** — a listed window is
  composited on the current Desktop, so it exists, while an
  unlisted one may merely be on another Desktop, which is
  exactly why #913 bars the census from the hide drop. Keep the
  hide drop AND `detach` census-free — each is a total answer
  about the app, not an inference from one missing read (the
  hide arm is pinned; `detach`'s routing is review's, since the
  gate lives in the sweep it never reaches). One
  continuous-absence episode
  (`removalDistrusted`) logs once and queues BOUNDED follow-up
  reconciles on the distrust's own one-shot — never the
  transient-retrack slot, whose part-spent deadline a refusal
  must not ride, and with `coalesceTabs: false` on the drain
  (#308's safe direction) — so a TRUE close still compositing
  at sweep time converges instead of polling. The re-queue
  bound is argued on `EventLoop.removalRecheckCap`, the delay
  on `KiwiCore.transientRetrackDelay`. The gate also stands
  down inside the Desktop-switch grace, where the census is
  double-exposed (#1023) and would refuse every departed
  window. Residue, accepted — and recorded in
  `docs/accepted-limitations.md` in the same change set: the
  census is layer-0 only, so a raised-layer window keeps the
  pre-gate behavior; an under-reported window the census also
  omits is still lost to the heal; a FLAPPING list re-opens the
  episode per flap, so the log line recurs while the reconcile
  cost coalesces; and a census that kept listing a truly closed
  window would keep its tile silently past the first line — the
  census is trusted as ground truth. `RemovalDistrustTests`
  pins the refusal, the exempt arms, the switch-grace
  stand-down, the episode ledger, the one-census cost and the
  convergence.
- **The startup scan may skip the AX warmup only for an app the
  WindowServer reports windowless, and only because a following
  reconcile warms whatever was skipped (#662).** Four links
  carry that promise, and all four are pinned now: the skip
  gate and the reconcile-warms retry by
  `StartupWarmupSkipTests`, the scheduled sweep's task actually
  opening its pass and reconciling by `StartupSweepTests`, the
  boot tail still *calling* `scheduleStartupSweep()` by
  `StartupSweepWiringTests` — which #836 added, having made a
  second skip rest on the same call — and the boot queue's own
  admission (`EventLoop.bootPassAdmits`, pinned by
  `BootScanEligibilityTests`): an app dropped at queue build is
  never warmed by the sweep either, so the admission must stay
  exactly "can never attach", which no warm is owed. Re-timing is still yours to
  weigh: the needle sees the call, never the latency, so re-time
  it only alongside the ceiling `docs/accepted-limitations.md`
  accepts for the user-visible residue. **Re-timing includes
  making the sweep
  take longer**: it is chunked now (#801), so the last app in
  its queue is warmed at 1 s plus the sweep's own duration
  rather than at 1 s — and a sweep-budgeted app later still.
