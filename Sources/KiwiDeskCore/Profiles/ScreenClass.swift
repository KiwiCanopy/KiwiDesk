import CoreGraphics
import Foundation

/// Display shape classification for starter layout assignment
/// (#678). Measured in POINTS from `Display.frame` — a 5K and a
/// 1440p 27" want identical layouts; `visibleFrame` is chrome the
/// user can move, and a screen does not change shape when they
/// do. The four cases are disjoint only because they are tested
/// in `allCases` order — a case added here states where in that
/// order it goes (`ScreenClassTests` pins order and boundaries).
public enum ScreenClass: String, Sendable, CaseIterable, Codable {
    /// Taller than wide.
    case pivoted
    /// Wide enough to hold three or four full columns.
    case ultrawide
    /// Too narrow for a two-way split.
    case laptop
    /// The 2K / 4K middle.
    case desktop

    /// Width threshold for ultrawide class (3000 pt).
    public static let ultrawideWidth: CGFloat = 3000
    /// Aspect ratio threshold for ultrawide class (2.1).
    public static let ultrawideAspect: CGFloat = 2.1
    /// Upper width bound for laptop class (1900 pt).
    public static let laptopWidth: CGFloat = 1900

    /// Classifies display dimensions in points.
    public static func of(_ size: CGSize) -> ScreenClass {
        guard size.width > 0, size.height > 0 else { return .desktop }
        if size.height > size.width { return .pivoted }
        if size.width >= ultrawideWidth
            || size.width / size.height >= ultrawideAspect
        {
            return .ultrawide
        }
        if size.width < laptopWidth { return .laptop }
        return .desktop
    }

    /// Classifies a connected display by its `frame.size`.
    public static func of(_ display: Display) -> ScreenClass {
        of(display.frame.size)
    }

    /// Candidate layouts for this shape, best first. The ABSENCES
    /// are as deliberate as the entries: `track` is out of
    /// desktop/laptop, `monocle` out of desktop/ultrawide, `bsp`
    /// only under desktop (absurd at 3440 pt, unusable at
    /// 1728 pt). `floating` is in NO list — one Floating space per
    /// setup is a rule about the SETUP, owned end to end by
    /// `StarterAllocation` (architect review, 2026-08-11), which
    /// also owns each screen's LEAD before this list is read.
    public var layouts: [LayoutMode] {
        switch self {
        case .laptop:
            [.scrolling, .monocle]
        case .desktop:
            [.grid, .stack, .bsp, .scrolling]
        case .ultrawide:
            [.track, .grid, .stack]
        case .pivoted:
            [.stack, .grid, .monocle]
        }
    }
}
