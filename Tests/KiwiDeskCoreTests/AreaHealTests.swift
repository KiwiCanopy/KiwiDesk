import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An area is never left with no Space (#3517): the resolve's heal
/// seeds each empty area of a split screen, pinned to the area's
/// key, and reuses that seed on the next resolve.
@Suite("Area heal")
@MainActor
struct AreaHealTests {
    private let wide = Display(
        id: DisplayID(900_501),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    @Test func everyAreaGetsASpaceOnce() throws {
        let core = makeTestCore()
        let split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)?
                .splitting(1, .sideBySide)
        )
        core.state.workspaces.upsertDisplay(wide)
        core.tiler.settings.displayAreas.store(
            split,
            on: wide.fingerprint,
            order: core.liveScreenOrder
        )
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.resolveSpaceDisplays(mainID: wide.id)
        let areas = core.state.workspaces.placements(of: wide.id)
        for area in areas {
            #expect(!core.state.workspaces.spaces(on: area.id).isEmpty)
        }
        let count = core.state.workspaces.allSpaces.count
        core.resolveSpaceDisplays(mainID: wide.id)
        #expect(core.state.workspaces.allSpaces.count == count)
        let right = try #require(areas.last)
        let seed = try #require(
            core.state.workspaces.spaces(on: right.id).first
        )
        #expect(core.spacePins[seed] == right.key.description)
        // A pin reset that empties the area again re-pins THAT
        // seed rather than minting another.
        core.spacePins[seed] = nil
        core.state.workspaces.assign(seed, to: areas[0].id)
        core.resolveSpaceDisplays(mainID: wide.id)
        #expect(core.state.workspaces.allSpaces.count == count)
        #expect(core.state.workspaces.placement(of: seed) == right.id)
        #expect(core.spacePins[seed] == right.key.description)
    }
}
