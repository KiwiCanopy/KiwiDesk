import CoreGraphics

/// Grid track sizing (#763): one unnormalised weight per track
/// index, `1.0` an equal share. Sizes belong to POSITIONS, never
/// windows: the first `count` weights apply, a track past the
/// stored list draws at `1.0`, and a writer never truncates the
/// list when the count drops (owner ruling 2026-10-15).
public enum GridTracks {
    /// Where a track sits in a cell: the first and last track
    /// index it covers along one axis.
    public struct Span: Equatable, Sendable {
        public let first: Int
        public let last: Int
    }

    /// One cell's place in the grid, in arrangement order.
    public struct Cell: Equatable, Sendable {
        public let columns: Span
        public let rows: Span
    }

    /// The weight track `index` draws at — `1.0` past the list,
    /// and for a stored value that is not a positive number.
    public static func weight(
        _ weights: [Double],
        at index: Int
    ) -> Double {
        guard index < weights.count else { return 1 }
        let value = weights[index]
        return value.isFinite && value > 0 ? value : 1
    }

    /// `count` track lengths dividing `span` (gaps already
    /// removed) by weight, each lifted to its floor: a lifted
    /// track takes its room from the others in proportion to
    /// their weights. Where the floors do not fit, every track
    /// keeps `minimum` alone (the layout's cascade rule has proved
    /// equal tracks clear it), and only past that do the weights
    /// alone decide.
    public static func lengths(
        count: Int,
        weights: [Double],
        span: CGFloat,
        floors: [CGFloat],
        minimum: CGFloat
    ) -> [CGFloat] {
        guard count > 0 else { return [] }
        let w = (0..<count).map { weight(weights, at: $0) }
        let floor = (0..<count).map {
            max(minimum, $0 < floors.count ? floors[$0] : 0)
        }
        if floor.reduce(0, +) <= span {
            return lifted(w, span: span, floors: floor)
        }
        let base = Array(repeating: minimum, count: count)
        if minimum * CGFloat(count) <= span {
            return lifted(w, span: span, floors: base)
        }
        return proportional(w, span: span)
    }

    private static func lifted(
        _ w: [Double],
        span: CGFloat,
        floors floor: [CGFloat]
    ) -> [CGFloat] {
        var pinned = Set<Int>()
        while true {
            let free = w.indices.filter { !pinned.contains($0) }
            let room = span - pinned.reduce(0) { $0 + floor[$1] }
            let total = free.reduce(0) { $0 + w[$1] }
            var out = floor
            for index in free {
                out[index] = room * CGFloat(w[index] / total)
            }
            let under = free.filter { out[$0] < floor[$0] - 0.001 }
            guard !under.isEmpty else { return out }
            pinned.formUnion(under)
        }
    }

    /// Equal tracks, for a caller with no weights to apply.
    public static func equal(count: Int, span: CGFloat) -> [CGFloat] {
        proportional(Array(repeating: 1, count: count), span: span)
    }

    private static func proportional(
        _ weights: [Double],
        span: CGFloat
    ) -> [CGFloat] {
        let total = weights.reduce(0, +)
        return weights.map { span * CGFloat($0 / total) }
    }

    /// The span `count` tracks divide once the gaps between them
    /// are taken out.
    public static func span(
        of region: CGFloat,
        count: Int,
        gap: CGFloat
    ) -> CGFloat {
        region - gap * CGFloat(max(count - 1, 0))
    }

    /// Cell `index`'s columns and rows in a `columns`×`rows`
    /// grid filled in arrangement order — row by row when
    /// `rowMajor` — the last of `count` spanning the rest of its
    /// row (column) when `fillLast` (`fill_empty_cells`). The one
    /// statement of where a cell sits, which the render and the
    /// resize both read.
    public static func cell(
        _ index: Int,
        count: Int,
        columns: Int,
        rows: Int,
        rowMajor: Bool,
        fillLast: Bool
    ) -> Cell {
        let col = rowMajor ? index % columns : index / rows
        let row = rowMajor ? index / columns : index % rows
        let fills = fillLast && index == count - 1
        let lastCol = fills && rowMajor ? columns - 1 : col
        let lastRow = fills && !rowMajor ? rows - 1 : row
        return Cell(
            columns: Span(first: col, last: lastCol),
            rows: Span(first: row, last: lastRow)
        )
    }

