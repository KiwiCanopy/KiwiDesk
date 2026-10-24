import CoreGraphics

/// One Fill as glass paints it (#2569): the stored hex and how far
/// it fades, 0–100 (`KiwiShelf.fillFade`). Minted once from the
/// resolved shelf look (`KiwiShelf.glassFill`); a surface with a
/// colour of its own — a drag marker, the sticky mark — keeps
/// today's fade. A reading surface carries `minShare`, the far
/// end's floor (`KiwiShelf.readingGlassFill`).
public struct GlassFill: Sendable, Equatable {
    public var hex: String
    public var fade: CGFloat
    /// The least share of the anchor the far end keeps, 0–1.
    public var minShare: CGFloat

    public init(
        hex: String,
        fade: CGFloat = KiwiShelf.fillFadeRange.upperBound,
        minShare: CGFloat = 0
    ) {
        self.hex = hex
        self.fade = KiwiShelf.clampFillFade(fade)
        self.minShare = min(max(minShare, 0), 1)
    }
}
