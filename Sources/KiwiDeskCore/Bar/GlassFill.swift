import CoreGraphics

/// One Fill as glass paints it (#2569): the stored hex and how far
/// it fades, 0–100 (`KiwiShelf.fillFade`). Minted once from the
/// resolved shelf look (`KiwiShelf.glassFill`); a surface with a
/// colour of its own — a drag marker, the sticky mark — keeps
/// today's fade.
public struct GlassFill: Sendable, Equatable {
    public var hex: String
    public var fade: CGFloat

    public init(
        hex: String,
        fade: CGFloat = KiwiShelf.fillFadeRange.upperBound
    ) {
        self.hex = hex
        self.fade = KiwiShelf.clampFillFade(fade)
    }
}
