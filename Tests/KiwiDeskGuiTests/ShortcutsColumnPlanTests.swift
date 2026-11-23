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
        let plan = Plan(
            single: sections,
            split: sections,
            cap: tall,
            columns: 3
        )
        #expect(plan.columns == [0..<3])
        #expect(plan.width(inset: 16, gap: 24) == 0)
    }

    @Test("past the room, the fewest columns that fit")
    func fewestColumns() {
        let sections = [section(4), section(4), section(4), section(4)]
        let one = Plan.height(sections.map(\.height), 0..<4)
        let half = Plan.height(sections.map(\.height), 0..<2)
        let two = Plan(
            single: sections,
            split: sections,
            cap: half,
            columns: 3
        )
        #expect(two.columns == [0..<2, 2..<4])
        #expect(
            two.width(inset: 16, gap: 24) == 2 * Plan.columnWidth - 24 + 32
        )
        // A pixel short of the two-column height takes three.
        let three = Plan(
            single: sections,
            split: sections,
            cap: half - 1,
            columns: 3
        )
        #expect(three.columns.count == 3)
        // Never past the limit, even where a column then scrolls.
        let capped = Plan(
            single: sections,
            split: sections,
            cap: 10,
            columns: 3
        )
        #expect(capped.columns.count == 3)
        let lone = Plan(
            single: sections,
            split: sections,
            cap: one - 1,
            columns: 1
        )
        #expect(lone.columns == [0..<4])
    }

    /// A section never splits: the cut is the most even one along
    /// section boundaries, every section in exactly one column.
    @Test("a column breaks only before a section, evenly")
    func breaksAtSections() {
        let sections = [section(10), section(1), section(1), section(10)]
        let plan = Plan(
            single: sections,
            split: sections,
            cap: 300,
            columns: 2
        )
        #expect(plan.columns == [0..<2, 2..<4])
        #expect(plan.columns.flatMap { Array($0) } == [0, 1, 2, 3])
        // One section alone stays one column, however tall.
        let lone = Plan(
            single: [section(40)],
            split: [section(40)],
            cap: 100,
            columns: 3
        )
        #expect(lone.columns == [0..<1])
    }

    /// Two columns at the 400 pt pitch, the 24 pt gap between them
    /// and a 16 pt inset each side take 808 pt; three take 1208.
    @Test("the columns that fit the room, one to three")
    func columnsFitting() {
        func fit(_ room: CGFloat) -> Int {
            Plan.columnsFitting(room, inset: 16, gap: 24)
        }
        #expect(fit(808) == 2)
        #expect(fit(807) == 1)
        #expect(fit(1207) == 2)
        #expect(fit(1208) == 3)
        #expect(fit(5000) == 3)
        #expect(fit(100) == 1)
    }

    /// One column is judged at its own wrap: a sheet that fits one
    /// wide column stays one even where narrower columns would wrap
    /// its captions taller.
    @Test("one column is judged at the width it draws at")
    func singleJudgedAtItsWidth() {
        let single = [Section(header: 40, rows: 4), section(4)]
        let split = [Section(header: 120, rows: 4), section(4)]
        let fits = Plan.height(single.map(\.height), 0..<2)
        let plan = Plan(single: single, split: split, cap: fits, columns: 3)
        #expect(plan.columns == [0..<2])
        let cut = Plan(single: single, split: split, cap: fits - 1, columns: 3)
        #expect(cut.columns == [0..<1, 1..<2])
    }
}
