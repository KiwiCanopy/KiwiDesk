import CoreGraphics
import Foundation

/// Display shape classification for starter layout assignment (#678,
/// `ScreenClassTests`). Measured in points from `Display.frame`.
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

    /// Candidate layout modes for this shape, ordered best first
    /// (`StarterAllocation`, architect review 2026-08-11).
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
