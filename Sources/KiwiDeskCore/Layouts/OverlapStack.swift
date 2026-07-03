import CoreGraphics

/// Emergency fallback shared by BSP, Stack, and Grid.
///
/// When a layout would shrink windows below `minWindowSize`,
/// downsizing halts: windows keep the minimum size and cascade
/// with a fixed vertical offset so every title bar stays
/// visible and clickable.
public enum OverlapStack {
    /// Vertical cascade offset keeping title bars reachable.
    public static let offset: CGFloat = 40

    /// Cascades `windows` inside `region`.
    public static func frames(
        for windows: some Collection<WindowID>,
        in region: CGRect,
        minSize: CGFloat
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        let size = CGSize(
            width: max(region.width, minSize),
            height: max(region.height, minSize)
        )
        for (index, window) in windows.enumerated() {
            result[window] = CGRect(
                x: region.minX,
                y: region.minY + CGFloat(index) * offset,
                width: size.width,
                height: size.height
            )
        }
        return result
    }
}
