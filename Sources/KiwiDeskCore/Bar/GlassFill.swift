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
    public private(set) var minShare: CGFloat

    public init(
        hex: String,
        fade: CGFloat = KiwiShelf.fillFadeRange.upperBound
    ) {
        self.init(hex: hex, fade: fade, minShare: 0)
    }

    /// With a reading floor: only `KiwiShelf.readingGlassFill`'s
    /// family mints one, never a share typed at a call site.
    init(hex: String, fade: CGFloat, minShare: CGFloat) {
        self.hex = hex
        self.fade = KiwiShelf.clampFillFade(fade)
        self.minShare = min(max(minShare, 0), 1)
    }
}

/// A Fill as SwiftUI glass draws it (`GlassTint.paint`, #2569): one
/// sRGB colour at two alphas along a fade, and the scheme the Fill
/// pins. Made only by the mint, so the cap holds here too.
public struct GlassPaint: Sendable, Equatable {
    /// The scheme a Fill decides (`GlassTint.pin`).
    public enum Pin: Sendable, Equatable { case dark, light }

    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat
    public let anchorAlpha: CGFloat
    public let farAlpha: CGFloat
    /// The fade's ends in SwiftUI's unit space (y grows down).
    public let start: CGPoint
    public let end: CGPoint
    public let pin: Pin?
}
