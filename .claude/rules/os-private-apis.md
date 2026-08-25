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
  re-query or by state it owns — sticky membership in
  particular, because `CopySpacesForWindows` never reports a
  second Desktop (#889 item 5) — and never by the wrapper's
  return value. The census the re-query reads stays
  `NativeSpaces`' — one reader of the display/spaces model.
- A bridge-driven Desktop switch reaches KiwiDesk through the
  SAME `NSWorkspace` notification a swipe does — observed on
  device 2026-08-25, `focus_desktop` producing the target
  Desktop's window census — so a caller arms no confirmation of
  its own. A caller with NO such signal owns its own
  bookkeeping: the no-follow `move_to_desktop` reaps the window
  it sent away, stamps the switch window so the removal reads
  as `vanished`, and stamps the move latch
  (`DesktopCommandTests`).
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
- No Accessibility trust is needed for any bridge operation
  (#889 item 2); do not add a permission prompt for one.
