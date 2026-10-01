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
        let retires =
            source.components(separatedBy: ".retire(except:").count - 1
        #expect(retires == 4, "both managers, both branches")
        // Each retire takes the one `keep` set…
        #expect(
            source.components(separatedBy: ".retire(except: keep)").count - 1
                == retires
        )
        // …and `keep` is the live set united with the leaving ones,
        // built once per branch.
        #expect(
            source.components(separatedBy: ".union(shelves.leavingDisplays)")
                .count - 1 == 2
        )
    }
}
