import Foundation
import Testing

/// Boot's two held-Space calls (#1646), which no behavior suite
/// reaches: `finishBoot()` is not test-drivable, and
/// `HeldSpaceRestartTests` calls `retireGoneHeldMembers()` by
/// hand. The judge must run inside `finishBoot` AFTER
/// `seedAwayWindows()`, or an away window's filing is judged
/// before the seed; and `arrangeBootDesk` must hold the Spaces
/// BEFORE the replay and settle them after it.
///
/// Known limits: needles over comment-stripped source, so a call
/// moved behind a condition that never holds still matches.
@Suite("Held Space boot wiring (#1646)")
struct HeldSpaceBootWiringTests {
    private func body(of function: String, in path: String) throws
        -> String
    {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        let pattern = "func \(function)\\([\\s\\S]{0,4000}?\\n    \\}"
        return String(
            text[
                try #require(
                    text.range(of: pattern, options: .regularExpression)
                )
            ]
        )
    }

    private func offset(of needle: String, in text: String) throws -> Int {
        let range = try #require(text.range(of: needle), "\(needle)")
        #expect(text.components(separatedBy: needle).count == 2, "\(needle)")
        return text.distance(from: text.startIndex, to: range.lowerBound)
    }

    @Test("finishBoot judges the held windows after the away seed")
    func judgeFollowsTheSeed() throws {
        let tail = try body(
            of: "finishBoot",
            in: "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
        )
        #expect(
            try offset(of: "seedAwayWindows()", in: tail)
                < offset(of: "retireGoneHeldMembers()", in: tail)
        )
    }

    @Test("arrangeBootDesk holds before the replay and settles after")
    func holdsBracketTheReplay() throws {
        let arrange = try body(
            of: "arrangeBootDesk",
            in: "Sources/KiwiDeskCore/App/KiwiCore+Restore.swift"
        )
        let hold = try offset(of: "restoreHeldSpaces(from:", in: arrange)
        let replay = try offset(of: "restore(holds.snapshot)", in: arrange)
        let settle = try offset(of: "settleHeldSpacesAtBoot(", in: arrange)
        #expect(hold < replay && replay < settle)
    }
}
