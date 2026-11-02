import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize's sizes belong to the Desktop its screen shows
/// (#2921), read from `DesktopMemory.shownSpaces` like the stack
/// flip, with the owner's four rulings: a restart carries them
/// (`SnapshotCarryCensusTests`), a reset names one Desktop or
/// every one, an unnamed Desktop shares one entry, and an explicit
/// choice clears every Desktop.
@Suite("Session sizes per Desktop (#2921)", .serialized)
@MainActor
struct SessionRatioDesktopTests {
    private let space = SpaceID("1")

    private func core() throws -> KiwiCore {
        let core = try KeepFixture.core()
        core.setSpaceMode(space, .bsp)
        return core
    }

    private func show(_ core: KiwiCore, _ shown: [String: SkyLight.SpaceID]) {
        core.desktopMemory.shownSpaces = shown
        core.desktopMemory.shownUserSpaces = shown.mapValues { _ in true }
    }

    /// The store's entry for `space` on `desktop` under the
    /// arrangement live.
    private func stored(
        _ core: KiwiCore,
        _ desktop: SkyLight.SpaceID?,
        _ id: SpaceID? = nil
    ) -> SessionRatios? {
        core.desktopMemory.sessionRatios[desktop]?[core.liveArrangement]?[
            id ?? space
        ]
    }

    /// What the render resolves for the Space, through the
    /// engine's wired door.
    private func drawnRatioH(_ core: KiwiCore) throws -> Double {
        let live = try #require(core.state.workspaces[space])
        return core.tiler.settings.resolvedBsp(
            for: live,
            session: core.tiler.sessionRatios(space)
        ).splitRatioH
    }

    @Test("a resize on one Desktop leaves the other's split")
    func twoDesktopsKeepTheirOwn() throws {
        let core = try core()
        let global = core.tiler.settings.bsp.splitRatioH
        show(core, ["Main": 10])
        core.writeSplitRatioH(0.7, for: space)
        #expect(try drawnRatioH(core) == 0.7)
        show(core, ["Main": 11])
        #expect(try drawnRatioH(core) == global)
        core.writeSplitRatioH(0.3, for: space)
        show(core, ["Main": 10])
        #expect(try drawnRatioH(core) == 0.7)
        show(core, ["Main": 11])
        #expect(try drawnRatioH(core) == 0.3)
    }

    @Test("a named reset is this Desktop's; all is every Desktop's")
    func resetScopes() throws {
        let core = try core()
        show(core, ["Main": 10])
        core.writeSplitRatioH(0.7, for: space)
        show(core, ["Main": 11])
        core.writeSplitRatioH(0.3, for: space)
        #expect(
            core.execute("reset_layout_sizing", args: [.string("1")])
                .isSuccess
        )
        #expect(core.sessionRatios(of: space) == SessionRatios())
        show(core, ["Main": 10])
        #expect(core.sessionRatios(of: space).splitRatioH == 0.7)
        // A Desktop other than the shown one holds sizes too, so
        // only a reset of every Desktop empties the store.
        show(core, ["Main": 11])
        core.writeSplitRatioH(0.3, for: space)
        show(core, ["Main": 10])
        #expect(
            core.execute("reset_layout_sizing", args: [.string("all")])
                .isSuccess
        )
        #expect(core.desktopMemory.sessionRatios.isEmpty)
    }

    @Test("no Desktop named: one shared entry, unread by a named one")
    func unnamedSharesOneEntry() throws {
        let core = try core()
        show(core, [:])
        core.writeSplitRatioH(0.7, for: space)
        #expect(stored(core, nil) != nil)
        // A screen no switch has filed names no Desktop either.
        show(core, ["6F1C1E9A-0000-4000-8000-000000000001": 30])
        #expect(core.sessionRatios(of: space).splitRatioH == 0.7)
        show(core, ["Main": 10])
        #expect(core.sessionRatios(of: space) == SessionRatios())
    }

    @Test("an override setter and a mode change clear every Desktop")
    func explicitChoicesClearEveryDesktop() throws {
        let core = try core()
        for desktop: SkyLight.SpaceID in [10, 11] {
            show(core, ["Main": desktop])
            core.writeSplitRatioH(0.7, for: space)
            core.writeMasterRatio(0.6, for: space)
        }
        _ = core.execute(
            "bsp.set_ratio_h_override",
            args: [.string("1"), .number(0.4)]
        )
        for desktop in [10, 11] as [SkyLight.SpaceID] {
            let ratios = stored(core, desktop)
            #expect(ratios?.splitRatioH == nil)
            #expect(ratios?.masterRatio == 0.6)
        }
        core.setSpaceMode(space, .stack)
        #expect(core.desktopMemory.sessionRatios.isEmpty)
    }

    @Test("a renumber keeps the sizes; a drop forgets them")
    func renumberAndDrop() throws {
        let core = try core()
        show(core, ["Main": 10])
        core.writeSplitRatioH(0.7, for: space)
        core.rekeySessionRatios(space, to: "9", under: core.liveArrangement)
        #expect(stored(core, 10, "9") != nil)
        #expect(stored(core, 10) == nil)
        core.forgetSessionRatios(of: "9")
        #expect(core.desktopMemory.sessionRatios.isEmpty)
    }
}
