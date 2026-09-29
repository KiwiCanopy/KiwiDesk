/// Which of a Space's app groups its chip draws (#1528 items
/// 17 and 20): centred on the anchor group and clamped to the
/// row. While the row holds more than `span + 1` groups the
/// chip is a fixed `span + 2` cells — a `+N` disc on each side
/// of `span` glyphs in the middle, `span + 1` glyphs and one
/// disc at an end — so a focus change never changes its length.
public enum SpaceBarStrip {
    /// One side's `+N` disc: the windows it hides, in row order,
    /// which its count draws and its menu lists, and whether the
    /// system focus is among them, which tints it (#376).
    public struct Disc: Equatable, Sendable {
        public var windows: [WindowID] = []
        public var holdsFocus = false

        /// No hidden windows: the side draws no disc.
        public static let none = Disc()
    }

    /// The groups a chip drew and how many the row held — two
    /// readings of one render, so a later render can tell a moved
    /// strip from a changed row (#1528 item 21).
    public struct Drawn: Equatable, Sendable {
        public var window: Range<Int>
        public var count: Int

        public init(window: Range<Int>, count: Int) {
            self.window = window
            self.count = count
        }

        /// Whether a row of `count` groups may keep drawing this
        /// window under the pointer: the same row, and a window
        /// `window(count:span:anchor:)` could have drawn for it.
        public func holds(count: Int, span: Int) -> Bool {
            count == self.count
                && SpaceBarStrip.isWindow(window, count: count, span: span)
        }
    }

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
    /// `count` groups.
    static func isWindow(
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

        /// The walk from `old` to `new`; nil when nothing moves,
        /// when the row changed under it — a window opened or
        /// closed shifts every index — and when the two windows
        /// share no group, a jump no glyph could walk across
        /// without passing over the neighbouring chips.
        public static func between(
            _ old: Drawn?,
            leadingDisc oldDisc: Bool,
            _ new: Drawn?,
            leadingDisc newDisc: Bool
        ) -> Walk? {
            guard let old, let new, old.count == new.count,
                old.window != new.window,
                old.window.overlaps(new.window)
            else { return nil }
            let lead = (oldDisc ? 1 : 0) - (newDisc ? 1 : 0)
            let front = new.window.lowerBound - old.window.lowerBound
            let back = new.window.upperBound - old.window.upperBound
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
