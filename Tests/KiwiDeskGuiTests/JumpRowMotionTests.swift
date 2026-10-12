import Foundation
import Testing

@testable import KiwiDesk

/// ⇧'s way here takes its room as the ⌘ number does (#1875 ▸
/// owner eyeball, 2026-10-12): the row's one animation keys both,
/// so ⇧ alone and ⇧⌘ slide under the same Reduce Motion gate.
@Suite("Jump to window row motion")
struct JumpRowMotionTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    private func squashedRow() throws -> String {
        let url = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Jump/JumpRowView.swift"
        )
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }

    @Test("one animation carries the number and the way here")
    func oneAnimationKeysBoth() throws {
        let row = try squashedRow()
        #expect(row.components(separatedBy: ".animation(").count == 2)
        #expect(row.contains("value:[showsNumber,showsWayHere])"))
    }

    /// The source keeps its identity, so the way here grows beside
    /// it: a row Move here can bring always draws the way-here
    /// view, expanded by the flag rather than swapped by it.
    @Test("the way here grows beside the source, never swaps it")
    func wayHereGrows() throws {
        let row = try squashedRow()
        #expect(row.contains("expanded:showsWayHere"))
        // Exactly one way-here view, built for every row it can
        // reach: a second construction is the swap coming back.
        #expect(row.components(separatedBy: "JumpWayHereView(").count == 2)
    }
}
