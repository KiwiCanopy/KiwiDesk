import Foundation
import Testing

/// The two wirings no unit test reaches (#761): what holds a
/// reveal is the shelf manager's one answer, and `updateBars()`
/// hands the revealer this pass's hiding shelves before the shelves
/// read them to keep or drop a panel.
@Suite("Shelf reveal wiring (#761)")
struct ShelfRevealWiringTests {
    private static func source(_ path: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDeskCore/\(path)")
        )
    }

    @Test("The reveal's hold is the shelves' one answer")
    func holdIsWired() throws {
        let boot = try Self.source("App/KiwiCore+Bootstrap.swift")
        #expect(boot.contains("shelves.reveal.holds = {"))
        #expect(boot.contains("shelves.surfaceHolds(key)"))
    }

    @Test("The revealer syncs before the shelves on both paths")
    func revealerSyncsFirst() throws {
        let shelf = try Self.source("App/KiwiCore+Shelf.swift")
        let hiding = shelf.ranges(of: "syncHidingShelves(")
        let shelves = shelf.ranges(of: "syncShelves(")
            .filter { !shelf[..<$0.lowerBound].hasSuffix("func ") }
        #expect(hiding.count == 2)
        #expect(shelves.count == 2)
        for (first, then) in zip(hiding, shelves) {
            #expect(first.lowerBound < then.lowerBound)
        }
    }
}
