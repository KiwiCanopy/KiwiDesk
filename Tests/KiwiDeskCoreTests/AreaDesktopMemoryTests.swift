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
    /// Spaces 6 and 3 in its left area (in that order, 3 shown) and
    /// Spaces 4 and 5 in its right.
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
        let homes = [(6, 0), (3, 0), (4, 1), (5, 1)]
        for (space, area) in homes where areas.count > area {
            core.state.workspaces.ensureSpace(SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: areas[area])
        }
        core.state.workspaces.activate(SpaceID(1))
        if let left = areas.first {
            core.state.workspaces.show(SpaceID(3), on: left)
        }
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
        // A fresh Desktop takes a free Space in each area: the
        // cursor's pick the left, the area's own the right.
        #expect(shown(core, areas[0]) == SpaceID(6))
        #expect(shown(core, areas[1]) == SpaceID(5))
        _ = swipe(core, from: 21, to: 20)
        #expect(shown(core, areas[1]) == SpaceID(4))
        #expect(shown(core, areas[0]) == SpaceID(3))
        // The other screen never moved.
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
    }

    /// Space 6 is another present Desktop's, so the left area has
    /// no free Space while the cursor lands in the right one.
    @Test("an area with no free Space keeps what it shows")
    func noFreeSpaceKeeps() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let other = try #require(authoritySnapshot().key(of: 11))
        core.desktopMemory.areaSpaces[other] = ["x": SpaceID(6)]
        _ = swipe(core, from: 20, to: 21)
        #expect(shown(core, areas[1]) == SpaceID(5))
        #expect(shown(core, areas[0]) == SpaceID(3))
    }

    @Test("another Desktop's area Space is taken for the cursor")
    func cursorSkipsAreaMemory() throws {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        let snapshot = authoritySnapshot()
        let other = try #require(snapshot.key(of: 11))
        let arriving = try #require(snapshot.key(of: 21))
        core.desktopMemory.areaSpaces[other] = ["x": SpaceID(6)]
        let taken = core.spacesShownElsewhere(
            excluding: arriving,
            in: snapshot
        )
        #expect(taken.contains(SpaceID(6)))
    }

    @Test("an unsplit screen files no area memory")
    func unsplitFilesNothing() throws {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        let snapshot = authoritySnapshot(mainCurrent: 11)
        let left = try #require(snapshot.key(of: 10))
        core.rememberAreaSpaces(on: DisplayID(1), leaving: left)
        #expect(core.desktopMemory.areaSpaces.isEmpty)
    }

    /// The main arm's departure files the screen the Desktop it
    /// left lives on, read from the switch's own snapshot.
    @Test("the main departure files the left Desktop's screen")
    func mainDepartureFilesItsScreen() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let snapshot = authoritySnapshot()
        let left = try #require(snapshot.key(of: 20))
        core.rememberDeparture(
            of: SpaceID(1),
            leaving: left,
            in: snapshot
        )
        #expect(core.desktopMemory.areaSpaces[left]?.count == 2)
    }

    @Test("the main arrival switches the screen's other areas")
    func mainArrivalSwitchesTheAreas() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        NativeSpaces.mainDisplayUUIDOverride = "UUID-B"
        let snapshot = authoritySnapshot(secondaryCurrent: 21)
        let arriving = try #require(snapshot.key(of: 21))
        let key = try #require(
            core.state.workspaces[placement: areas[1]]?.key.description
        )
        core.desktopMemory.areaSpaces[arriving] = [key: SpaceID(5)]
        core.activateArriving(SpaceID(6), on: arriving, in: snapshot)
        #expect(core.state.workspaces.activeSpace == SpaceID(6))
        #expect(shown(core, areas[1]) == SpaceID(5))
    }

    @Test("a merge moves the live areas' memory to the survivor")
    func mergeRemapsTheLiveMemory() throws {
        defer { resetAuthorityOverrides() }
        let (core, _) = makeCore()
        let whole = ScreenSplit.whole(width: 3440, height: 1440)
        let three = try #require(
            whole.splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
        let merged = try #require(three.merging(2, 1)?.split)
        let desktop = DesktopKey.number(3)
        core.desktopMemory.areaSpaces[desktop] = [
            "Wide#2": SpaceID(5), "Wide#1": SpaceID(4),
        ]
        core.desktopMemory.areaSpaces[.number(4)] = ["Wide#2": SpaceID(5)]
        core.remapAreaSpaces(
            from: ["Wide": three],
            to: ["Wide": merged]
        )
        #expect(
            core.desktopMemory.areaSpaces[desktop] == ["Wide#1": SpaceID(4)]
        )
        #expect(
            core.desktopMemory.areaSpaces[.number(4)]
                == ["Wide#1": SpaceID(5)]
        )
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
