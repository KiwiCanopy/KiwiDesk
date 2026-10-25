import CoreGraphics

/// Emergency overflow fallback cascading windows with title bars visible.
public enum OverlapStack {
    /// Vertical cascade offset keeping title bars reachable.
    public static let offset: CGFloat = 40

    /// Cascades `windows` inside `region` (`KiwiCore+ZOrder`, #197).
    public static func frames(
        for windows: some Collection<WindowID>,
        in region: CGRect,
        minSize: MinSize,
        fitToRegion: Bool = false
    ) -> [WindowID: CGRect] {
        var result: [WindowID: CGRect] = [:]
        let cascade =
            CGFloat(max(windows.count - 1, 0)) * offset
        let fullHeight = max(region.height, minSize.height)
        let size = CGSize(
            width: max(region.width, minSize.width),
            height: fitToRegion
                ? max(fullHeight - cascade, minSize.height)
                : fullHeight
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
