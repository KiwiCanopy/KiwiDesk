import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A split screen's areas each keep their own Space order and Space
/// history (#3517): the order step wraps inside the focused area,
/// and a per-screen history walk reaches only that area's Spaces.
@Suite("Area Space step and history")
@MainActor
struct AreaStepHistoryTests {
    private let wide = Display(
        id: DisplayID(900_611),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    /// Left holds 1 and 2, Right 3 and 4; 3 is active.
    private func core() throws -> KiwiCore {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        core.tiler.settings.displayAreas = [
            wide.fingerprint: try #require(
                ScreenSplit.whole(width: 3440, height: 1440)
                    .splitting(0, .sideBySide)
            )
        ]
        let areas = core.state.workspaces.placements(of: wide.id)
        try #require(areas.count == 2)
        for (space, area) in [("1", 0), ("2", 0), ("3", 1), ("4", 1)] {
            core.state.workspaces.assign(
                SpaceID(space),
                to: areas[area].id
            )
        }
        core.state.workspaces.activate("3")
        return core
    }

    @Test func orderStepWrapsInsideTheFocusedArea() throws {
        let core = try core()
        #expect(core.focusSpaceInOrder(by: 1).isSuccess)
        #expect(core.state.workspaces.activeSpace == "4")
        #expect(core.focusSpaceInOrder(by: 1).isSuccess)
        #expect(core.state.workspaces.activeSpace == "3")
    }

    @Test func historyReachesOnlyTheFocusedArea() throws {
        let core = try core()
        core.spaceHistory.base = .perScreen
        let walk = try #require(core.spaceHistoryWalk())
        #expect(walk.shown == "3")
        #expect(walk.reachable("4"))
        #expect(!walk.reachable("1"))
    }
}
