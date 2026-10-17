import AppKit
import Testing

@testable import KiwiDeskCore

/// The layout picker (#762, #2229): the key panel's Layouts scope,
/// opened through the GUI hook for the Space under the pointer,
/// read from the Layout menu's own drift and applied as its rows
/// apply.
@Suite("Layout picker (#762)")
@MainActor
struct LayoutPickerTests {
    private func makeCore() -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("3")
        core.state.workspaces.activate("3")
        core.state.workspaces.setMode("3", .grid)
        return core
    }

    @Test("the picker reads the Space's live layout")
    func stateReadsTheSpace() throws {
        let core = makeCore()
        let state = try #require(core.layoutPickerState(for: "3"))
        #expect(state.space == "3")
        #expect(state.live == .grid)
        #expect(core.layoutPickerState(for: "nope") == nil)
        // A Space not shown answers for itself, not the active one.
        core.state.workspaces.ensureSpace("4")
        core.state.workspaces.setMode("4", .monocle)
        #expect(core.layoutPickerState(for: "4")?.live == .monocle)
    }

    @Test("a pick sets the Space's layout")
    func pickSetsTheLayout() {
        let core = makeCore()
        core.applyLayout(.monocle, to: "3")
        #expect(core.state.workspaces[SpaceID("3")]?.mode == .monocle)
    }

    /// The pointer names the screen, the screen names the Space:
    /// on a desk of two, the one under the pointer, not the
    /// focused one. A point on the seam belongs to the upper
    /// screen, as every other pointer reader decides.
    @Test("the screen under the pointer names the Space")
    func pointerPicksTheScreen() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let below = CGRect(x: 0, y: -800, width: 1000, height: 800)
        let screens = [
            (frame: left, id: DisplayID(1)),
            (frame: right, id: DisplayID(2)),
            (frame: below, id: DisplayID(3)),
        ]
        #expect(
            KiwiCore.display(at: CGPoint(x: 1500, y: 400), among: screens)
                == DisplayID(2)
        )
        #expect(
            KiwiCore.display(at: CGPoint(x: 500, y: 0), among: screens)
                == DisplayID(1)
        )
        #expect(
            KiwiCore.display(at: CGPoint(x: 5000, y: 0), among: screens)
                == nil
        )
    }
}