    /// The outcome of moving one shared edge.
    public struct EdgeStep: Equatable, Sendable {
        /// The whole stored list after the write — never shorter
        /// than before.
        public let weights: [Double]
        /// True when a floor stopped the edge short of the ask.
        public let clamped: Bool
    }

    /// Moves the edge between adjacent tracks `grown` and
    /// `neighbor` so `grown` draws `delta` points longer (shorter
    /// for a negative delta) and `neighbor` gives exactly that,
    /// every other track keeping the length it drew. `draw` is the
    /// render's own solver for a weight list and `floors` its
    /// per-track floors, so a press lands what the next render
    /// draws even where a floor lifts a track. With no floor
    /// lifting anything the pair's weight sum is kept. Clamped so
    /// each of the pair keeps its floor; nil when the pair cannot
    /// hold both floors at all.
    public static func moveEdge(
        weights stored: [Double],
        grown: Int,
        neighbor: Int,
        floors: [CGFloat],
        delta: CGFloat,
        draw: ([Double]) -> [CGFloat]
    ) -> EdgeStep? {
        var weights = stored
        let needed = max(grown, neighbor) + 1
        while weights.count < needed { weights.append(1) }
        let drawn = draw(weights)
        let floor = { $0 < floors.count ? floors[$0] : 0 }
        let pair = drawn[grown] + drawn[neighbor]
        guard pair > 0, floor(grown) + floor(neighbor) <= pair + 0.001
        else { return nil }
        let wanted = drawn[grown] + delta
        let landed = min(
            max(wanted, floor(grown)),
            pair - floor(neighbor)
        )
        let target = [grown: landed, neighbor: pair - landed]
        // A free track's length is its weight times one shared
        // rate; a pair weighted at that rate draws its target and
        // leaves every free track where it was.
        let free = drawn.indices.first {
            target[$0] == nil && drawn[$0] > floor($0) + 0.01
        }
        if let free {
            for _ in 0..<24 {
                let now = draw(weights)
                let rate = now[free] / CGFloat(weight(weights, at: free))
                for (index, length) in target {
                    weights[index] = Double(max(length, 0.001) / rate)
                }
            }
        } else {
            bisect(&weights, grown, neighbor, landed, draw)
        }
        return EdgeStep(
            weights: weights,
            clamped: abs(landed - wanted) > 0.001
        )
    }

    /// The pair's share of its weight sum that draws `landed`:
    /// with no free track the others keep their floors whatever
    /// the pair's weights, so the sum is kept.
    private static func bisect(
        _ weights: inout [Double],
        _ grown: Int,
        _ neighbor: Int,
        _ landed: CGFloat,
        _ draw: ([Double]) -> [CGFloat]
    ) {
        let sum =
            weight(weights, at: grown) + weight(weights, at: neighbor)
        var low = 0.0
        var high = 1.0
        for _ in 0..<48 {
            let mid = (low + high) / 2
            weights[grown] = sum * mid
            weights[neighbor] = sum - weights[grown]
            if draw(weights)[grown] < landed {
                low = mid
            } else {
                high = mid
            }
        }
        let share = min(max((low + high) / 2, 0.000_001), 0.999_999)
        weights[grown] = sum * share
        weights[neighbor] = sum - weights[grown]
    }

    /// `weights` with its trailing `1.0` entries dropped — they
    /// draw what absence draws — so a list set back to equal
    /// leaves the file. Entries are never dropped elsewhere.
    public static func trimmed(_ weights: [Double]) -> [Double] {
        var out = weights
        while let last = out.last, abs(last - 1) < 0.000_001 {
            out.removeLast()
        }
        return out
    }
}
