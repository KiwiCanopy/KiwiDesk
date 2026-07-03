import CoreGraphics

/// Floating: KiwiDesk does not manage geometry at all.
///
/// Returns no frames, so every window keeps its current
/// position (default macOS behavior). KiwiDesk only intervenes
/// again when a window is re-tiled via `make_tiled`.
public struct FloatingLayout: LayoutSystem {
    public init() {}

    public func calculateGeometry(
        for windows: [WindowID],
        in context: LayoutContext
    ) -> [WindowID: CGRect] {
        [:]
    }
}
