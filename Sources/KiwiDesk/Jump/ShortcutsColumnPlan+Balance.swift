import CoreGraphics

/// The balanced fill (#3570 ▸ Ruling 5): the column-major cut, at
/// any row, whose heights never rise left to right, the first column
/// the longest (owner, 2026-11-23); among those the least tallest,
/// then the most even, then the one with more in earlier columns.
extension ShortcutsColumnPlan {
    /// One row of a section: the cut breaks between any two.
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
        let units = sections.enumerated().flatMap { index, section in
            (0..<section.rows).map { Unit(section: index, rows: $0..<$0 + 1) }
        }
        let runs = cut(units, sections, into: min(count, units.count))
        var columns = runs.map { pieces(units[$0]) }
        while columns.count < count { columns.append([]) }
        let tallest = runs.map { height(of: units[$0], sections) }.max()
        return (columns, tallest ?? 0)
    }

    /// The units' runs: `count` contiguous ranges, ordered tallest
    /// first where any cut allows it.
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
        // Each run's height grows by one row at a time, so the table
        // costs one pass per start.
        for start in 0..<total {
            var height: CGFloat = 0
            var last: Int?
            for end in (start + 1)...total {
                let unit = units[end - 1]
                let section = sections[unit.section]
                if unit.section != last {
                    if last != nil { height += sectionGap }
                    height +=
                        unit.rows.lowerBound > 0 && end - 1 == start
                        ? section.continued : section.header
                    last = unit.section
                }
                height += CGFloat(unit.rows.count) * section.pitch
                run[start][end] = height
            }
        }
        if let ordered = ordered(run, total: total, into: count) {
            return ordered
        }
        return evenest(run, total: total, into: count)
    }

    /// The cut whose heights never rise left to right, least tallest
    /// first, then most even, then with the most in the earlier
    /// columns; nil where no cut keeps that order. Every cut is
    /// tried: three columns at most keep it cheap.
    private static func ordered(
        _ run: [[CGFloat]],
        total: Int,
        into count: Int
    ) -> [Range<Int>]? {
        typealias Key = (tallest: CGFloat, squares: CGFloat, ends: [Int])
        var best: Key?
        func better(_ key: Key, than held: Key) -> Bool {
            if key.tallest != held.tallest {
                return key.tallest < held.tallest
            }
            if key.squares != held.squares {
                return key.squares < held.squares
            }
            return key.ends.lexicographicallyPrecedes(held.ends, by: >)
        }
        func walk(_ start: Int, _ ends: [Int], _ heights: [CGFloat]) {
            let left = count - ends.count
            guard left > 0 else {
                let key: Key = (
                    heights.max() ?? 0,
                    heights.reduce(0) { $0 + $1 * $1 },
                    ends
                )
                if best.map({ better(key, than: $0) }) ?? true { best = key }
                return
            }
            let last = left == 1 ? total : total - left + 1
            let first = left == 1 ? total : start + 1
            for end in first...last {
                let height = run[start][end]
                if let previous = heights.last, height > previous { continue }
                walk(end, ends + [end], heights + [height])
            }
        }
        walk(0, [], [])
        guard let ends = best?.ends else { return nil }
        return zip([0] + ends, ends).map { $0..<$1 }
    }

    /// The least-tallest, most even cut, for a sheet no ordered cut
    /// fits.
    private static func evenest(
        _ run: [[CGFloat]],
        total: Int,
        into count: Int
    ) -> [Range<Int>] {
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
                            && cost.squares <= held.squares)
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
