import CoreGraphics

/// Monocle: every window is maximized to the full usable area.
///
/// All windows share the same frame; whichever is focused sits
/// on top, the rest are hidden behind it. No geometry splitting
/// regardless of window count. With the indicator bar enabled,
/// its strip is carved out of the usable area first, so windows
/// and bar never overlap and both stay on the monitor.
public struct MonocleLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        let frame = context.monocle.windowFrame(
            in: context.usable,
            inner: context.gaps.inner
        )
        var result: [WindowID: CGRect] = [:]
        for window in windows {
            result[window] = frame
        }
        return result
    }
}
