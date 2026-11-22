import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A split copies the parent area's bar values to the area it
/// mints (#3517), and the Save diff books each copied entry as a
/// row of its own, so a split shows its bar changes before Save.
@MainActor
@Suite("A split's copied bar values reach the diff (#3517)")
struct ScreenAreaSplitDiffTests {
    private let screen = "DELL U2720Q:2560x1440"

    @Test("the minted area's copied edge and Show are rows")
    func copiedEntriesAreRows() throws {
        var clean = GuiConfig()
        clean.settings.appBarStyle.edgeOverride[screen] = .left
        clean.settings.spaceBarStyle.visibilityOverride[screen] = .hidden
        var edited = clean
        let whole = ScreenSplit.whole(width: 2560, height: 1440)
        let split = edited.splitArea(
            0,
            .sideBySide,
            floor: 100,
            of: whole,
            on: screen
        )
        let copy = try #require(split)
        let minted = copy.minted.description
        let edges = SettingsValueReadout.rows(
            for: .kiwishelf(.appBarScreenEdge),
            old: clean,
            new: edited
        )
        #expect(edges.map(\.instance) == [minted])
        let shows = SettingsValueReadout.rows(
            for: .kiwishelf(.spaceBarScreenVisibility),
            old: clean,
            new: edited
        )
        #expect(shows.map(\.instance) == [minted])
    }
}
