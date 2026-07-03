import CoreGraphics

/// Monocle: every window is maximized to the full usable area.
///
/// All windows share the same frame; whichever is focused sits
/// on top, the rest are hidden behind it. No geometry splitting
/// regardless of window count.
public struct MonocleLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let usable = context.usable
        var result: [WindowID: CGRect] = [:]
        for window in windows {
            result[window] = usable
        }
        return result
    }
}
