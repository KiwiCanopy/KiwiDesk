import AppKit

/// The focus ring's sheen on a bar's active indicator (#1644
/// prototype): `BorderSheen`'s ramp over the outline's stroke or
/// the edge mark's fill, gated by the verdict the ring takes.
@MainActor
enum BarSheen {
    static let layerName = "kiwi.sheen"

    /// Paints or retires the ramp on `accent`, reading the
    /// geometry its layer already carries — so a caller runs it
    /// after both the accent's style and its frame are set.
    /// `outline` strokes the layer's border; otherwise the ramp
    /// fills the whole mark.
    static func apply(
        to accent: NSView,
        hex: String,
        outline: Bool,
        shelf: KiwiShelf
    ) {
        guard let host = accent.layer else { return }
        let existing =
            host.sublayers?.first {
                $0.name == layerName
            } as? CAGradientLayer
        guard LiquidGlassGate.drawsSheen(shelf), !accent.isHidden
        else {
            existing?.removeFromSuperlayer()
            return
        }
        let ramp = existing ?? CAGradientLayer()
        ramp.name = layerName
        if existing == nil { host.addSublayer(ramp) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ramp.frame = host.bounds
        let mask = (ramp.mask ?? CALayer())
        mask.frame = ramp.bounds
        mask.cornerRadius = host.cornerRadius
        mask.borderWidth = outline ? host.borderWidth : 0
        mask.borderColor = NSColor.black.cgColor
        mask.backgroundColor =
            outline ? nil : NSColor.black.cgColor
        ramp.mask = mask
        BorderSheen.paint(ramp, hex: hex)
        CATransaction.commit()
    }
}
