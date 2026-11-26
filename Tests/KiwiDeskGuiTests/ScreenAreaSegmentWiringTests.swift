import Foundation
import Testing

/// The ⌥-drag on a joined divider (#3611) reaches Core's segment
/// doors: no unit test drives a real drag, so the call sites are
/// pinned here, beside `ScreenSplitSegmentTests`' doors.
@Suite("Screen area segment wiring (#3611)")
struct ScreenAreaSegmentWiringTests {
    private func source(_ name: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
        let dir = "Sources/KiwiDesk/Settings/Components/Screens/"
        return SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(dir + name),
                encoding: .utf8
            )
        )
    }

    @Test func segmentDragGoesThroughCore() throws {
        let divider = try source("ScreenAreaDivider.swift")
        #expect(!divider.isEmpty)
        // ⌥ picks a segment only on a joined line, from Core.
        #expect(
            divider.contains(
                "guard NSEvent.modifierFlags.contains(.option), joined"
            )
        )
        #expect(divider.contains("split.isJoined(cut)"))
        #expect(
            divider.contains(
                "split.segment(of: cut, at: pointer ?? cut.start)"
            )
        )
        // The segment moves through its door, unsnapped, and lands
        // on the in-flight cut that holds it.
        #expect(divider.contains("split.movingSegment("))
        #expect(
            divider.contains(
                "landed: landed.split.cut(\n"
                    + "                    holding: segment,"
            )
        )
        #expect(divider.contains("segment: segment\n"))
        // The card draws the piece in flight and the line's rest.
        let card = try source("ScreenCard.swift")
        #expect(card.contains("let shown = mine?.segment ?? cut"))
        #expect(card.contains("AreaSegmentRest(stored: stored"))
    }
}
