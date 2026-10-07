import CoreGraphics
import Foundation

/// The hover peek's header ink (#1946, owner ruling 2026-10-07):
/// derived from the palette, never picked, as the empty ink is.
extension KiwiShelf {
    /// The share of `itemColor`'s own alpha the peek's app line
    /// draws at — a step under the titles, its 11 pt semibold
    /// carrying the rest of the hierarchy.
    public static let peekHeaderAlpha: CGFloat = 0.75

    /// The peek's header ink: `itemColor` at `peekHeaderAlpha`
    /// where that holds `idleInkFloor` on both grounds the peek
    /// draws on — the stored Fill, and the Fill as glass tints it,
    /// capped at `GlassTint.maxAlpha` — over white and black; the
    /// full item ink otherwise, so a custom palette nobody measured
    /// never loses its header.
    public var peekHeaderColor: String {
        let dimmed = itemColor(atShare: Self.peekHeaderAlpha)
        let grounds = [fillColor, fill(cappedAt: GlassTint.maxAlpha)]
        for ground in grounds {
            guard let ratio = worstContrast(dimmed, nil, on: ground),
                ratio >= Self.idleInkFloor
            else { return itemColor }
        }
        return dimmed
    }

    /// `fillColor` at no more than `cap` alpha, as `#RRGGBBAA`;
    /// an unparseable colour passes through.
    func fill(cappedAt cap: CGFloat) -> String {
        guard let rgba = DragVisual.parseHex(fillColor) else {
            return fillColor
        }
        let alpha = min(rgba.alpha, Double(cap))
        let bytes = [rgba.red, rgba.green, rgba.blue, alpha].map {
            String(format: "%02X", Int(($0 * 255).rounded()))
        }
        return "#" + bytes.joined()
    }
}
