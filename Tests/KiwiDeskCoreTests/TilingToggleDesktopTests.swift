import Foundation
import Testing

@testable import KiwiDeskCore

/// The tiling toggle belongs to the Desktop its Space shows on
/// (#3008, owner 2026-11-09): each switch keeps the left Desktop's
/// toggles and brings the arriving one's, read from
/// `DesktopMemory.shownSpaces` as the stack flip is (#2771).
@Suite("Tiling toggle per Desktop (#3008)", .serialized)
@MainActor
struct TilingToggleDesktopTests {
    private let space = SpaceID("1")

    private func core() throws -> KiwiCore {
        let core = try KeepFixture.core()
        show(core, ["Main": 10])
        return core
    }

    private func show(
        _ core: KiwiCore,
        _ shown: [String: SkyLight.SpaceID]
    ) {
        core.desktopMemory.shownSpaces = shown
        core.desktopMemory.shownUserSpaces =
            shown.mapValues { _ in true }
    }

    @Test("each Desktop keeps its own toggle")
    func eachDesktopKeepsItsOwn() throws {
        let core = try core()
        #expect(
            core.execute("set_tiling", args: [.bool(false)]).isSuccess
        )
        #expect(core.isTilingOff(space))
        core.refileTilingToggles { show(core, ["Main": 11]) }
        #expect(!core.isTilingOff(space))
        #expect(core.desktopMemory.tilingToggles[10]?[space] == false)
        core.refileTilingToggles { show(core, ["Main": 10]) }
        #expect(core.isTilingOff(space))
        #expect(core.desktopMemory.tilingToggles.isEmpty)
    }

    @Test("a full-screen Space between two Desktops moves no toggle")
    func fullScreenBetweenKeepsEach() throws {
        let core = try core()
        core.execute("set_tiling", args: [.bool(false)])
        // A full-screen app: no user Desktop shown.
        core.refileTilingToggles {
            show(core, ["Main": 99])
            core.desktopMemory.shownUserSpaces = ["Main": false]
        }
        core.refileTilingToggles { show(core, ["Main": 11]) }
        #expect(!core.isTilingOff(space))
        core.refileTilingToggles { show(core, ["Main": 10]) }
        #expect(core.isTilingOff(space))
        core.refileTilingToggles { show(core, ["Main": 11]) }
        #expect(!core.isTilingOff(space))
    }

    @Test("a reading that leaves the Desktop as it was swaps nothing")
    func sameDesktopSwapsNothing() throws {
        let core = try core()
        core.execute("set_tiling", args: [.bool(false)])
        core.refileTilingToggles { show(core, ["Main": 10]) }
        #expect(core.isTilingOff(space))
        #expect(core.desktopMemory.tilingToggles.isEmpty)
    }

    @Test("a dropped Space forgets its toggles on every Desktop")
    func dropForgetsEveryDesktop() throws {
        let core = try core()
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.execute("set_tiling", args: [.bool(false), .string("2")])
        core.refileTilingToggles { show(core, ["Main": 11]) }
        #expect(
            core.desktopMemory.tilingToggles[10]?[SpaceID("2")] == false
        )
        core.forwardWindows(of: SpaceID("2"), to: space)
        #expect(core.desktopMemory.tilingToggles.isEmpty)
        #expect(core.state.tilingToggles[SpaceID("2")] == nil)
    }
}
