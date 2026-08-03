import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The live preview's window count (#678 turn 10).
///
/// The count exists so the schematics *simulate* rather than
/// illustrate — Cascade overflow and Cascade all draw the same
/// frame until the stack is deep enough to overflow, and a track
/// limit means nothing until there are more windows than tracks.
/// A schematic that took the count and ignored it would look
/// entirely correct on screen at the default, which is why these
/// assert the arithmetic rather than the drawing.
@Suite("Layout preview window count")
struct LayoutSchematicCountTests {
    /// The floor is 2, not 1: at one window every layout draws
    /// the same full-screen rectangle, and several schematics
    /// have no second zone to partition. A change lowering it
    /// reds here, where the reason is written down.
    @Test("the count band starts where a layout differs")
    func countBand() {
        #expect(LayoutSchematic.windowCountRange.lowerBound == 2)
        #expect(
            LayoutSchematic.windowCountRange.contains(
                LayoutSchematic.defaultWindowCount
            )
        )
    }

    /// A dynamic grid balances through the ENGINE's own rule, so
    /// the preview rebalances exactly when KiwiDesk does. Pinned
    /// at the boundary the balance moves: four windows are a 2×2
    /// and a fifth adds a column (columns-first) or a row
    /// (rows-first).
    @Test("a dynamic grid balances the way the engine does")
    func gridBalance() {
        let four = GridLayout.balanced(
            count: 4,
            splitDirection: .horizontal
        )
        #expect(four.columns == 2 && four.rows == 2)
        let five = GridLayout.balanced(
            count: 5,
            splitDirection: .horizontal
        )
        #expect(five.columns == 3 && five.rows == 2)
        let fiveRowsFirst = GridLayout.balanced(
            count: 5,
            splitDirection: .vertical
        )
        #expect(
            fiveRowsFirst.columns == 2 && fiveRowsFirst.rows == 3
        )
    }

    /// Every schematic reads the count. A schematic that dropped
    /// the input would still compile and still draw — this is the
    /// scan that says it did not, and it walks the tree rather
    /// than restating a list of file names, so a seventh
    /// schematic is covered by existing code.
    @Test("every schematic takes the window count")
    func everySchematicTakesTheCount() throws {
        let dir = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Layouts"
            )
        var checked = 0
        for file in try SourceScan.swiftSources(under: dir)
        where file.lastPathComponent.hasSuffix("Schematic.swift") {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            checked += 1
            #expect(
                source.contains(
                    "var windows = "
                        + "LayoutSchematic.defaultWindowCount"
                ),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) declares no "
                        + "window count — the preview's slider "
                        + "would move nothing in it"
                )
            )
            #expect(
                source.contains("value: windows"),
                Comment(
                    rawValue:
                        "\(file.lastPathComponent) never reads "
                        + "its window count into the drawing"
                )
            )
        }
        // A floor would let the scan pass having looked at
        // nothing. Seven: the six tuned layouts (Floating has
        // nothing to draw) plus Scrolling's follow pair, which
        // is a second frame of the same layout and needs the
        // count for the same reason.
        #expect(checked == 7)
    }
}
