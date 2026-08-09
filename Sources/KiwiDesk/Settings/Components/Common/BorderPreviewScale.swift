import CoreGraphics

/// Pure math for the border-width readouts (#786 review): the
/// ONE remap from the real 1–20 pt border-width band onto a
/// preview's smaller span, like `GapPreviewScale` one shelf
/// over. The editor's 96 pt mock windows read through 1–7; the
/// Home tile's third-size panes read through a proportionally
/// smaller band — the same real width must carry the same
/// perceived weight on both pictures (owner, 2026-08-09), and
/// two textual copies of the remap disagree on the next retune
/// with every test green (#702's class, one preview down).
enum BorderPreviewScale {
    /// The width band `BorderStyle.clampedWidth` can produce.
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
