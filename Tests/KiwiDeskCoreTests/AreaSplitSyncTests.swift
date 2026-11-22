import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every write of `display_areas` reaches the placement list
/// (#3517): a whole-settings install — a profile apply, a Settings
/// Save, a revert — as much as the area verbs, through the one
/// `tiler.onAreaSplits` door, and none while splits are off.
@Suite("Area split sync")
@MainActor
struct AreaSplitSyncTests {
    private let wide = Display(
        id: DisplayID(900_501),
        name: "Wide",
        frame: CGRect(x: 0, y: 0, width: 3440, height: 1440)
    )

    private func split() throws -> ScreenSplit {
        try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)
        )
    }

    @Test func settingsInstallFeedsThePlacements() throws {
        let core = makeTestCore()
        core.honoursAreaSplits = true
        core.state.workspaces.upsertDisplay(wide)
        var settings = core.tiler.settings
        settings.displayAreas = [wide.fingerprint: try split()]
        core.tiler.settings = settings
        #expect(core.state.workspaces.placements(of: wide.id).count == 2)
        settings.displayAreas = [:]
        core.tiler.settings = settings
        #expect(core.state.workspaces.placements(of: wide.id).count == 1)
    }

    @Test func nothingIsFedWhileSplitsAreOff() throws {
        let core = makeTestCore()
        core.state.workspaces.upsertDisplay(wide)
        core.tiler.settings.displayAreas = [wide.fingerprint: try split()]
        #expect(core.state.workspaces.placements(of: wide.id).count == 1)
    }
}
