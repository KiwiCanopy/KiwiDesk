/// Which of a Space's app groups its chip draws (#1528 items
/// 17 and 20): centred on the anchor group and clamped to the
/// row. While the row holds more than `span + 1` groups the
/// chip is a fixed `span + 2` cells — a `+N` disc on each side
/// of `span` glyphs in the middle, `span + 1` glyphs and one
/// disc at an end — so a focus change never changes its length.
public enum SpaceBarStrip {
    /// The drawn groups for `count` groups: everything when
    /// `count <= span + 1`, else centred on `anchor` and clamped.
    /// An even span puts its extra glyph on the trailing side;
    /// no anchor draws the start of the row.
    public static func window(
        count: Int,
        span: Int,
        anchor: Int?
    ) -> Range<Int> {
        let span = max(span, 1)
        guard count > span + 1 else { return 0..<max(count, 0) }
        let lead = (anchor ?? 0) - (span - 1) / 2
        if lead <= 0 { return 0..<(span + 1) }
        if lead + span >= count { return (count - span - 1)..<count }
        return lead..<(lead + span)
    }

    /// Whether `range` is a window `window` could have drawn for
    /// `count` groups — the one test a held window passes to be
    /// kept while the row changes under the pointer (item 21).
    public static func isWindow(
        _ range: Range<Int>,
        count: Int,
        span: Int
    ) -> Bool {
        let span = max(span, 1)
        guard count > span + 1 else { return range == 0..<max(count, 0) }
        if range == 0..<(span + 1) { return true }
        if range == (count - span - 1)..<count { return true }
        return range.count == span && range.lowerBound > 0
            && range.upperBound < count
    }

    /// The cells a chip spends on glyphs and discs for `count`
    /// groups — what the length measurement reads, so the length
    /// the shelf plans is the one the chip draws.
    public static func cells(count: Int, span: Int) -> Int {
        let span = max(span, 1)
        return count > span + 1 ? span + 2 : max(count, 0)
    }

    /// How a chip's glyphs walk when its strip moves (#1528 item
    /// 21), in cells: every kept glyph travels `cells` back to
    /// its new cell — a leading disc appearing or leaving counts,
    /// since it takes or frees the first cell — and the counts
    /// say how many glyphs leave or arrive at each end.
    public struct Walk: Equatable {
        public var cells: Int
        public var leavingFront = 0
        public var leavingBack = 0
        public var enteringFront = 0
        public var enteringBack = 0

        /// The walk from `old` to `new`; nil when nothing moves.
        public static func between(
            _ old: Range<Int>?,
            leadingDisc oldDisc: Bool,
            _ new: Range<Int>?,
            leadingDisc newDisc: Bool
        ) -> Walk? {
            guard let old, let new, old != new else { return nil }
            let lead = (oldDisc ? 1 : 0) - (newDisc ? 1 : 0)
            let front = new.lowerBound - old.lowerBound
            let back = new.upperBound - old.upperBound
            return Walk(
                cells: front + lead,
                leavingFront: max(front, 0),
                leavingBack: max(-back, 0),
                enteringFront: max(-front, 0),
                enteringBack: max(back, 0)
            )
        }
    }
}
