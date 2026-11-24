import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shared-Desktop grid's ← → (#3602): they stay in the
/// Desktop's row and land on the target cell's line whose top is
/// nearest the source line's, a tie going up; the columns keep
/// today's index. VoiceOver hears a grid line's screen.
@Suite("Desktops shared-Desktop grid keys (#3602)")
@MainActor
struct DesktopsGridKeysTests {
    typealias F = DesktopsGridFixture

    private func state(
        _ overview: DesktopOverview,
        at place: DesktopsPlace
    ) -> DesktopsState {
        var state = F.state(overview)
        state.select(place)
        return state
    }

    @Test("→ lands on the nearest line in the row, not the same index")
    func nearestLine() {
        // DELL's third line (top 2 lines down) faces Built-in's
        // split cell, whose second line sits nearest under a header.
        var grid = state(
            F.overview(),
            at: DesktopsPlace(screen: 1, desktop: 0, line: 2)
        )
        _ = grid.press(.side(-1), repeated: false)
        #expect(grid.place == DesktopsPlace(screen: 0, desktop: 0, line: 1))
        var columns = state(
            F.overview(shared: false),
            at: DesktopsPlace(screen: 1, desktop: 0, line: 2)
        )
        _ = columns.press(.side(-1), repeated: false)
        #expect(
            columns.place == DesktopsPlace(screen: 0, desktop: 0, line: 2)
        )
    }

    @Test("a tie between two lines goes up")
    func tieGoesUp() throws {
        // Built-in's first line starts one area header down, which at
        // the 36 pt line is halfway between DELL's first two lines.
        var grid = state(
            F.overview(),
            at: DesktopsPlace(screen: 0, desktop: 0, line: 0)
        )
        let top = DesktopsGeometry.areaHeight + DesktopsGeometry.areaGap
        try #require(2 * top == grid.geometry.line)
        _ = grid.press(.side(1), repeated: false)
        #expect(grid.place == DesktopsPlace(screen: 1, desktop: 0, line: 0))
    }

    @Test("a grid line speaks its screen; a column's does not")
    func spokenScreen() throws {
        LocalizationManager.shared.select("en")
        let place = DesktopsPlace(screen: 1, desktop: 1, line: 0)
        let grid = F.state()
        let line = try #require(grid.line(place))
        #expect(
            DesktopsText.spoken(line, at: place, in: grid).hasSuffix(", DELL")
        )
        let columns = F.state(F.overview(shared: false))
        #expect(
            !DesktopsText.spoken(line, at: place, in: columns)
                .contains("DELL")
        )
    }
}
