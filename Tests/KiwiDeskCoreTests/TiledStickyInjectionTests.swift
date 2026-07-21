import Foundation
import Testing

@testable import KiwiDeskCore

/// #414 v2: derived home-index injection of tiled-sticky
/// windows into the active space's member lists.
@Suite("Tiled-sticky injection", .serialized)
struct TiledStickyInjectionTests {

    private func makeWindow(
        _ id: UInt32,
        isFloating: Bool = false,
        isSticky: Bool = false
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "App",
            title: "Title",
            isFloating: isFloating,
            isSticky: isSticky
        )
    }

    /// space1 (active) gets local tiled 1...count; the sticky
    /// window `stickyID` homes on space2 behind `before` tiled
    /// siblings, so its home tiled index is `before`.
    private func makeState(
        locals: Int,
        stickyID: UInt32,
        homeSiblingsBefore before: Int
    ) -> StateCoordinator {
        var state = StateCoordinator()
        state.workspaces.ensureSpace("1")
        state.workspaces.ensureSpace("2")
        state.workspaces.activate("1")
        for id in 1...UInt32(locals) {
            state.windows.upsert(makeWindow(id))
            state.workspaces.add(WindowID(id), to: "1")
        }
        for offset in 0..<before {
            let id = 100 + UInt32(offset)
            state.windows.upsert(makeWindow(id))
            state.workspaces.add(WindowID(id), to: "2")
        }
        state.windows.upsert(
            makeWindow(stickyID, isSticky: true)
        )
        state.workspaces.add(WindowID(stickyID), to: "2")
        return state
    }

    @Test("Injection lands at the home tiled index")
    func injectsAtHomeIndex() {
        let state = makeState(
            locals: 3,
            stickyID: 50,
            homeSiblingsBefore: 2
        )
        guard let s1 = state.workspaces["1"] else {
            Issue.record("Expected space")
            return
        }
        let tiled = state.effectiveTiledMembers(
            of: s1,
            activeSpace: "1"
        )
        #expect(
            tiled == [
                WindowID(1), WindowID(2), WindowID(50),
                WindowID(3),
            ]
        )
    }

    @Test("A home index past the target count appends")
    func clampsToTargetCount() {
        let state = makeState(
            locals: 1,
            stickyID: 50,
            homeSiblingsBefore: 4
        )
        guard let s1 = state.workspaces["1"] else {
            Issue.record("Expected space")
            return
        }
        let tiled = state.effectiveTiledMembers(
            of: s1,
            activeSpace: "1"
        )
        #expect(tiled == [WindowID(1), WindowID(50)])
    }

    @Test("Multiple stickies insert in stable (index, id) order")
    func multipleStickiesStableOrder() {
        var state = StateCoordinator()
        state.workspaces.ensureSpace("1")
        state.workspaces.ensureSpace("2")
        state.workspaces.ensureSpace("3")
        state.workspaces.activate("1")
        state.windows.upsert(makeWindow(1))
        state.workspaces.add(WindowID(1), to: "1")
        // Two stickies, both first tiled member of their homes:
        // equal home index 0, so id breaks the tie.
        state.windows.upsert(makeWindow(30, isSticky: true))
        state.workspaces.add(WindowID(30), to: "3")
        state.windows.upsert(makeWindow(20, isSticky: true))
        state.workspaces.add(WindowID(20), to: "2")
        guard let s1 = state.workspaces["1"] else {
            Issue.record("Expected space")
            return
        }
        let tiled = state.effectiveTiledMembers(
            of: s1,
            activeSpace: "1"
        )
        // Both derive home index 0; equal-index travelers keep
        // ascending id order (reversed insertion in
        // `effectiveTiledMembers`).
        #expect(
            tiled == [WindowID(20), WindowID(30), WindowID(1)]
        )
    }

    @Test("The sticky's own home space injects nothing extra")
    func homeSpaceStaysLocal() {
        var state = StateCoordinator()
        state.workspaces.ensureSpace("1")
        state.workspaces.ensureSpace("2")
        state.workspaces.activate("2")
        state.windows.upsert(makeWindow(1))
        state.workspaces.add(WindowID(1), to: "1")
        state.windows.upsert(makeWindow(2, isSticky: true))
        state.workspaces.add(WindowID(2), to: "2")
        guard let s2 = state.workspaces["2"] else {
            Issue.record("Expected space")
            return
        }
        let tiled = state.effectiveTiledMembers(
            of: s2,
            activeSpace: "2"
        )
        #expect(tiled == [WindowID(2)])
    }

    @Test("localTiledMembers never injects")
    func localDerivationStaysLocal() {
        let state = makeState(
            locals: 2,
            stickyID: 50,
            homeSiblingsBefore: 0
        )
        guard let s1 = state.workspaces["1"] else {
            Issue.record("Expected space")
            return
        }
        #expect(
            state.localTiledMembers(of: s1)
                == [WindowID(1), WindowID(2)]
        )
    }

    @Test("Bar members place a tiled traveler at its slot")
    func effectiveMembersMatchInjectedPosition() {
        var state = StateCoordinator()
        state.workspaces.ensureSpace("1")
        state.workspaces.ensureSpace("2")
        state.workspaces.activate("1")
        // Active space: float 9 between tiled 1 and 2. The
        // traveler (home tiled index 1) tiles between locals 1
        // and 2; the float keeps its flat-array position.
        state.windows.upsert(makeWindow(1))
        state.windows.upsert(makeWindow(9, isFloating: true))
        state.windows.upsert(makeWindow(2))
        state.workspaces.add(WindowID(1), to: "1")
        state.workspaces.add(WindowID(9), to: "1")
        state.workspaces.add(WindowID(2), to: "1")
        state.windows.upsert(makeWindow(100))
        state.workspaces.add(WindowID(100), to: "2")
        state.windows.upsert(makeWindow(50, isSticky: true))
        state.workspaces.add(WindowID(50), to: "2")
        guard let s1 = state.workspaces["1"] else {
            Issue.record("Expected space")
            return
        }
        #expect(
            state.effectiveTiledMembers(of: s1, activeSpace: "1")
                == [WindowID(1), WindowID(50), WindowID(2)]
        )
        #expect(
            state.effectiveMembers(of: s1, activeSpace: "1")
                == [
                    WindowID(1), WindowID(9), WindowID(50),
                    WindowID(2),
                ]
        )
    }
}
