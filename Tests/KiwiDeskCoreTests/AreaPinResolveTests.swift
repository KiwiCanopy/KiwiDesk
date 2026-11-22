import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The space resolve places a pinned Space in the area its pin
/// names (#3517), keeps an unpinned Space's area across a resolve,
/// and sends a pin to a vanished area to area 0 (ruling 22).
@Suite("Area pins resolve")
@MainActor
struct AreaPinResolveTests {
    private let wide = Display(
        id: DisplayID(900_201),
        name: "LG UltraWide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func core() throws -> KiwiCore {
        let core = makeTestCore()
        let split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
        core.state.workspaces.setAreaSplits([wide.fingerprint: split])
        core.state.workspaces.upsertDisplay(wide)
        for id in 1...3 { core.state.workspaces.ensureSpace(SpaceID(id)) }
        return core
    }

    @Test func pinToAnAreaKeyLandsThere() throws {
        let core = try core()
        core.spacePins[SpaceID(2)] = "\(wide.fingerprint)#1"
        core.spacePins[SpaceID(3)] = wide.fingerprint
        core.resolveSpaceDisplays(mainID: wide.id)
        #expect(core.state.workspaces.placement(of: SpaceID(2))?.area == 1)
        #expect(core.state.workspaces.placement(of: SpaceID(3))?.area == 0)
    }

    @Test func unpinnedSpaceKeepsItsArea() throws {
        let core = try core()
        let right = try #require(
            core.state.workspaces.placements(of: wide.id).last
        ).id
        core.state.workspaces.assign(SpaceID(1), to: right)
        core.resolveSpaceDisplays(mainID: wide.id)
        #expect(core.state.workspaces.placement(of: SpaceID(1)) == right)
    }

    @Test func pinToAVanishedAreaTakesAreaZero() throws {
        let core = try core()
        let right = try #require(
            core.state.workspaces.placements(of: wide.id).last
        ).id
        // Held in the right area, its pin names an area gone: the pin
        // still decides, and area 0 is where it falls back to.
        core.state.workspaces.assign(SpaceID(2), to: right)
        core.spacePins[SpaceID(2)] = "\(wide.fingerprint)#7"
        core.resolveSpaceDisplays(mainID: wide.id)
        #expect(core.state.workspaces.placement(of: SpaceID(2))?.area == 0)
    }

    @Test func areaPinNamesItsScreen() throws {
        let core = try core()
        let laptop = Display(
            id: DisplayID(900_202),
            name: "Built-in",
            frame: CGRect(x: -1512, y: 0, width: 1512, height: 982)
        )
        core.state.workspaces.upsertDisplay(laptop)
        core.spacePins[SpaceID(2)] = "\(wide.fingerprint)#1"
        core.resolveSpaceDisplays(mainID: laptop.id)
        #expect(core.state.workspaces.display(of: SpaceID(2)) == wide.id)
        #expect(core.state.workspaces.placement(of: SpaceID(2))?.area == 1)
    }
}
