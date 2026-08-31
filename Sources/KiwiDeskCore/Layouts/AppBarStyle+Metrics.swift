import CoreGraphics

/// Metric resolution helpers for `AppBarStyle` (`SpaceBarStyle+Metrics`).
extension AppBarStyle {
    /// Resolves font size from explicit setting or thickness scaling
    /// (`SpaceBarStyle.identifierFontSize(forDepth:)`).
    public func resolvedFontSize(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        if fontSize > 0 { return fontSize }
        return min(max(thickness * 0.42, 9), 28)
    }

    /// Rendered content folded with horizontal/vertical collapse
    /// (`Content.rendered(horizontal:)`).
    public var renderedContent: Content {
        content.rendered(horizontal: edge.isHorizontal)
    }

    /// Supported title character cap range (8...80), shared across both bars.
    public static let titleCapRange = 8...80

    /// Title cap clamped to `titleCapRange`.
    public var resolvedTitleCap: Int {
        min(
            max(titleCap, Self.titleCapRange.lowerBound),
            Self.titleCapRange.upperBound
        )
    }

    /// Truncates title to character cap with trailing ellipsis.
    public static func cappedTitle(
        _ title: String,
        to cap: Int
    ) -> String {
        guard title.count > cap else { return title }
        return String(title.prefix(cap)) + "…"
    }
}
