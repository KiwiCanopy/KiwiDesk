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
  (`AXUIElement`). No fallback = not acceptable.
- Never disable SIP, and never ask the user to.

## The WMBridge operation classes (macOS 26+, #884/#889)

SkyLight's `SLSBridged*Operation` classes are an ObjC surface,
not C symbols, so the `dlsym` discipline extends to them as
class lookup — and every one of the following is an obligation
on whoever touches them:

- Resolve a class by name at runtime, `NSClassFromString`
  after the framework's `dlopen`, and treat a nil lookup as
  **the capability being absent** — every entry point answers
  nil or false, none traps (#889 item 8 proved the nil against
  three fake names with the real class as the control). Never
  declare the class in Swift or ObjC to link against it.
- Reach the bridge ONLY through `WMBridge`
  (`OS/WMBridge*.swift`). The `SLSBridged` prefix, the
  `performWithWMBridgeDelegate` selector and `NSClassFromString`
  itself are each spelled once, in its core file, which
  `WMBridgeSeamTests` pins by exact count across both source
  trees — a full class name anywhere else is a hit, because the
  wrapper joins the prefix to short operation names at lookup.
- **Performed is not applied.** An asynchronous operation
  returns void; a synchronous one returns a result object even
  when the WindowServer silently declined (edge reservation
  performed under every mask and moved nothing;
  `CopyManagedDisplaysOperation` performs and answers nil). A
  caller verifies a write by a re-query or by state it owns —
  sticky membership in particular, because
  `CopySpacesForWindows` never reports a second Desktop
  (#889 item 5) — and never by the wrapper's return value.
- The bridge dispatches only while **AppKit is genuinely
  loaded** (#884's bisection): free in the app, binding on
  every harness. A test reaches `WMBridge` through
  `classResolverOverride` and never the live bridge
  (`WMBridgeTests`); a device check compiles the wrapper's
  files into a standalone binary that touches AppKit first.
- A GUI surface offering a bridge feature gates on
  `WMBridge.isAvailable` — which requires a synchronous read to
  ANSWER, not merely the class to resolve — and greys with a
  reason when it is false (gui.md's grey-don't-hide).
- No Accessibility trust is needed for any bridge operation
  (#889 item 2); do not add a permission prompt for one.
