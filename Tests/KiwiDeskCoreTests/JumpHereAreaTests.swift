import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's "here" on a split screen is the area it opened over
/// (#3572 ruling 1): the Space that area shows, not the screen's
/// first area's, for the list's rows and Move here alike, while the
/// focus stays on another screen. Display A unsplit with Space 1,
/// focused; display B split side by side, Space 3 in its left area
/// and Space 4 in its right.
@Suite("KiwiHub here by area (#3572)", .serialized)
@MainActor
struct JumpHereAreaTests {
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
        let areas = core.state.workspaces.placements(of: wide.id)
            .map(\.id)
        core.state.workspaces.ensureSpace(SpaceID(1))
        core.state.workspaces.assign(SpaceID(1), to: DisplayID(1))
        for (space, area) in [(3, 0), (4, 1)] where areas.count > area {
            core.state.workspaces.ensureSpace(SpaceID(space))
            core.state.workspaces.assign(SpaceID(space), to: areas[area])
        }
        core.state.workspaces.activate(SpaceID(1))
        return (core, areas)
    }

    @Test("each area's here is the Space it shows")
    func hereIsTheArea() throws {
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        #expect(core.jumpSnapshot(on: areas[0]).here == SpaceID(3))
        #expect(core.jumpSnapshot(on: areas[1]).here == SpaceID(4))
        #expect(core.moveHereSpace(in: areas[1]) == SpaceID(4))
        // The screen's own read answers its first area, which is
        // what a right-area Move here used to file into.
        #expect(core.awayFilingSpace(on: DisplayID(2)) == SpaceID(3))
        // No area: the active Space.
        #expect(core.moveHereSpace(in: nil) == SpaceID(1))
    }

    /// The pointer read in Cocoa points, judged on the screens
    /// state holds, so no host screen decides it.
    @Test("the pointer's area is KiwiHub's area")
    func pointerPicksTheArea() throws {
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        core.shelves.contextMenus.pointer = { NSPoint(x: 3000, y: 700) }
        #expect(core.jumpArea() == areas[1])
        core.shelves.contextMenus.pointer = { NSPoint(x: 400, y: 700) }
        #expect(core.jumpArea() == areas[0])
        #expect(core.layoutPickerSpace(in: core.jumpArea()) == SpaceID(3))
        core.shelves.contextMenus.pointer = { NSPoint(x: 50, y: 50) }
        #expect(
            core.jumpArea()
                == core.state.workspaces.leadPlacement(
                    of: DisplayID(1)
                )
        )
        core.shelves.contextMenus.pointer = { NSPoint(x: -9000, y: 0) }
        #expect(core.jumpArea() == nil)
    }

    @Test("Move here from the right area files into its Space")
    func moveHereFilesIntoTheArea() throws {
        let (core, areas) = makeCore()
        try #require(areas.count == 2)
        let window = ManagedWindow(
            id: WindowID(7),
            pid: 900_310,
            appName: "A"
        )
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(7), to: SpaceID(1))
        #expect(core.moveHere(.window(WindowID(7)), on: areas[1]))
        #expect(core.state.workspaces.space(of: WindowID(7)) == SpaceID(4))
    }
}
