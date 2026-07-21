import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Effective tiled members parity", .serialized)
struct TiledMembersParityTests {

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

    @Test("Tiled members match old space filter for pure tiled setup")
    func pureTiledParity() {
        var state = StateCoordinator()
        let spaceID = SpaceID("1")
        state.workspaces.ensureSpace(spaceID)
        state.workspaces.activate(spaceID)

        let w1 = makeWindow(1)
        let w2 = makeWindow(2)
        state.windows.upsert(w1)
        state.windows.upsert(w2)
        state.workspaces.add(WindowID(1), to: spaceID)
        state.workspaces.add(WindowID(2), to: spaceID)

        guard let space = state.workspaces[spaceID] else {
            Issue.record("Expected space to exist")
            return
        }

        let oldDerivation = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let helperOutput = state.effectiveTiledMembers(
            of: space,
            activeSpace: spaceID
        )

        #expect(helperOutput == oldDerivation)
        #expect(helperOutput == [WindowID(1), WindowID(2)])
    }

    @Test("Tiled members exclude floating windows like per-site filter")
    func mixedFloatingParity() {
        var state = StateCoordinator()
        let spaceID = SpaceID("1")
        state.workspaces.ensureSpace(spaceID)
        state.workspaces.activate(spaceID)

        let w1 = makeWindow(1, isFloating: false)
        let w2 = makeWindow(2, isFloating: true)
        let w3 = makeWindow(3, isFloating: false)
        state.windows.upsert(w1)
        state.windows.upsert(w2)
        state.windows.upsert(w3)
        state.workspaces.add(WindowID(1), to: spaceID)
        state.workspaces.add(WindowID(2), to: spaceID)
        state.workspaces.add(WindowID(3), to: spaceID)

        guard let space = state.workspaces[spaceID] else {
            Issue.record("Expected space to exist")
            return
        }

        let oldDerivation = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let helperOutput = state.effectiveTiledMembers(
            of: space,
            activeSpace: spaceID
        )

        #expect(helperOutput == oldDerivation)
        #expect(helperOutput == [WindowID(1), WindowID(3)])
    }

    @Test("Tiled members never inject a tiled-sticky homed elsewhere")
    func tiledStickyStaysHomeForLayout() {
        var state = StateCoordinator()
        let space1 = SpaceID("1")
        let space2 = SpaceID("2")
        state.workspaces.ensureSpace(space1)
        state.workspaces.ensureSpace(space2)
        state.workspaces.activate(space1)

        // A TILED sticky window (isFloating: false) homed on the
        // inactive space2 — the reachable v1 state a `!isFloating`
        // predicate does NOT filter out.
        let w1 = makeWindow(1, isFloating: false)
        let wSticky = makeWindow(2, isFloating: false, isSticky: true)
        state.windows.upsert(w1)
        state.windows.upsert(wSticky)
        state.workspaces.add(WindowID(1), to: space1)
        state.workspaces.add(WindowID(2), to: space2)

        guard let s1 = state.workspaces[space1],
            let s2 = state.workspaces[space2]
        else {
            Issue.record("Expected spaces to exist")
            return
        }

        // Active space1: the traveler must NOT join the tiled
        // layout (its glyph travels, its tile stays home in v1).
        let s1Old = s1.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let s1Tiled = state.effectiveTiledMembers(
            of: s1,
            activeSpace: space1
        )
        #expect(s1Tiled == s1Old)
        #expect(s1Tiled == [WindowID(1)])

        // Inactive home space2 still lays out its own member.
        let s2Old = s2.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        let s2Tiled = state.effectiveTiledMembers(
            of: s2,
            activeSpace: space1
        )
        #expect(s2Tiled == s2Old)
        #expect(s2Tiled == [WindowID(2)])
    }

    @Test("Effective members handles traveling sticky windows across spaces")
    func effectiveMembersTravelingSticky() {
        var state = StateCoordinator()
        let space1 = SpaceID("1")
        let space2 = SpaceID("2")
        state.workspaces.ensureSpace(space1)
        state.workspaces.ensureSpace(space2)
        state.workspaces.activate(space1)

        let w1 = makeWindow(1, isFloating: false)
        let w2 = makeWindow(2, isFloating: true, isSticky: true)
        let w3 = makeWindow(3, isFloating: false)

        state.windows.upsert(w1)
        state.windows.upsert(w2)
        state.windows.upsert(w3)

        state.workspaces.add(WindowID(1), to: space1)
        // Sticky window homed on space2
        state.workspaces.add(WindowID(2), to: space2)
        state.workspaces.add(WindowID(3), to: space1)

        guard let s1 = state.workspaces[space1],
            let s2 = state.workspaces[space2]
        else {
            Issue.record("Expected spaces to exist")
            return
        }

        // Active space1: sticky w2 homed elsewhere travels to space1
        let s1Members = state.effectiveMembers(
            of: s1,
            activeSpace: space1
        )
        #expect(s1Members == [WindowID(1), WindowID(3), WindowID(2)])

        // Inactive space2: sticky w2 is pruned (traveled to space1)
        let s2Members = state.effectiveMembers(
            of: s2,
            activeSpace: space1
        )
        #expect(s2Members.isEmpty)
    }
}
