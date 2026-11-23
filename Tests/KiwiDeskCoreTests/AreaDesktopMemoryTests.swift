import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A Desktop switch on a split screen switches every area of it
/// (#3517 ruling 17): each area shows the Space it showed on the
/// arriving Desktop, or a free one, and files what it showed under
/// the Desktop it left. Driven through `moveSwitchedDisplaySpaces`,
/// as `SecondaryDisplaySpaceTests` drives it, since the handler's
/// arm retiles and a retile needs a host screen.
@Suite("Desktop memory per area (#3517)", .serialized)
@MainActor
struct AreaDesktopMemoryTests {
    /// Display A unsplit with Space 1; display B split side by side,
    /// Space 3 in its left area and Spaces 4 and 5 in its right.
    private func makeCore() -> (KiwiCore, [PlacementID]) {
        let core = makeAuthorityCore()
        let wide = Display(
            id: DisplayID(2),
            name: "B",
            frame: CGRect(x: 100, y: 0, width: 3440, height: 1440)
        )
        let split = ScreenSplit.whole(width: 3440, height: 1440)
            .splitting(0, .sideBySide)
        core.state.workspaces.setAreaSplits(
            split.map { [wide.fingerprint: $0] } ?? [:]
        )
        connectAuthority(core, [authorityDisplay(1, "A"), wide])
        pinTwoDisplays()
        let areas = core.state.workspaces.placements(of: wide.id)
            .map(\.id)
        core.state.workspaces.ensureSpace(SpaceID(1))
        core.state.workspaces.assign(SpaceID(1), to: DisplayID(1))
        let homes = [(3, 0), (4, 1), (5, 1)]
        for (space, area) in homes where areas.count > area {
            core.state.workspaces.ensureSpace(SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: areas[area])
        }
        core.state.workspaces.activate(SpaceID(1))
        return (core, areas)
    }

    private func swipe(
        _ core: KiwiCore,
        from left: UInt64,
        to arriving: UInt64
    ) -> DesktopSnapshot {
        let snapshot = authoritySnapshot(secondaryCurrent: arriving)
        core.moveSwitchedDisplaySpaces(
            DisplaySwitch(
                changed: ["UUID-B"],
                previous: ["UUID-A": 10, "UUID-B": left]
            ),
            in: snapshot
        )
        return snapshot
    }

    private func shown(
        _ core: KiwiCore,
        _ area: PlacementID
    ) -> SpaceID? {
        core.state.workspaces.activeSpace(on: area)
    }

    @Test("each area files what it showed under the Desktop left")
    func departureFilesEveryArea() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        core.state.workspaces.show(SpaceID(4), on: areas[1])
        let snapshot = swipe(core, from: 20, to: 21)
        let left = try #require(snapshot.key(of: 20))
        let filed = core.desktopMemory.areaSpaces[left]
        let keys = areas.compactMap {
            core.state.workspaces[placement: $0]?.key.description
        }
        #expect(filed == [keys[0]: SpaceID(3), keys[1]: SpaceID(4)])
    }

    @Test("a return shows each area's own Space again")
    func returnRestoresEveryArea() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        core.state.workspaces.show(SpaceID(4), on: areas[1])
        _ = swipe(core, from: 20, to: 21)
        // A fresh Desktop takes the free Space in the right area.
        #expect(shown(core, areas[1]) == SpaceID(5))
        #expect(shown(core, areas[0]) == SpaceID(3))
        _ = swipe(core, from: 21, to: 20)
        #expect(shown(core, areas[1]) == SpaceID(4))
        #expect(shown(core, areas[0]) == SpaceID(3))
        // The other screen never moved.
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
    }

    @Test("an area with no free Space keeps what it shows")
    func noFreeSpaceKeeps() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        _ = swipe(core, from: 20, to: 21)
        #expect(shown(core, areas[0]) == SpaceID(3))
    }

    @Test("an unsplit screen files no area memory")
    func unsplitFilesNothing() {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        let snapshot = authoritySnapshot(mainCurrent: 11)
        guard let left = snapshot.key(of: 10) else { return }
        core.rememberAreaSpaces(on: DisplayID(1), leaving: left)
        #expect(core.desktopMemory.areaSpaces.isEmpty)
    }

    @Test("a stamp re-keys the areas' memory with the cursor")
    func reconcileRekeys() {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        let stamp = DesktopIdentity(raw: "AREA-STAMP")
        core.desktopMemory.areaSpaces[.number(3)] = ["k": SpaceID(3)]
        var topology = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        topology[2] = authoritySpace(
            20,
            display: "UUID-B",
            current: true,
            identity: stamp
        )
        NativeSpaces.spacesOverride = topology
        core.reconcileDesktopSpaceMemory(
            in: NativeSpaces.desktopSnapshot()
        )
        #expect(core.desktopMemory.areaSpaces[.number(3)] == nil)
        #expect(
            core.desktopMemory.areaSpaces[.identity(stamp)]
                == ["k": SpaceID(3)]
        )
    }

    @Test("the discard clears the areas' memory")
    func forgetClears() {
        let (core, _) = makeCore()
        core.desktopMemory.areaSpaces[.number(3)] = ["k": SpaceID(3)]
        core.forgetDesktopSpaceMemory()
        #expect(core.desktopMemory.areaSpaces.isEmpty)
        #expect(core.persistedDesktopAreaSpaces() == [:])
    }
}
