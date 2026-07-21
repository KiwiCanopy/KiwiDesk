import Foundation
import Testing

@testable import KiwiDeskCore

/// #431: a tiled-sticky traveler is injected into the active
/// space's scrolling row but can never be its membership-guarded
/// `focused` slot, so `scrollAnchor` lets a focus-driven layout
/// still pan to it while it is the frontmost window.
@Suite("Scrolling sticky anchor", .serialized)
struct ScrollingStickyAnchorTests {

    private func makeWindow(
        _ id: UInt32,
        isSticky: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            isSticky: isSticky
        )
    }

    /// space1 (active) holds locals 1...`locals`; a sticky window
    /// homes on space2 as its first tiled member, so it travels
    /// into space1's row.
    private func makeState(locals: Int) -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.ensureSpace("1")
        state.workspaces.ensureSpace("2")
        state.workspaces.activate("1")
        for id in 1...UInt32(locals) {
            state.windows.upsert(makeWindow(id))
            state.workspaces.add(WindowID(id), to: "1")
        }
        state.windows.upsert(makeWindow(50, isSticky: true))
        state.workspaces.add(WindowID(50), to: "2")
        return state
    }

    private func anchor(
        _ state: StateCoordinator
    ) -> WindowID? {
        guard let s1 = state.workspaces["1"] else {
            Issue.record("Expected space")
            return nil
        }
        let tiled = state.effectiveTiledMembers(
            of: s1,
            activeSpace: "1"
        )
        return state.scrollAnchor(of: s1, tiled: tiled)
    }

    @Test("A frontmost traveler becomes the pan anchor")
    func travelerAnchorsWhenFrontmost() {
        var state = makeState(locals: 3)
        state.workspaces.focus(WindowID(1), in: "1")
        // Focusing the traveler lands on its HOME space (the
        // guard passes there) and sets `lastFocused` to it, but
        // never touches space1's `focused` slot.
        state.workspaces.focus(WindowID(50), in: "2")
        #expect(state.workspaces["1"]?.focused == WindowID(1))
        #expect(anchor(state) == WindowID(50))
    }

    @Test("Focusing a local member reverts the anchor")
    func localFocusRevertsAnchor() {
        var state = makeState(locals: 3)
        state.workspaces.focus(WindowID(50), in: "2")
        // A later local focus makes it the frontmost window, so
        // the anchor drops back to the space's own slot.
        state.workspaces.focus(WindowID(2), in: "1")
        #expect(anchor(state) == WindowID(2))
    }

    @Test("A non-traveler last-focus never anchors")
    func unrelatedLastFocusIgnored() {
        // `lastFocused` on an inactive space that owns no
        // traveler for space1 must not steal its anchor.
        var state = makeState(locals: 2)
        state.windows.upsert(makeWindow(99))
        state.workspaces.add(WindowID(99), to: "2")
        state.workspaces.focus(WindowID(1), in: "1")
        state.workspaces.focus(WindowID(99), in: "2")
        #expect(anchor(state) == WindowID(1))
    }

    @Test("No focus yields no anchor")
    func emptyFocusYieldsNil() {
        let state = makeState(locals: 2)
        #expect(anchor(state) == nil)
    }
}
