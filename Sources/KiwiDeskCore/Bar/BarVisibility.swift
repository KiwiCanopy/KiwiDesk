import CoreGraphics

/// Where the window an App Bar item stands for sits (#2234): fully
/// on screen and uncovered, partly so, or not at all. Judged from
/// the frames KiwiDesk issued and the order it intends, never a
/// WindowServer read — so a window another app or an untracked
/// panel covers still reads as visible.
public enum BarVisibility: Equatable, Sendable {
    case visible
    /// Partly visible: `shown` is the side of the window still on
    /// screen, nil where it is covered rather than cut.
    case partly(shown: Side?)
    case hidden

    public enum Side: Equatable, Sendable {
        case left, right, top, bottom
    }

    /// Whether an App Bar item draws its half-moon: only a partly
    /// visible window does.
    var drawsHalfMoon: Bool {
        if case .partly = self { return true }
        return false
    }

    /// The share of a covered window that must stay uncovered for
    /// it to read partly visible: at or under it, a window all but
    /// buried reads hidden. A CUT window reads partly once it shows
    /// more than a scrolling row's edge sliver
    /// (`ScrollingLayout.edgePeek`), the reach KiwiDesk leaves a
    /// scrolled-out window (owner, #2234, 2026-10-18).
    static let partlyFloor: CGFloat = 0.2

    /// A cut or overlap under this many points is no cut: an
    /// echo's rounding, a border's outset.
    static let tolerance: CGFloat = 1

    /// The verdict for a tile at `frame` in the area its layout
    /// fills, `screen`, beneath the tiles at `above` — all in one
    /// coordinate space, AX's (y grows down).
    static func judge(
        _ frame: CGRect?,
        on screen: CGRect,
        above: [CGRect]
    ) -> BarVisibility {
        guard let frame else { return .hidden }
        let shown = frame.intersection(screen)
        guard !shown.isNull, shown.width > tolerance,
            shown.height > tolerance
        else { return .hidden }
        let cutX = frame.width - shown.width
        let cutY = frame.height - shown.height
        if cutX > tolerance || cutY > tolerance {
            let along = cutX >= cutY ? shown.width : shown.height
            guard along > ScrollingLayout.edgePeek + tolerance else {
                return .hidden
            }
            return .partly(shown: side(of: shown, in: frame, cutX, cutY))
        }
        let overlapping = above.filter { cover in
            let overlap = shown.intersection(cover)
            return !overlap.isNull && overlap.width > tolerance
                && overlap.height > tolerance
        }
        if overlapping.contains(where: {
            $0.insetBy(dx: -tolerance, dy: -tolerance).contains(shown)
        }) {
            return .hidden
        }
        guard !overlapping.isEmpty else { return .visible }
        // The largest single cover: several overlapping covers read
        // as the biggest of them.
        let covered =
            overlapping.map { area(shown.intersection($0)) }.max() ?? 0
        guard area(shown) - covered > partlyFloor * area(frame) else {
            return .hidden
        }
        return .partly(shown: nil)
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.width * rect.height
    }

    /// The side of `frame` that `shown` keeps, on the axis cut more
    /// — nil where that axis is cut at both ends, which points no
    /// way to scroll.
    private static func side(
        of shown: CGRect,
        in frame: CGRect,
        _ cutX: CGFloat,
        _ cutY: CGFloat
    ) -> Side? {
        if cutX >= cutY {
            let left = shown.minX - frame.minX > tolerance
            let right = frame.maxX - shown.maxX > tolerance
            guard left != right else { return nil }
            return right ? .left : .right
        }
        let top = shown.minY - frame.minY > tolerance
        let bottom = frame.maxY - shown.maxY > tolerance
        guard top != bottom else { return nil }
        return bottom ? .top : .bottom
    }

    /// The verdict for a float at `frame` (#2234, owner 2026-10-18):
    /// hidden where the region `bounds` does not hold it whole,
    /// whatever the cut; under the focused window at `focus`, which
    /// sits above every float (#2284), hidden when wholly covered
    /// and partly with no side when overlapped at all; else lit. No
    /// share floor: any overlap shows the ring.
    static func judgeFloat(
        _ frame: CGRect?,
        on bounds: CGRect,
        under focus: CGRect?
    ) -> BarVisibility {
        guard let frame,
            bounds.insetBy(dx: -tolerance, dy: -tolerance).contains(frame)
        else { return .hidden }
        guard let focus else { return .visible }
        let overlap = frame.intersection(focus)
        guard !overlap.isNull, overlap.width > tolerance,
            overlap.height > tolerance
        else { return .visible }
        if focus.insetBy(dx: -tolerance, dy: -tolerance).contains(frame) {
            return .hidden
        }
        return .partly(shown: nil)
    }
}
