/// Which Spaces a hidden Space Bar's dots show (#761, owner
/// 2026-10-19): at most `cap`, so the mark always fits its band,
/// following the current Space as iOS page dots do. The row
/// slides only when the current Space would land on an end dot,
/// so it never jumps on every switch, and an end with Spaces
/// beyond it draws a small dot. Pure, so the slide is assertable.
enum ShelfDotWindow {
    /// The most dots a mark draws: six fill 60 pt, inside the
    /// 64 pt band (`ShelfMarkPlacement.bandLength`).
    static let cap = 6

    /// The first Space shown, of `count`, with `current` the shown
    /// Space's index and `previous` the last pass's first.
    static func start(count: Int, current: Int, previous: Int?) -> Int {
        guard count > cap else { return 0 }
        let last = count - cap
        var start = min(max(previous ?? current - cap / 2, 0), last)
        // An end dot holds the current Space only at the row's own
        // ends; elsewhere the row slides one in from the end.
        if current <= start { start = max(0, current - 1) }
        if current >= start + cap - 1 {
            start = min(last, current - (cap - 2))
        }
        return start
    }

    /// The window's indices into `count` Spaces from `start`, and
    /// whether each end has Spaces beyond it.
    static func shown(
        count: Int,
        start: Int
    ) -> (range: Range<Int>, before: Bool, after: Bool) {
        let end = min(count, start + cap)
        return (start..<end, start > 0, end < count)
    }
}
