import CoreGraphics

/// Pure resolve helpers split from AppBarStyle.swift (file-size
/// ceiling) — `SpaceBarStyle+Metrics` is the same seam on the
/// other bar. The Codable conformance stays with the struct.
extension AppBarStyle {
    /// The item font ladder: an explicit `font_size` wins;
    /// auto scales with the bar's cross dimension (its
    /// thickness), so a fat bar gets readable text and a slim
    /// one stays inside its strip. One resolution site shared
    /// by the item view, the slot measurement and the GUI
    /// preview so they can't drift —
    /// `SpaceBarStyle.identifierFontSize(forDepth:)` is the
    /// same shape on the other bar.
    public func resolvedFontSize(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        if fontSize > 0 { return fontSize }
        return min(max(thickness * 0.42, 9), 28)
    }
}
