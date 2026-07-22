import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Per-display active-space model (#multi-monitor): each display
/// shows its own space at once, and switching focus to one
/// display never hides another's space. Pure `WorkspaceManager`
/// state — no AX / screen needed.
@Suite("Multi-monitor per-display active space")
struct MultiMonitorSpaceTests {
    private let displayA = DisplayID(1)
    private let displayB = DisplayID(2)

    /// Two displays: spaces 1–2 on A, space 5 on B — the
    /// reported "main + secondary" layout.
    private func twoMonitorState() -> WorkspaceManager {
        var w = WorkspaceManager()
        w.upsertDisplay(
            Display(
                id: displayA,
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        w.upsertDisplay(
            Display(
                id: displayB,
                name: "B",
                frame: CGRect(
                    x: 1920,
                    y: 0,
                    width: 1920,
                    height: 1080
                )
            )
        )
        w.ensureSpace(SpaceID("1"))
        w.ensureSpace(SpaceID("2"))
        w.ensureSpace(SpaceID("5"))
        w.assign(SpaceID("1"), to: displayA)
        w.assign(SpaceID("2"), to: displayA)
        w.assign(SpaceID("5"), to: displayB)
        w.activate(SpaceID("1"))
        return w
    }

    @Test("Each display shows its own active space")
    func perDisplayActive() {
        let w = twoMonitorState()
        // Focused display A shows the focused active space; B
        // falls back to its only assigned space.
        #expect(w.activeSpace == SpaceID("1"))
        #expect(w.activeSpace(on: displayA) == SpaceID("1"))
        #expect(w.activeSpace(on: displayB) == SpaceID("5"))
    }

    @Test("Both displays' spaces are visible at once")
    func bothVisible() {
        let w = twoMonitorState()
        // The bug: only one space rendered. Now space 5 is
        // visible on B without any user action.
        #expect(
            w.visibleSpaces == Set([SpaceID("1"), SpaceID("5")])
        )
    }

    @Test("Activating B's space preserves A's shown space")
    func focusOtherDisplayKeepsThis() {
        var w = twoMonitorState()
        // Switch A to space 2, then focus B's space 5.
        w.activate(SpaceID("2"))
        w.activate(SpaceID("5"))
        // Focus moved to B; A keeps showing space 2 (not stashed).
        #expect(w.activeSpace == SpaceID("5"))
        #expect(w.activeSpace(on: displayA) == SpaceID("2"))
        #expect(w.activeSpace(on: displayB) == SpaceID("5"))
        #expect(
            w.visibleSpaces == Set([SpaceID("2"), SpaceID("5")])
        )
    }

    @Test("Focus can move back and forth between displays")
    func focusRoundTrip() {
        var w = twoMonitorState()
        w.activate(SpaceID("2"))  // A -> space 2 (same display)
        w.activate(SpaceID("5"))  // focus to B
        w.activate(SpaceID("2"))  // focus back to A
        #expect(w.activeSpace == SpaceID("2"))
        // B still remembers it was showing space 5.
        #expect(w.activeSpace(on: displayB) == SpaceID("5"))
        #expect(
            w.visibleSpaces == Set([SpaceID("2"), SpaceID("5")])
        )
    }

    @Test("Same-display switch does not touch the other display")
    func sameDisplaySwitch() {
        var w = twoMonitorState()
        w.activate(SpaceID("2"))
        // Only A's shown space changed; B untouched.
        #expect(w.activeSpace(on: displayA) == SpaceID("2"))
        #expect(w.activeSpace(on: displayB) == SpaceID("5"))
    }

    @Test("Single monitor keeps the one-active-space behavior")
    func singleMonitorUnchanged() {
        var w = WorkspaceManager()
        w.upsertDisplay(
            Display(
                id: displayA,
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        w.ensureSpace(SpaceID("1"))
        w.ensureSpace(SpaceID("2"))
        w.assign(SpaceID("1"), to: displayA)
        w.assign(SpaceID("2"), to: displayA)
        w.activate(SpaceID("1"))
        #expect(w.visibleSpaces == Set([SpaceID("1")]))
        w.activate(SpaceID("2"))
        // One monitor: switching replaces the single visible space.
        #expect(w.visibleSpaces == Set([SpaceID("2")]))
        #expect(w.activeSpace == SpaceID("2"))
    }

    @Test("No displays yet: visibleSpaces is just the active one")
    func noDisplaysBootstrap() {
        var w = WorkspaceManager()
        w.ensureSpace(SpaceID("1"))
        w.activate(SpaceID("1"))
        #expect(w.visibleSpaces == Set([SpaceID("1")]))
    }

    @Test("Removing a display drops its secondary-shown entry")
    func removeDisplayClears() {
        var w = twoMonitorState()
        w.activate(SpaceID("2"))
        w.activate(SpaceID("5"))  // A parked as secondary
        w.activate(SpaceID("2"))  // B parked as secondary
        w.removeDisplay(displayB)
        // B is gone; only A's space is visible.
        #expect(w.visibleSpaces == Set([SpaceID("2")]))
    }

    @Test("Removing a shown space clears its secondary entry")
    func removeShownSpaceClears() {
        var w = twoMonitorState()
        w.activate(SpaceID("2"))
        w.activate(SpaceID("5"))  // A parked showing space 2
        w.removeSpace(SpaceID("2"))
        // A falls back to its first remaining assigned space (1).
        #expect(w.activeSpace(on: displayA) == SpaceID("1"))
    }

    @Test("Reassigning a shown space never lays it on two displays")
    func reassignDoesNotDoubleShow() {
        var w = twoMonitorState()
        w.activate(SpaceID("2"))
        w.activate(SpaceID("5"))  // A parked showing space 2
        // Space 2 is now moved to display B (profile / topology
        // reassign). A's stale secondary pick at 2 must not keep
        // showing it — 2 lives on B now.
        w.assign(SpaceID("2"), to: displayB)
        #expect(w.activeSpace(on: displayA) == SpaceID("1"))
        #expect(w.activeSpace(on: displayB) == SpaceID("5"))
        // No space is claimed by two displays at once.
        let a = w.activeSpace(on: displayA)
        let b = w.activeSpace(on: displayB)
        #expect(a != b)
    }
}
