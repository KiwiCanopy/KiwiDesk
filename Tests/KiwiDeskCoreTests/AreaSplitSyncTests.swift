import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Every write of `display_areas` reaches the placement list
/// (#3517): a whole-settings install — a profile apply, a Settings
/// Save, a revert — as much as the area verbs, through the one
/// `tiler.onAreaSplits` door.
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
        core.state.workspaces.upsertDisplay(wide)
        var settings = core.tiler.settings
        settings.displayAreas.store(
            try split(),
            on: wide.fingerprint,
            order: core.liveScreenOrder
        )
        core.tiler.settings = settings
        #expect(core.state.workspaces.placements(of: wide.id).count == 2)
        settings.displayAreas = [:]
        core.tiler.settings = settings
        #expect(core.state.workspaces.placements(of: wide.id).count == 1)
    }

    /// A load installs the settings before the boot scan reports a
    /// screen, so the split waits for its screen (#3517 L19): the
    /// report's resolve gives the screen its number, and with it
    /// Screen 1's split (#3647 ▸ lane 3).
    @Test func splitLoadedBeforeItsScreenLaysOut() throws {
        let core = makeTestCore()
        var settings = core.tiler.settings
        // Screen 1's shares, before any screen gives the number one.
        settings.displayAreas[number: 1] = ScreenShares(
            try split(),
            width: 3440,
            height: 1440
        )
        core.tiler.settings = settings
        core.state.workspaces.upsertDisplay(wide)
        core.resolveSpaceDisplays()
        #expect(core.state.workspaces.placements(of: wide.id).count == 2)
    }
}
