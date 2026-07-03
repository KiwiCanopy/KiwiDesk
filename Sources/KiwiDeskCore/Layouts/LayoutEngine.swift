import CoreGraphics

/// Dispatches a layout mode to its algorithm.
///
/// Switching a space's mode instantly rearranges the same flat
/// window list with a different formula — no state conversion.
public enum LayoutEngine {
    public static func system(
        for mode: LayoutMode
    ) -> any LayoutSystem {
        switch mode {
        case .bsp:
            return BspLayout()
        case .stack:
            return StackLayout()
        case .scrolling:
            return ScrollingLayout()
        case .monocle:
            return MonocleLayout()
        case .grid:
            return GridLayout()
        case .floating:
            return FloatingLayout()
        }
    }

    /// Calculates geometry for a space's windows.
    public static func calculate(
        mode: LayoutMode,
        windows: [WindowID],
        context: LayoutContext
    ) -> [WindowID: CGRect] {
        system(for: mode)
            .calculateGeometry(for: windows, in: context)
    }
}
