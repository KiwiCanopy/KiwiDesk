import CoreGraphics

/// How the Shortcuts side lays its sections out (#3570 ▸ Ruling 5):
/// one column until a single column would scroll past one
/// screenful, then column-major columns about 400 pt wide, at most
/// three, as even as section boundaries allow so a filtered sheet
/// rarely scrolls. A section never splits, so a column breaks only
/// before a section title, and VoiceOver reads down each column,
/// then on to the next; ↑ ↓ scroll the one shared scroll view.
/// Pure: section heights are estimated from their parts, never
/// measured.
struct ShortcutsColumnPlan: Equatable {
    /// One section's estimated parts.
    struct Section: Equatable {
        /// The title, and the caption under it if any.
        var header: CGFloat
        var rows: Int
        /// A row's height and the stack's spacing above it; the
        /// sheet hands its own (`ShortcutsSheetView.planned`).
        var pitch: CGFloat = 28

        var height: CGFloat { header + CGFloat(rows) * pitch }
    }

    /// Each column's sections, as ranges into the section list.
    let columns: [Range<Int>]

    static let columnWidth: CGFloat = 400
    static let maxColumns = 3
    /// The room above every section but a column's first.
    static let sectionGap: CGFloat = 16

    /// No sheet drawn.
    static let empty = ShortcutsColumnPlan(columns: [])

    /// The width the side's content asks for: a `columnWidth` pitch
    /// per column, `gap` of it between each two and none after the
    /// last, and `inset` on each side; 0 for one column, which takes
    /// the field row's width.
    func width(inset: CGFloat, gap: CGFloat) -> CGFloat {
        let count = CGFloat(columns.count)
        guard count > 1 else { return 0 }
        return count * Self.columnWidth - gap + 2 * inset
    }

    /// How many columns at that pitch fit `room` points less `inset`
    /// each side.
    static func columnsFitting(
        _ room: CGFloat,
        inset: CGFloat,
        gap: CGFloat
    ) -> Int {
        let fit = Int((room - 2 * inset + gap) / columnWidth)
        return min(max(fit, 1), maxColumns)
    }

    /// The plan under a sheet `cap` tall, in at most `columns`
    /// columns. `single` is the sections as one column draws them
    /// and `split` as a narrower column does, so a caption's wrap is
    /// judged at the width it would draw at.
    init(
        single: [Section],
        split: [Section],
        cap: CGFloat,
        columns limit: Int
    ) {
        let whole = Self.height(single.map(\.height), 0..<single.count)
        guard single.count == split.count, whole > cap else {
            columns = single.isEmpty ? [] : [0..<single.count]
            return
        }
        columns = Self.partition(
            split.map(\.height),
            cap: cap,
            limit: limit
        )
    }

    private init(columns: [Range<Int>]) {
        self.columns = columns
    }

    /// A column's height over `heights[range]`.
    static func height(_ heights: [CGFloat], _ range: Range<Int>) -> CGFloat {
        heights[range].reduce(0, +)
            + CGFloat(max(range.count - 1, 0)) * sectionGap
    }

    /// The fewest columns, from one, whose tallest fits `cap`; past
    /// `limit`, `limit` columns as even as a section boundary allows.
    static func partition(
        _ heights: [CGFloat],
        cap: CGFloat,
        limit: Int
    ) -> [Range<Int>] {
        let count = heights.count
        guard count > 0 else { return [] }
        let whole = [0..<count]
        guard height(heights, 0..<count) > cap else { return whole }
        var best = whole
        let most = min(limit, count)
        guard most >= 2 else { return whole }
        for columns in 2...most {
            best = evenest(heights, into: columns)
            if best.map({ height(heights, $0) }).max() ?? 0 <= cap {
                return best
            }
        }
        return best
    }

    /// `heights` cut into `columns` runs whose tallest is least.
    private static func evenest(
        _ heights: [CGFloat],
        into columns: Int
    ) -> [Range<Int>] {
        let count = heights.count
        // tallest[k][i]: the least tallest column cutting the first
        // i sections into k columns; cut[k][i]: the last run's start.
        var tallest = Array(
            repeating: Array(repeating: CGFloat.infinity, count: count + 1),
            count: columns + 1
        )
        var cut = Array(
            repeating: Array(repeating: 0, count: count + 1),
            count: columns + 1
        )
        tallest[0][0] = 0
        for k in 1...columns {
            for end in k...count {
                for start in (k - 1)..<end {
                    let run = height(heights, start..<end)
                    let worst = max(tallest[k - 1][start], run)
                    if worst < tallest[k][end] {
                        tallest[k][end] = worst
                        cut[k][end] = start
                    }
                }
            }
        }
        var ranges: [Range<Int>] = []
        var end = count
        for k in stride(from: columns, through: 1, by: -1) {
            let start = cut[k][end]
            ranges.insert(start..<end, at: 0)
            end = start
        }
        return ranges
    }
}
