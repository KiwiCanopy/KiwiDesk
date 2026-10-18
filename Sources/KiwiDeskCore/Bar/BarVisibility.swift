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

    /// A cut or overlap under this many points is no cut: an
    /// echo's rounding, a border's outset.
    static let tolerance: CGFloat = 1

    /// The verdict for a window at `frame` on a screen whose usable
    /// area is `screen`, beneath the windows at `above` — all in one
    /// coordinate space, AX's (y grows down). `parked` is the
    /// stash's corner verdict, which leaves a sliver on screen.
    static func judge(
        _ frame: CGRect?,
        on screen: CGRect,
        above: [CGRect],
        parked: Bool
    ) -> BarVisibility {
        guard let frame, !parked else { return .hidden }
        let shown = frame.intersection(screen)
        guard !shown.isNull, shown.width > tolerance,
            shown.height > tolerance
        else { return .hidden }
        let cutX = frame.width - shown.width
        let cutY = frame.height - shown.height
        if cutX > tolerance || cutY > tolerance {
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
        if !overlapping.isEmpty { return .partly(shown: nil) }
        return .visible
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
}
