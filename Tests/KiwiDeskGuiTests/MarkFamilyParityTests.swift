import Foundation
import Testing

/// The sticky mark (#414) and the overflow mark (#2235) ride every
/// channel together: the follow, the carry's owed stack and the
/// syncs go through the one door each in `KiwiCore+Marks.swift`, and
/// every other spelling of one family has its twin in the same file.
/// A source scan, because a missed channel strands a mark only on a
/// live panel — the settle passes missed it once, in the commit
/// that added the family.
@Suite("Mark family parity (#2235)")
struct MarkFamilyParityTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// Files under Core spelling `needle`, with their counts.
    private func sites(of needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let count = text.occurrences(of: needle)
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    @Test("the follow and the owed stack go through the one door")
    func doorsAreTheOnlyCallers() throws {
        for family in ["stickyMarks", "overflowMarks"] {
            for member in ["follow(", "oweOrder("] {
                #expect(
                    try sites(of: "\(family).\(member)")
                        == ["KiwiCore+Marks.swift": 1],
                    "\(family).\(member)"
                )
            }
        }
    }

    /// The retile syncs the overflow marks at the bars' tail (a
    /// shelf write repaints them without a pass) and the sticky
    /// marks with the rings; every other sync takes `updateMarks`.
    @Test("a sync of one family alone is a ruled site")
    func singleFamilySyncsAreRuled() throws {
        let sticky = try sites(of: "updateStickyMarks(")
        #expect(
            sticky == [
                "KiwiCore+StickyMarks.swift": 1,
                "KiwiCore+Marks.swift": 1,
                "KiwiCore+Retile.swift": 1,
            ]
        )
        let overflow = try sites(of: "updateOverflowMarks(")
        #expect(
            overflow == [
                "KiwiCore+OverflowMarks.swift": 1,
                "KiwiCore+Marks.swift": 1,
                "KiwiCore+Retile.swift": 1,
            ]
        )
        #expect(try sites(of: "updateMarks(").values.reduce(0, +) >= 10)
    }

    /// Every other member either family's manager is wired or
    /// called by appears as often for the other, file by file.
    @Test("each remaining spelling has its twin in the same file")
    func remainingSpellingsAreTwinned() throws {
        let members = [
            "isAnimating =", "commandedFrame =",
            "isWindowServerTracked =", "reposition(", "reassert(",
            "clear()",
        ]
        for member in members {
            let sticky = try sites(of: "stickyMarks.\(member)")
            #expect(!sticky.isEmpty, "stickyMarks.\(member) is gone")
            #expect(
                sticky == (try sites(of: "overflowMarks.\(member)")),
                "overflowMarks.\(member) differs from the sticky mark's"
            )
        }
    }
}
