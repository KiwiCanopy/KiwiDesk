import AppKit

@testable import KiwiDesk

/// Build a `StatusItemController` that never touches the real
/// menu bar.
///
/// The production initializer's default factory calls
/// `NSStatusBar.system.statusItem(...)` — a live, user-visible
/// menu bar slot per constructed controller, and a grep of the
/// test tree for `NSStatusBar` finds nothing because the touch
/// happens inside the production initializer. A run that
/// constructs controllers bare was observed leaving a blank
/// menu-bar slot with WindowServer at 42–46% CPU for the whole
/// run (15 live items).
///
/// Shared rather than per-file on the `TestCore.swift` ground
/// (`.claude/rules/tests.md`): *omission*, not divergence. Every
/// copy of `{ nil }` is identically harmless, but one forgotten
/// argument in a new suite re-enables the dangerous production
/// default. `MachineTouchTests` pins every test-tree construction
/// to this file.
@MainActor
func makeTestStatusItemController() -> StatusItemController {
    StatusItemController(makeStatusItem: { nil })
}
