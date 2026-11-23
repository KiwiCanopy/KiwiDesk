import CoreGraphics
import Testing

@testable import KiwiDesk

/// The Shortcuts side's columns (#3570 ▸ Ruling 5, amended with the
/// ui-designer 2026-11-23): one column while it fits the sheet's
/// room, else the fewest that do at a 460 pt pitch, at most three;
/// the fill is column-major, its tallest column shortest, and a
/// section past 1.25 × the even share breaks at a row. Pure
/// arithmetic.
@Suite("Shortcuts column plan")
struct ShortcutsColumnPlanTests {
    private typealias Plan = ShortcutsColumnPlan
    private typealias Section = ShortcutsColumnPlan.Section

    /// A section of `rows` rows under an 18 pt title: 18 + 28 × rows.
    private func section(_ rows: Int) -> Section {
        Section(header: 18, rows: rows)
    }

    private func count(
        _ sections: [Section],
        cap: CGFloat,
        closing: CGFloat = 0,
        limit: Int = 3
    ) -> Int {
        Plan.count(
            single: sections,
            split: sections,
            closing: closing,
            cap: cap,
            limit: limit
        )
    }

    @Test("one column while it fits the room")
    func oneColumnFits() {
        let sections = [section(4), section(3), section(2)]
        let tall = Plan.height(sections.map(\.height))
        #expect(count(sections, cap: tall) == 1)
        #expect(Plan.width(columns: 1, inset: 16, gap: 24) == 0)
    }

    @Test("past the room, the fewest columns that fit, up to the limit")
    func fewestColumns() {
        let sections = [section(4), section(4), section(4), section(4)]
        // Four 130 pt sections: two to a column is 276 pt.
        #expect(count(sections, cap: 276) == 2)
        #expect(count(sections, cap: 275) == 3)
        #expect(count(sections, cap: 10) == 3)
        #expect(count(sections, cap: 10, limit: 2) == 2)
        #expect(count(sections, cap: 10, limit: 1) == 1)
    }

    /// The full-width closing section takes its height and a gap off
    /// the room every count is judged in.
    @Test("the closing section's room counts against the columns")
    func closingTakesRoom() {
        let sections = [section(4), section(4)]
        let whole = Plan.height(sections.map(\.height))
        #expect(count(sections, cap: whole) == 1)
        #expect(count(sections, cap: whole, closing: 30) == 2)
        #expect(count(sections, cap: whole + 46, closing: 30) == 1)
    }

    @Test("the fill reads column-major and keeps every row once")
    func columnMajor() {
        let sections = [section(2), section(5), section(3), section(4)]
        let plan = Plan(sections: sections, columns: 2)
        #expect(plan.columns.count == 2)
        let order = plan.columns.joined().flatMap { piece in
            piece.rows.map { piece.section * 100 + $0 }
        }
        let expected = sections.enumerated().flatMap { index, section in
            (0..<section.rows).map { index * 100 + $0 }
        }
        #expect(order == expected)
    }

    /// Breaks only before a title where no section is past 1.25 × the
    /// even share, and the cut makes the tallest column shortest:
    /// four even sections split two and two, not one and three.
    @Test("the cut balances at section boundaries")
    func balancesAtSections() {
        let even = Plan(
            sections: Array(repeating: section(4), count: 4),
            columns: 2
        )
        #expect(even.columns.map { $0.map(\.section) } == [[0, 1], [2, 3]])
        #expect(even.columns.joined().allSatisfy { !$0.continued })
        let tall = Plan.balanced(
            [section(2), section(2), section(6)],
            into: 2
        )
        // 74 + 16 + 74 = 164 over 186, never 74 over 276.
        #expect(tall.columns.map { $0.map(\.section) } == [[0, 1], [2]])
        #expect(tall.tallest == 186)
    }

    /// Where several cuts share the shortest tallest column, the
    /// most even wins: no column ends early beside a long one.
    @Test("a tie goes to the most even cut")
    func tieGoesToTheEvenest() {
        // A 300 pt one-row section fixes the tallest whatever the cut.
        let tall = Section(header: 272, rows: 1)
        let plan = Plan.balanced(
            [tall] + Array(repeating: section(1), count: 4),
            into: 3
        )
        #expect(plan.tallest == 300)
        #expect(
            plan.columns.map { $0.map(\.section) } == [[0], [1, 2], [3, 4]]
        )
    }

    /// A section past 1.25 × the even share breaks at a row; its
    /// rows go on at the next column's top under the repeated title.
    @Test("an oversized section breaks at a row and continues")
    func oversizedBreaks() throws {
        let sections = [section(30), section(2)]
        let plan = Plan.balanced(sections, into: 2)
        let first = try #require(plan.columns.first?.first)
        let next = try #require(plan.columns.last?.first)
        #expect(plan.columns[0].map(\.section) == [0])
        #expect(next.section == 0)
        #expect(next.continued)
        #expect(first.rows.upperBound == next.rows.lowerBound)
        // Balanced, not 858 over 74.
        let whole = Plan.height(sections.map(\.height))
        #expect(plan.tallest < whole * 0.6)
        // Under the share, the same section stays whole.
        let kept = Plan.balanced([section(6), section(6)], into: 2)
        #expect(kept.columns.joined().allSatisfy { !$0.continued })
    }

    @Test("fewer pieces than columns leave the last columns empty")
    func emptyColumns() {
        let plan = Plan(sections: [section(1)], columns: 3)
        #expect(plan.columns.count == 3)
        #expect(plan.columns[0].count == 1)
        #expect(plan.columns[1].isEmpty && plan.columns[2].isEmpty)
    }

    /// Two columns at the 460 pt pitch, the 24 pt gap between them
    /// and a 16 pt inset each side take 928 pt; three take 1388.
    @Test("the columns that fit the room, one to three")
    func columnsFitting() {
        func fit(_ room: CGFloat) -> Int {
            Plan.columnsFitting(room, inset: 16, gap: 24)
        }
        #expect(Plan.width(columns: 2, inset: 16, gap: 24) == 928)
        #expect(fit(928) == 2)
        #expect(fit(927) == 1)
        #expect(fit(1000) == 2)
        #expect(fit(1387) == 2)
        #expect(fit(1388) == 3)
        #expect(fit(5000) == 3)
        #expect(fit(100) == 1)
    }
}
