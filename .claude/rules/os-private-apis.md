---
paths:
  - "Sources/KiwiDeskCore/OS/**"
  - "**/SkyLight*.swift"
  # Not an AX rule: this one file holds the sanctioned
  # `@_silgen_name`, so the carve-out below has to arrive with the
  # rule it excepts. `accessibility.md` is silent on it, so a
  # reviewer loading only that file would see neither. Pinned to
  # the file, not `AX/**`, which would tell every AX editor that
  # private window-server rules bind their file. `InstructionPinTests`
  # fails if the pin stops resolving.
  - "Sources/KiwiDeskCore/AX/AXHelper.swift"
---

# OS layer — private SkyLight/CGS APIs

Canonical for this subsystem (AGENTS.md §5 indexes it). When
editing here:

- Resolve private SkyLight/CGS symbols at runtime via `dlsym`
  (`SkyLight.swift`). **Never** link them with `@_silgen_name` — a
  linked symbol that disappears in a macOS update crashes the app
  at launch; a failed `dlsym` lookup returns nil and falls back.
- One symbol is exempt, and the exemption does not generalise:
  `_AXUIElementGetWindow`, linked with `@_silgen_name` in
  `AX/AXHelper.swift`. It is a stable Accessibility symbol, not
  SkyLight/CGS — the crash argument above is about the private
  window-server surface, which churns across releases. Do not read
  it as licence for a second linked symbol, and do not "fix" this
  one to `dlsym`.
- **Every** private fast path must have a public-API fallback
  (`AXUIElement`). No fallback = not acceptable — with one
  carve-out, which is not a loophole: where macOS exposes a
  capability ONLY through the private surface, there is no
  fallback to write, and the code **refuses** rather than
  synthesizing a substitute (`KiwiCore+DesktopCommands.swift`
  refuses when `canDriveDesktops` is false; faking Mission
  Control keystrokes was the rejected substitute). Absent is
  allowed; faked is not. `docs/design-decisions.md` ▸ *The
  window-management bridge is not a SIP escape hatch* argues
  which private surfaces may be adopted at all.
- Never disable SIP, and never ask the user to.

## The WMBridge operation classes (#884/#889)

