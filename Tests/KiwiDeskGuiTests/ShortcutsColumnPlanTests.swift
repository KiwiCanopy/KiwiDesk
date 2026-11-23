import CoreGraphics
import Testing

@testable import KiwiDesk

/// The Shortcuts side's columns (#3570 ▸ Ruling 5): one column until
/// it would scroll past the sheet's room, then column-major columns,
/// at most three, as even as section boundaries allow, each break
/// before a section title. Pure arithmetic.
@Suite("Shortcuts column plan")
struct ShortcutsColumnPlanTests {
    private typealias Plan = ShortcutsColumnPlan
    private typealias Section = ShortcutsColumnPlan.Section

    /// A section of `rows` rows under an 18 pt title.
    private func section(_ rows: Int) -> Section {
        Section(header: 18, rows: rows)
    }

    @Test("one column while it fits the room")
    func oneColumnFits() {
        let sections = [section(4), section(3), section(2)]
        let tall = Plan.height(sections.map(\.height), 0..<3)
        let plan = Plan(sections: sections, cap: tall, columns: 3)
        #expect(plan.columns == [0..<3])
        #expect(plan.width(inset: 16) == 0)
    }

    @Test("past the room, the fewest columns that fit")
    func fewestColumns() {
        let sections = [section(4), section(4), section(4), section(4)]
        let one = Plan.height(sections.map(\.height), 0..<4)
        let half = Plan.height(sections.map(\.height), 0..<2)
        let two = Plan(sections: sections, cap: half, columns: 3)
        #expect(two.columns == [0..<2, 2..<4])
        #expect(two.width(inset: 16) == 2 * Plan.columnWidth + 32)
        // A pixel short of the two-column height takes three.
        let three = Plan(sections: sections, cap: half - 1, columns: 3)
        #expect(three.columns.count == 3)
        // Never past the limit, even where a column then scrolls.
        let capped = Plan(sections: sections, cap: 10, columns: 3)
        #expect(capped.columns.count == 3)
        let lone = Plan(sections: sections, cap: one - 1, columns: 1)
        #expect(lone.columns == [0..<4])
    }

    /// A section never splits: the cut is the most even one along
    /// section boundaries, every section in exactly one column.
    @Test("a column breaks only before a section, evenly")
    func breaksAtSections() {
        let sections = [section(10), section(1), section(1), section(10)]
        let plan = Plan(sections: sections, cap: 300, columns: 2)
        #expect(plan.columns == [0..<2, 2..<4])
        #expect(plan.columns.flatMap { Array($0) } == [0, 1, 2, 3])
        // One section alone stays one column, however tall.
        let lone = Plan(sections: [section(40)], cap: 100, columns: 3)
        #expect(lone.columns == [0..<1])
    }

    @Test("the columns that fit the room, one to three")
    func columnsFitting() {
        #expect(Plan.columnsFitting(700, inset: 16) == 1)
        #expect(Plan.columnsFitting(832, inset: 16) == 2)
        #expect(Plan.columnsFitting(3000, inset: 16) == 3)
        #expect(Plan.columnsFitting(100, inset: 16) == 1)
    }
}
