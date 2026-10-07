import CoreGraphics
import Foundation

/// The hover peek's header ink (#1946, owner ruling 2026-10-07):
/// derived from the palette, never picked, as the empty ink is.
extension KiwiShelf {
    /// The share of `itemColor`'s own alpha the peek's app line
    /// draws at — a step under the titles, its 11 pt semibold
    /// carrying the rest of the hierarchy.
    public static let peekHeaderAlpha: CGFloat = 0.75

    /// The peek's header ink: `itemColor` taken a `peekStep`
    /// down, so a custom palette nobody measured never loses its
    /// header.
    public var peekHeaderColor: String {
        peekStep(itemColor, beneath: nil)
    }

    /// The count pill's window glyph: the badge ink taken the
    /// header's step down over the badge fill, so it reads as
    /// faint as the header; the number keeps the full badge ink.
    public var peekPillGlyphColor: String {
        peekStep(groupBadgeTextColor, beneath: groupBadgeColor)
    }

    /// The badge fill's weakest separation from the peek's grounds
    /// below which the count pill draws its ring (#1946): WCAG's
    /// non-text floor for a shape that must read as one.
    public static let peekPillRingFloor = 3.0

    /// Whether the count pill needs its ring: its fill separates from
    /// either ground the header step judges by less than
    /// `peekPillRingFloor`, over either wallpaper — or cannot be read.
    public var peekPillNeedsRing: Bool {
        peekPillSeparation.map { $0 < Self.peekPillRingFloor } ?? true
    }

    /// The badge fill against the plate, at its worst over both
    /// grounds and both wallpapers; nil where a colour is unreadable.
    public var peekPillSeparation: Double? {
        let grounds = [fillColor, fill(cappedAt: GlassTint.maxAlpha)]
        var worst: Double?
        for ground in grounds {
            guard
                let ratio = worstContrast(groupBadgeColor, nil, on: ground)
            else { return nil }
            worst = min(worst ?? ratio, ratio)
        }
        return worst
    }

    /// `ink` at `peekHeaderAlpha` of its own alpha where that holds
    /// `idleInkFloor` on both grounds the peek draws on — the
    /// stored Fill, and the Fill as glass tints it, capped at
    /// `GlassTint.maxAlpha` — each under `layer` where given, over
    /// white and black; `ink` itself otherwise.
    func peekStep(_ ink: String, beneath layer: String?) -> String {
        let dimmed = Self.hex(ink, atShare: Self.peekHeaderAlpha)
        let grounds = [fillColor, fill(cappedAt: GlassTint.maxAlpha)]
        for ground in grounds {
            guard
                let ratio = worstContrast(
                    dimmed,
                    nil,
                    on: ground,
                    beneath: layer
                ),
                ratio >= Self.idleInkFloor
            else { return ink }
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
