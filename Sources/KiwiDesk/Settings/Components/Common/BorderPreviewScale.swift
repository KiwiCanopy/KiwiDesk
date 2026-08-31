import CoreGraphics

/// Remapping real border-width band to preview scales (#702, #786).
enum BorderPreviewScale {
    /// Width band `BorderStyle.clampedWidth` can produce.
    static let real: ClosedRange<CGFloat> = 1...20

    static func width(
        _ value: CGFloat,
        to band: ClosedRange<CGFloat>
    ) -> CGFloat {
        let span = real.upperBound - real.lowerBound
        let t = min(
            max((value - real.lowerBound) / span, 0),
            1
        )
        return band.lowerBound
            + t * (band.upperBound - band.lowerBound)
    }
}
