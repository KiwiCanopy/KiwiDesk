import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The two read paths of the per-area Desktop memory a plain
/// return never takes (#3517): a Space filed under a key that is
/// not its area's own (a merged-away area, ruling 22), and a main
/// departure whose Desktop has only its number, which the arriving
/// reading may give to another screen's Desktop (#1147). Split from
/// `AreaDesktopMemoryTests` at the file ceiling, with its fixture.
@Suite("Desktop memory per area, edge reads (#3517)", .serialized)
@MainActor
struct AreaDesktopMemoryEdgeTests {
    /// Display A unsplit with Space 1; display B split side by side,
    /// Spaces 6 and 3 in its left area (in that order, 3 shown) and
    /// Spaces 4, 5 and 7 in its right.
    private func makeCore() -> (KiwiCore, [PlacementID]) {
        let core = makeAuthorityCore()
        let wide = Display(
            id: DisplayID(2),
            name: "B",
            frame: CGRect(x: 100, y: 0, width: 3440, height: 1440)
        )
        connectAuthority(core, [authorityDisplay(1, "A"), wide])
        pinTwoDisplays()
        if let split = ScreenSplit.whole(width: 3440, height: 1440)
            .splitting(0, .sideBySide)
        {
            core.tiler.settings.displayAreas.store(
                split,
                on: wide.fingerprint,
                order: core.liveScreenOrder
            )
        }
        let areas = core.state.workspaces.placements(of: wide.id)
            .map(\.id)
        core.state.workspaces.ensureSpace(SpaceID(1))
        core.state.workspaces.assign(SpaceID(1), to: DisplayID(1))
        let homes = [(6, 0), (3, 0), (4, 1), (5, 1), (7, 1)]
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

    @Test("a Space filed under another key returns to its area")
    func movedEntryIsHonoured() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let arriving = try #require(authoritySnapshot().key(of: 21))
        let key = try #require(core.state.workspaces[placement: areas[1]]?.key)
        let number = try #require(core.liveScreenOrder.slot(of: key)?.number)
        core.desktopMemory.areaSpaces[arriving] = ["\(number)#9": SpaceID(7)]
        _ = swipe(core, from: 20, to: 21)
        // The filed 7, where a free pick would take 5.
        #expect(shown(core, areas[1]) == SpaceID(7))
    }

    /// Desktop 3 is display B's first; its number, re-read in the
    /// arriving reading, is not trusted to name its screen, so the
    /// main screen (unsplit) is the one filed.
    @Test("a numbered Desktop's departure files the main screen")
    func numberKeyFilesTheMainScreen() throws {
        defer { resetAuthorityOverrides() }
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let snapshot = authoritySnapshot()
        let left = DesktopKey.number(3)
        try #require(snapshot.space(for: left)?.displayUUID == "UUID-B")
        core.rememberDeparture(
            of: SpaceID(1),
            leaving: left,
            in: snapshot
        )
        #expect(core.desktopMemory.areaSpaces[left] == nil)
    }
}
