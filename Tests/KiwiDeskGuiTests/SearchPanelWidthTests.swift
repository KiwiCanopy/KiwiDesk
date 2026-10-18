import Foundation
import Testing

@testable import KiwiDesk

/// The search results panel's width (#2399): the field's width,
/// clamped to `floor ... cap`, and never past the header's
/// trailing edge. The arithmetic, then the wiring — a card that
/// stops reading the clamp, or a header that stops naming the
/// space the room is measured in, leaves the arithmetic green.
@Suite("Search panel width (#2399)")
struct SearchPanelWidthTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func width(field: CGFloat, room: CGFloat) -> CGFloat {
        SearchPanelWidth.width(
            for: SearchPanelRoom(field: field, room: room)
        )
    }

    @Test("a narrow field keeps the floor where the header has room")
    func narrowFieldKeepsTheFloor() {
        #expect(width(field: 200, room: 900) == SearchPanelWidth.floor)
    }

    @Test("a field between the bounds sets the width")
    func fieldSetsTheWidth() {
        let between = (SearchPanelWidth.floor + SearchPanelWidth.cap) / 2
        #expect(width(field: between, room: 2000) == between)
    }

    @Test("a wide field stops at the cap")
    func wideFieldStopsAtTheCap() {
        #expect(width(field: 1400, room: 2000) == SearchPanelWidth.cap)
    }

    /// The header's edge outranks the floor: a panel past it would
    /// hang off the window.
    @Test("the header's trailing edge outranks the floor")
    func roomOutranksTheFloor() {
        let room = SearchPanelWidth.floor - 40
        #expect(width(field: 150, room: room) == room)
        #expect(width(field: 1400, room: 500) == 500)
    }

    @Test("an unmeasured room leaves the clamp alone")
    func unmeasuredRoom() {
        #expect(width(field: 0, room: 0) == SearchPanelWidth.floor)
    }

    private func flat(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(path)
        )
        .split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the card draws the clamp and the header names its space")
    func clampIsWired() throws {
        let results = try flat(
            "Sources/KiwiDesk/Settings/HeaderSearch+Results.swift"
        )
        #expect(
            results.occurrences(
                of: ".frame(width:SearchPanelWidth.width(for:panelRoom),"
            ) == 1
        )
        let search = try flat("Sources/KiwiDesk/Settings/HeaderSearch.swift")
        #expect(
            search.occurrences(
                of: ".onGeometryChange(for:SearchPanelRoom.self,"
                    + "of:SearchPanelRoom.measured){panelRoom=$0}"
            ) == 1
        )
        let header = try flat(
            "Sources/KiwiDesk/Settings/SettingsHeaderBar.swift"
        )
        #expect(
            header.occurrences(
                of: ".coordinateSpace(.named(SearchPanelRoom.headerSpace))"
            ) == 1
        )
    }
}
