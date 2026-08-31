import CoreGraphics

/// The ONE remap from the real border-width band onto a
/// preview's smaller span (#786): the same real width must carry
/// the same perceived weight on every picture, and two textual
/// copies disagree on the next retune with every test green
/// (#702's class).
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
