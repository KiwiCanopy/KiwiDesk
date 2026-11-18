import CoreGraphics

/// How deep the handles draw (#3451): a look style path, in whole
/// points, the one depth an Auto bar's handle and the Pocket's tab
/// both take (#3361).
extension KiwiShelf {
    /// Bounds of `handleThickness` in pt: below 2 the two hairlines
    /// leave no core, past 6 the handle nears its 9 pt hover band.
    public static let handleThicknessRange: ClosedRange<CGFloat> = 2...6

    /// `thickness` rounded to a whole point and kept in
    /// `handleThicknessRange`.
    public static func clampHandleThickness(
        _ thickness: CGFloat
    ) -> CGFloat {
        min(
            max(thickness.rounded(), handleThicknessRange.lowerBound),
            handleThicknessRange.upperBound
        )
    }

    /// The depth every handle and the Pocket's tab draw at.
    public var resolvedHandleThickness: CGFloat {
        Self.clampHandleThickness(handleThickness)
    }
}
