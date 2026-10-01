import Foundation
import Testing

@testable import KiwiDesk

/// `KiwiCore.updateBars()` retires a bar overlay only for a display
/// outside the connected set UNITED with the displays whose shelf is
/// still fading (#1838): dropped mid-fade, a display re-enumerating
/// inside the glide re-joins as a new section. `ShelfFadeTests`
/// holds the manager's reading; this holds its one consumer, which
/// no headless core can drive through a departing display.
@Suite("Shelf retire wiring (#1838)")
struct ShelfRetireWiringTests {
    private static func source() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("App")
            .appendingPathComponent("KiwiCore+Shelf.swift")
        let stripped = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        try #require(!stripped.isEmpty)
        return stripped
    }

    @Test("Every retire spares the displays whose shelf is leaving")
    func retireSparesLeavingDisplays() throws {
        let source = try Self.source()
        // The one retire door: both managers take the one `keep`…
        let retires =
            source.components(separatedBy: ".retire(except:").count - 1
        #expect(retires == 2, "both managers, one door")
        #expect(
            source.components(separatedBy: ".retire(except: keep)").count - 1
                == retires
        )
        // …which is the live set united with the leaving displays…
        #expect(
            source.components(separatedBy: ".union(shelves.leavingDisplays)")
                .count - 1 == 1
        )
        // …and both branches of `updateBars()` call that door AFTER
        // syncing the shelves, which is when a departing display's
        // shelf starts leaving: each call's preceding text, back to
        // the previous call or the function head, holds a sync.
        let head = try #require(
            source.range(of: "func updateBars()")?.upperBound
        )
        let decl = try #require(
            source.range(of: "private func retireDepartedBars")?.lowerBound
        )
        let body = String(source[head..<decl])
        let door = "retireDepartedBars(live:"
        let segments = body.components(separatedBy: door)
        #expect(segments.count == 3, "two call sites")
        for segment in segments.dropLast() {
            #expect(segment.contains("syncShelves("), "a retire before sync")
        }
    }
}
