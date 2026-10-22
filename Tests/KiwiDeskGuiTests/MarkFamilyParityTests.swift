import Foundation
import Testing

/// The sticky mark (#414) and the overflow mark (#2235) ride every
/// channel together: the follow, the carry's owed stack and the
/// syncs go through the one door each in `KiwiCore+Marks.swift`, and
/// every other member the sticky mark's manager is reached by has
/// its twin in the same file. The members are read off the source,
/// so a new channel reds until it is twinned or ruled sticky-only.
/// A source scan, because a missed channel strands a mark only on a
/// live panel — the settle passes missed it once.
@Suite("Mark family parity (#2235)")
struct MarkFamilyParityTests {
    private static let core = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    /// Members reached on the sticky mark's manager alone, each
    /// with its reason — the one copy.
    private static let stickyOnly: [String: String] = [
        "flash": "the pills are the sticky mark's (#1799)",
        "sync": "each family syncs inside its own update function",
    ]

    /// Members that go through `KiwiCore+Marks.swift`'s doors.
    private static let doors: Set<String> = ["follow", "oweOrder"]

    /// `family.member` spellings per file, by member.
    private func members(
        of family: String
    ) throws -> [String: [String: Int]] {
        let pattern = try NSRegularExpression(
            pattern: "\\b\(family)\\.([A-Za-z]+)"
        )
        var found: [String: [String: Int]] = [:]
        for file in try SourceScan.swiftSources(under: Self.core) {
            let text = try SourceScan.strippedSource(at: file)
            let range = NSRange(text.startIndex..., in: text)
            for match in pattern.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text)
                else { continue }
                found[String(text[r]), default: [:]][
                    file.lastPathComponent,
                    default: 0
                ] += 1
            }
        }
        return found
    }

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
        let sticky = try members(of: "stickyMarks")
        let overflow = try members(of: "overflowMarks")
        for member in Self.doors {
            #expect(sticky[member] == ["KiwiCore+Marks.swift": 1])
            #expect(overflow[member] == ["KiwiCore+Marks.swift": 1])
        }
    }

    /// Every other member — read off the source, not listed — is
    /// spelled as often for the overflow mark, file by file.
    @Test("each remaining member has its twin in the same file")
    func remainingMembersAreTwinned() throws {
        let sticky = try members(of: "stickyMarks")
        let overflow = try members(of: "overflowMarks")
        let twinned = Set(sticky.keys)
            .subtracting(Self.doors)
            .subtracting(Self.stickyOnly.keys)
        #expect(twinned.count >= 5, "the scan found \(twinned)")
        for member in twinned {
            #expect(
                sticky[member] == overflow[member],
                "overflowMarks.\(member) differs from the sticky mark's"
            )
        }
        for member in Self.stickyOnly.keys {
            #expect(sticky[member] != nil, "ruled \(member) is gone")
        }
    }

    /// The bars sync the overflow marks (they wear the shelf's
    /// look) and the retile syncs the sticky marks with the rings;
    /// every other sync takes `updateMarks`.
    @Test("a sync of one family alone is a ruled site")
    func singleFamilySyncsAreRuled() throws {
        #expect(
            try sites(of: "updateStickyMarks(") == [
                "KiwiCore+StickyMarks.swift": 1,
                "KiwiCore+Marks.swift": 1,
                "KiwiCore+Retile.swift": 2,
            ]
        )
        #expect(
            try sites(of: "updateOverflowMarks(") == [
                "KiwiCore+OverflowMarks.swift": 1,
                "KiwiCore+Marks.swift": 1,
                "KiwiCore+Shelf.swift": 2,
            ]
        )
        #expect(try sites(of: "updateMarks(").values.reduce(0, +) >= 10)
    }
}
