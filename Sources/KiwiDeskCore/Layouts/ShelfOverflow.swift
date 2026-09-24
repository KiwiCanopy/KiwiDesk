import CoreGraphics

/// How a shelf section shows what it cannot fit (#1517): no
/// arrows — the content fades on each hidden side. The ONE home of
/// the overflow arithmetic both sections and the Settings preview
/// read, pure so it is unit-testable (`ShelfOverflowTests`).
public enum ShelfOverflow {
    /// The fade's bounds (pt) and its share of a section's visible
    /// length it may never exceed, so a short section keeps most
    /// of its content legible.
    public static let fadeRange: ClosedRange<CGFloat> = 32...72
    public static let fadeShareCap: CGFloat = 0.25

    /// One side's fade length: twice the thickness, clamped to
    /// `fadeRange`, capped at `fadeShareCap` of `visible`. With no
    /// `visible` it is the uncapped length — the worst case a
    /// floor must budget for.
    public static func fadeLength(
        thickness: CGFloat,
        visible: CGFloat? = nil
    ) -> CGFloat {
        let scaled = min(
            max(2 * thickness, fadeRange.lowerBound),
            fadeRange.upperBound
        )
        guard let visible else { return scaled }
        return min(scaled, max(visible, 0) * fadeShareCap)
    }
}
