import Foundation
import Testing

/// The hover peek's wiring a behavioural test cannot see (#1946):
/// its glass decided through the one gate where it renders, its
/// item re-checked after the shelf's hover re-read, and no bar view
/// left registering the system tooltip it replaces.
@Suite("Bar hover peek seams (#1946)")
struct BarPeekSeamTests {
    private static var bar: URL {
        SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore/Bar")
    }

    private static func source(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: bar.appendingPathComponent(file)
        )
    }

    /// One gate read on the stored shelf, which the body names
    /// nowhere beside it — a second read would draw the stored
    /// glass under Reduce transparency (#1374).
    @Test("the peek renders its glass through the gate, once")
    func peekTakesTheGate() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func show(",
                in: try Self.source("BarPeekPanel.swift")
            ),
            "BarPeekPanel.show is gone"
        )
        #expect(
            SourceScan.callSites(
                in: Array(body),
                for: "LiquidGlassGate.rendered"
            ).count == 1
        )
        let stored = try #require(
            SourceScan.callArguments(
                of: "LiquidGlassGate.rendered(",
                in: body
            )?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        #expect(stored == "stored")
        #expect(body.occurrences(of: stored) == 1)
    }

    /// The re-read may move the pointer onto another item, which
    /// the peek then follows; only after it is the peeked item's
    /// place worth comparing.
    @Test("the relayout re-checks the peek after the hover re-read")
    func relayoutChecksAfterTheReRead() throws {
        let body = try #require(
            SourceScan.declarationBody(
                after: "func relayout(",
                in: try Self.source("ShelfManager.swift")
            )
        )
        let check = try #require(body.range(of: "peek.syncToAnchor()"))
        let reRead = try #require(
            body.range(of: "syncHoverToPointer()", options: .backwards)
        )
        #expect(reRead.upperBound <= check.lowerBound)
    }

    /// The peek replaced the system tooltip on every bar item; a
    /// menu row's tooltip (`SpaceBarWindowMenu`) is a menu's, not
    /// a bar view's.
    @Test("no bar view registers a system tooltip")
    func noBarTooltip() throws {
        var found: [String] = []
        for file in try SourceScan.swiftSources(under: Self.bar) {
            let text = try SourceScan.strippedSource(at: file)
            for needle in ["addToolTip(", "NSViewToolTipOwner"]
            where text.contains(needle) {
                found.append("\(file.lastPathComponent): \(needle)")
            }
        }
        #expect(found.isEmpty, "\(found)")
    }
}