SkyLight's `SLSBridged*Operation` classes are an ObjC surface,
not C symbols, so the `dlsym` discipline extends to them as
class lookup. Present on macOS 26.6.1 (25G76, observed
2026-08-18); no earlier build has been probed, so no doc names a
cutoff — the nil lookup IS the version gate (#889 item 8).
Every one of the following binds whoever touches them:

- Resolve a class by name at runtime, `NSClassFromString`
  after the framework's `dlopen`, and treat a nil lookup as
  **the capability being absent** — every entry point answers
  nil or false, none traps, and a result object that no longer
  declares the key being read answers nil too (`WMBridgeTests`
  ▸ `absentCapabilityDegrades`, `missingKeyDegrades`; #889
  item 8 proved the nil on device against three fake names
  with the real class as the control). Never declare the class
  in Swift or ObjC to link against it.
- Reach the bridge ONLY through `WMBridge`
  (`OS/WMBridge*.swift`). The bridge's strings —
  `WMBridgeSeamTests`' needles, the class prefix and the
  dispatch selector among them — are each spelled once, in the
  wrapper's core file, which that suite pins by exact count
  across both source trees; a full class name anywhere else is
  a hit, because the wrapper joins the prefix to short
  operation names at lookup.
- **Performed is not applied.** An asynchronous operation
  returns void; a synchronous one returns a result object even
  when the WindowServer silently declined — edge reservation
  performed under every mask and moved nothing (#889 item 6),
  and `CopyManagedDisplaysOperation` performs and answers nil
  (26.6.1, observed 2026-08-25). A caller verifies a write by a
  re-query or by state it owns, and never by the wrapper's
  return value. The census the re-query reads stays
  `NativeSpaces`' — one reader of the display/spaces model.
- **Multi-membership is not available: `AddWindowsToSpaces`
  performs and applies NOTHING (#1145).** Device-probed
  2026-09-01 on macOS 26.6.2 — our own window and a foreign
  app's, every argument shape (`NSArray` of `NSNumber`, `NSSet`),
  against every non-current Desktop — and verified against the
  compositor's own on-screen census (`CGWindowListCopyWindowInfo`
  plus `SLSGetActiveSpace`): the operation reports performed
  every time and the window is present only on the Desktop it
  physically lives on. #889 item 5's "visual truth test" that
  read as working was the #1023 gesture-compositing artifact —
  both Desktops render at once for ~1 s of a swipe — and a
  pointer-write switch does not reproduce it; the same item's
  finding that `CopySpacesForWindows` never reports a second
  Desktop still stands, and is now explained rather than a lie.
  So a caller asserts no second membership and keeps no ledger
  of one; the wrapper's `addWindows`, `removeWindows` and
  `spaces(for:)` stay as the re-probe surface with no
  production caller, and a new call site reds in
  `WMBridgeSeamTests`' per-file spelling map. **The MOVE
  (`MoveWindowsToManagedSpace`) is the one membership write
  applied cross-app** — `move_to_desktop` ships on it, and
  sticky reach CARRIES on it at each Desktop switch
  ([state-and-layout.md](state-and-layout.md)). A future macOS
  that applies the ADD earns a re-probe with the census as the
  witness, never a re-read of item 5.
- **The per-Desktop window list is one `dlsym` symbol, read
  through one builder, reached through one seam (#1146).**
  `SLSCopyWindowsWithOptionsAndTags` (`SkyLight+WindowCensus.swift`,
  whose docstring carries the option semantics and the device
  measurement — read them there, never restate them) answers
  which windows a native Space hosts from a foreign connection.
  `NativeSpaces.desktopCensus(spaces:)` is the one builder,
  intersecting the per-Desktop lists with the layer-0 owner map
  `AXHelper.allNormalWindowOwners()` reads; a production
  consumer reads it ONLY through `DesktopMemory.readCensus`, the
  one door a test pins too (`DesktopCensusSeamTests`, whose
  `testCorePinsBothDoors` holds that `makeTestCore` pins it and
  the per-window `readWindowSpace` to "no compositor"), because
  the builder reads the host's WindowServer under a suite. **Nil is absent, never
  faked**: a consumer answers a nil census with its pre-#1146
  behavior (`AwayLedgerTests` ▸ `noCensusIsNoVerdict`,
  `AwayBootSeedTests` ▸ `noCensusSeedsNothing`,
  `LifecycleReasonTests`' `.unknown` clauses), and a new
  consumer owes that clause. Two readings that must not be
  confused: **"gone" is the SPACE LIST being empty**
  (`SLSCopySpacesForWindows` answering `[]`, or the id on no
  Desktop's list) — never absence from
  `CGWindowListCopyWindowInfo(.optionAll)`, for the reason on
  `allNormalWindowOwners`' docstring. And the census is
  downstream of the removal: the sweep never reads it
  ([accessibility.md](accessibility.md)).
- **The space-pointer write performs no transition (#1023).**
  `ManagedDisplaySetCurrentSpaceOperation` moves the pointer and
  composites the target's windows, but never hides the origin's
  — both Desktops render at once until a genuine gesture
  completes the swap, while EVERY pointer read
  (`SLSGetActiveSpace`, `SLSManagedDisplayGetCurrentSpace`, the
  managed-display plist) reports the switch landed within
  ~120 ms, so no re-query on this surface can see the difference
  (device-measured 2026-08-26, macOS 26.6.2, both displays, both
  a Dock-hidden and a bridge-hidden target). A switching caller
  therefore pairs an ACCEPTED set with
  `WMBridge.hideSpaces([origin])`, origin read from the same
  snapshot that resolved the target — set-then-hide measured as
  a complete switch — and the deferred pointer re-query verifies
  only that the set was not dropped (`DesktopCommandTests`,
  `DesktopSwitchGuardTests`).
  The bare C `SLSShowSpaces`/`SLSHideSpaces` are silent no-ops
  from a foreign process; the bridged operations are not.
- A bridge-driven Desktop switch reaches KiwiDesk through the
  SAME `NSWorkspace` notification a swipe does — observed on
  device 2026-08-25, `focus_desktop` producing the target
  Desktop's window census — but that notification fires on the
  POINTER moving, which can precede the moved window's
  composite, so its reconcile may run before the window is
  listable (device-traced 2026-08-26, the "ignored until
  minimized" report: the adoption heal then quiets the id as a
  permanent mismatch). A verb that moved a window somewhere
  hidden therefore owns its own bookkeeping either way: the
  no-follow `move_to_desktop` reaps the window it sent away,
  stamps the switch window so the removal reads as `vanished`,
  and stamps the move latch (`DesktopCommandTests`); the FOLLOW
  folds the departure eagerly — state AND the event loop's
  element registration, or every later reconcile treats the
  window as already known — and arms a reveal reap the heal's
  quieting cannot gate (`DesktopSwitchGuardTests`). The #1023
  bullet's deferred re-query stays a drop diagnostic that only
  logs.
- The bridge dispatches only while **AppKit is genuinely
  loaded** (#884's bisection): free in the app, binding on
  every harness — under `swift test` every bare read answers
  the deaf false and `isAvailable` caches it for the process.
  So a test reaches `WMBridge` only through
  `classResolverOverride` (`WMBridgeSeamTests` ▸
  `testsReachTheBridgeThroughTheSeam` refuses a test file that
  spells `WMBridge.` without it), and a CONSUMER in `Sources/`
  reads the bridge at a wiring site listed in that suite's
  `allowed` map — a stored value the GUI consumes, never a read
  inside a view `body` — so a GUI suite rendering the view
  cannot reach the live bridge through it unseen. Proving the
  bridge on a device means a standalone binary with AppKit
  genuinely linked (#889's recipe); the repo carries no script
  for it.
- `WMBridge.isAvailable` is the capability predicate a GUI
  gate reads — true only when a synchronous read ANSWERS, not
  merely when the class resolves (`WMBridgeTests` ▸
  `availabilityNeedsAnAnsweringDelegate`); what a gated surface
  does with a false is `gui.md`'s.
- A custom key written into a Desktop's store leaves under
  `WMBridge.valueKeyPrefix`, which the wrapper applies itself
  to the BARE key a caller passes and strips again in
  `stamps(of:)` (`WMBridgeTests` ▸ `storeKeysAreNamespaced`,
  `stampsRoundTrip`) — the store is Apple's own dictionary
  (#889 item 3). The prefix is a STORED value the WindowServer
  persists (item 3 again), so §5's crossing rule binds it: a
  change to the string owes a one-shot re-stamp of every
  Desktop carrying the old one, never a reader lenient to both.
- **A Desktop's value dictionary IS a record macOS persists**,
  and that — not the bridge — is what makes an identity stamp
  work (#1147, measured on the owner's Mac 2026-09-03, two
  unplug/replug rounds). A key written through
  `SpaceSetValuesOperation` lands in
  `~/Library/Preferences/com.apple.spaces.plist` beside Apple's
  own `id64`, `type`, `uuid` and `wsid`, and macOS round-trips
  keys it does not recognise. Three consequences, each measured
  rather than reasoned:
  - the stamp survives logout, reboot and an OS update (the
    2026-08-18 canary, still on Desktop 1 sixteen days later);
  - it survives an unplug, which APPENDS a screen's surviving
    Desktops to the remaining one at new numbers, containers
    intact;
  - it survives the replug REBUILD. The first Desktop of an
    unplugged screen fuses into the current one and its
    container dies; on reconnect macOS mints a **new `id64`**
    and restores the archived record — our key included — onto
    it (1452 → 1454 → 1456 across two rounds). **So `id64` is a
    runtime handle, never an identity**, and a durable map must
    not key by it.

  What this leans on is undocumented: that macOS keeps unknown
  keys in that record rather than filtering them. Write no code
  that would break if it stopped. As of #1147 nothing does: a
  Desktop that comes back unstamped is marked unstampable for the
  session and every consumer falls back to its Mission Control
  number, which is the pre-#1147 behaviour.
  Degrading to the status quo is the design's answer here;
  keep it that way.

  Apple's own `uuid` is persisted identically and IS stable, and
  is still not usable: it is `SpaceCopyName` — the Desktop's
  name — so naming a Desktop would move it, and it is EMPTY on
  the primordial Desktop. Never write it.
- No Accessibility trust is needed for any bridge operation
  (#889 item 2); do not add a permission prompt for one.
