import AppKit

/// The active indicator under the sheen (#1644): both bars ask
/// these, so the outline and the edge mark take it alike.
extension BarAccent {
    /// The indicator's flat colour on its layer: clear while the
    /// sheen draws it, which would otherwise stack a translucent
    /// highlight twice.
    @MainActor
    static func flatInk(_ hex: String, sheen: Bool) -> CGColor {
        sheen ? NSColor.clear.cgColor : NSColor(kiwiHex: hex).cgColor
    }

    /// The indicator's sheen: a rim of `outline` width, or the
    /// edge mark's fill when nil, capped against the plate `fill`
    /// sits on; nil unless `drawn`.
    @MainActor
    static func sheen(
        _ hex: String,
        outline: CGFloat?,
        fill: String,
        drawn: Bool
    ) -> SheenRimView.Paint? {
        guard drawn else { return nil }
        return SheenRimView.Paint(
            hex: hex,
            width: outline,
            grounds: BorderSheen.grounds(plate: fill)
        )
    }
}
