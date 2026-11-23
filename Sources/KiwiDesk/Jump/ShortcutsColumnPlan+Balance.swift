import CoreGraphics

/// The balanced fill (#3570 ▸ Ruling 5b): the column-major cut whose
/// tallest column is shortest, ties going to the most even cut, so
/// no column is left short while another runs on.
extension ShortcutsColumnPlan {
    /// A run the cut may not split: a whole section, or one row of a
    /// section taller than `breakShare` × the even share.
    private struct Unit {
        let section: Int
        let rows: Range<Int>
    }

    /// The cut of `sections` into exactly `count` columns, empty
    /// columns last where there are fewer units than columns, and
    /// its tallest column.
    static func balanced(
        _ sections: [Section],
        into count: Int
    ) -> (columns: [[Piece]], tallest: CGFloat) {
        guard !sections.isEmpty else { return ([], 0) }
        let share = height(sections.map(\.height)) / CGFloat(count)
        let units = sections.enumerated().flatMap { index, section in
            section.height > breakShare * share
                ? (0..<section.rows).map {
                    Unit(section: index, rows: $0..<$0 + 1)
                }
                : [Unit(section: index, rows: 0..<section.rows)]
        }
        let runs = cut(units, sections, into: min(count, units.count))
        var columns = runs.map { pieces(units[$0]) }
        while columns.count < count { columns.append([]) }
        let tallest = runs.map { height(of: units[$0], sections) }.max()
        return (columns, tallest ?? 0)
    }

    /// The units' runs: `count` contiguous ranges whose tallest is
    /// least, then whose heights' squares sum least.
    private static func cut(
        _ units: [Unit],
        _ sections: [Section],
        into count: Int
    ) -> [Range<Int>] {
        let total = units.count
        var run = [[CGFloat]](
            repeating: [CGFloat](repeating: 0, count: total + 1),
            count: total + 1
        )
        for start in 0..<total {
            for end in (start + 1)...total {
                run[start][end] = height(of: units[start..<end], sections)
            }
        }
        typealias Cost = (tallest: CGFloat, squares: CGFloat)
        let none: Cost = (.infinity, .infinity)
        var best = [[Cost]](
            repeating: [Cost](repeating: none, count: total + 1),
            count: count + 1
        )
        var from = [[Int]](
            repeating: [Int](repeating: 0, count: total + 1),
            count: count + 1
        )
        best[0][0] = (0, 0)
        for column in stride(from: 1, through: count, by: 1) {
            for end in column...total {
                for start in (column - 1)..<end {
                    let before = best[column - 1][start]
                    let height = run[start][end]
                    let cost: Cost = (
                        max(before.tallest, height),
                        before.squares + height * height
                    )
                    let held = best[column][end]
                    if cost.tallest < held.tallest
                        || (cost.tallest == held.tallest
                            && cost.squares < held.squares)
                    {
                        best[column][end] = cost
                        from[column][end] = start
                    }
                }
            }
        }
        var runs: [Range<Int>] = []
        var end = total
        for column in stride(from: count, through: 1, by: -1) {
            let start = from[column][end]
            runs.insert(start..<end, at: 0)
            end = start
        }
        return runs
    }

    /// A column over `units`: each section's share under its title,
    /// or the repeated title where it continues, a gap between two.
    private static func height(
        of units: ArraySlice<Unit>,
        _ sections: [Section]
    ) -> CGFloat {
        pieces(units).enumerated().reduce(0) { sum, entry in
            let (index, piece) = entry
            let section = sections[piece.section]
            let title = piece.continued ? section.continued : section.header
            return sum + (index == 0 ? 0 : sectionGap) + title
                + CGFloat(piece.rows.count) * section.pitch
        }
    }

    /// `units` merged back into one piece per section.
    private static func pieces(_ units: ArraySlice<Unit>) -> [Piece] {
        var out: [Piece] = []
        for unit in units {
            if let last = out.last, last.section == unit.section {
                out[out.count - 1] = Piece(
                    section: unit.section,
                    rows: last.rows.lowerBound..<unit.rows.upperBound
                )
            } else {
                out.append(Piece(section: unit.section, rows: unit.rows))
            }
        }
        return out
    }
}
