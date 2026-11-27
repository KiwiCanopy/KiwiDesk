import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A screen argument names an area (#3517 ruling 16): a number is a
/// physical screen, landing in its area 0 wherever the focus is; an
/// area key or an area's own name names that area; a shared name is
/// refused. `pin_space_to_display` stores the area's key.
@Suite("Area arguments")
@MainActor
struct AreaArgumentTests {
    private let wide = Display(
        id: DisplayID(900_401),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func core() throws -> (KiwiCore, [PlacementID]) {
        let core = makeTestCore()
        var split = try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
        split.areas[1].name = "Calls"
        core.state.workspaces.upsertDisplay(wide)
        core.storeSplit(split, on: wide.fingerprint)
        let areas = core.state.workspaces.placements(of: wide.id).map(\.id)
        core.state.workspaces.assign(SpaceID("1"), to: areas[0])
        core.state.workspaces.assign(SpaceID("2"), to: areas[1])
        core.state.workspaces.activate(SpaceID("1"))
        return (core, areas)
    }

    @Test func eachFormResolves() throws {
        let (core, areas) = try core()
        #expect(core.resolveAreaArg(.number(1)) == areas[0])
        #expect(core.resolveAreaArg(.string(wide.fingerprint)) == areas[0])
        #expect(
            core.resolveAreaArg(.string("\(wide.fingerprint)#1")) == areas[1]
        )
        #expect(core.resolveAreaArg(.string("Wide")) == areas[0])
        #expect(core.resolveAreaArg(.string("Calls")) == areas[1])
        #expect(core.resolveAreaArg(.string("Nowhere")) == nil)
    }

    @Test func numberLandsInAreaZero() throws {
        let (core, areas) = try core()
        core.state.workspaces.activate(SpaceID("2"))
        #expect(core.resolveAreaArg(.number(1)) == areas[0])
    }

    @Test func goneAreaKeyLandsInAreaZero() throws {
        let (core, areas) = try core()
        #expect(
            core.resolveAreaArg(.string("\(wide.fingerprint)#7")) == areas[0]
        )
    }

    @Test func everyAreaSpaceReadsShown() throws {
        let (core, _) = try core()
        // Space 2 shows in the non-lead area while 1 is active.
        #expect(
            core.state.workspaces.visibleSpaces == [
                SpaceID("1"), SpaceID("2"),
            ]
        )
    }

    @Test func pinStoresTheAreaKey() throws {
        let (core, _) = try core()
        let reply = core.execute(
            "pin_space_to_display",
            args: [.string("5"), .string("Calls")]
        )
        #expect(reply.isSuccess)
        #expect(core.spacePins[SpaceID("5")] == "\(wide.fingerprint)#1")
        #expect(core.state.workspaces.placement(of: SpaceID("5"))?.area == 1)
    }

    @Test func moveLandsInTheNamedArea() throws {
        let (core, _) = try core()
        let reply = core.execute(
            "move_space_to_display",
            args: [.string("1"), .string("Calls")]
        )
        #expect(reply.isSuccess)
        #expect(core.state.workspaces.placement(of: SpaceID("1"))?.area == 1)
    }

    @Test func sharedAreaNameIsRefused() throws {
        let (core, _) = try core()
        var split = core.state.workspaces.placements(of: wide.id)
            .map(\.area)
        split[0].name = "Calls"
        core.state.workspaces.setAreaSplits([
            wide.fingerprint: ScreenSplit(areas: split)
        ])
        #expect(core.resolveAreaArg(.string("Calls")) == nil)
    }

    @Test func screenNameWinsOverAnAreaName() throws {
        let (core, areas) = try core()
        var split = core.state.workspaces.placements(of: wide.id)
            .map(\.area)
        split[1].name = "Wide"
        core.state.workspaces.setAreaSplits([
            wide.fingerprint: ScreenSplit(areas: split)
        ])
        #expect(core.resolveAreaArg(.string("Wide")) == areas[0])
    }
}
