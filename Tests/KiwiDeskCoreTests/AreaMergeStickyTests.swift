import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A merge moves the merged-away area's Spaces to the survivor, and
/// a screen-sticky window is sticky to its home area (#3517 rulings
/// 22, 30): it renders there, stays out of the stash there, and may
/// move to another area of its screen.
@Suite("Area merge and screen-sticky")
@MainActor
struct AreaMergeStickyTests {
    private let wide = Display(
        id: DisplayID(900_621),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    /// Left, Middle and Right — ids 0, 1 and 2 — holding Spaces
    /// 1, 2 and 3.
    private func core() throws -> (KiwiCore, ScreenSplit) {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        let split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)?
                .splitting(1, .sideBySide)
        )
        core.tiler.settings.displayAreas.store(
            split,
            on: wide.fingerprint,
            order: core.liveScreenOrder
        )
        let areas = core.state.workspaces.placements(of: wide.id)
        try #require(areas.map(\.area.id) == [0, 1, 2])
        for (space, area) in zip(["1", "2", "3"], areas) {
            core.state.workspaces.assign(SpaceID(space), to: area.id)
        }
        core.state.workspaces.activate("1")
        return (core, split)
    }

    @Test func mergedAwaySpaceGoesToTheSurvivor() throws {
        let (core, split) = try core()
        let merged = try #require(split.merging(1, 2))
        #expect(merged.survivor == 1)
        core.tiler.settings.displayAreas.store(
            merged.split,
            on: wide.fingerprint,
            order: core.liveScreenOrder
        )
        #expect(core.state.workspaces.placement(of: "3")?.area == 1)
        #expect(core.state.workspaces.placement(of: "1")?.area == 0)
    }

    @Test func screenStickyKeepsToItsHomeArea() throws {
        let (core, _) = try core()
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(1),
                pid: 900_621,
                appName: "Sticky",
                stickyScope: .display
            )
        )
        core.state.workspaces.add(WindowID(1), to: "2")
        let state = core.state
        let window = try #require(state.windows[WindowID(1)])
        // Focus in Left: the window still draws in Middle.
        #expect(state.stickyRenderSpace(of: window) == "2")
        #expect(!state.stickyExemptFromStash(window, onSpace: "1"))
        #expect(core.stickyMoveBlock(WindowID(1), to: "3") == nil)
        #expect(core.stickyMoveBlock(WindowID(1), to: "2") != nil)
    }

    /// A Lua merge rewrites a pin on the merged-away area to the
    /// survivor, as a Settings merge does (ruling 22).
    @Test func luaMergeMovesThePinToTheSurvivor() throws {
        let (core, _) = try core()
        let right = ScreenAreaKey(parsing: "\(wide.fingerprint)#2")
        core.spacePins["3"] = right.description
        let reply = core.execute(
            "set_display_areas",
            args: [
                .string(wide.fingerprint), .string("side_by_side"),
                .number(1720), .number(1720),
            ]
        )
        #expect(reply.isSuccess)
        let survivor = ScreenAreaKey(parsing: "\(wide.fingerprint)#1")
        #expect(core.spacePins["3"] == survivor.description)
    }
}
