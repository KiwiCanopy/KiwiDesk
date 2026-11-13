import CoreGraphics

/// A glyph SF Symbols has no single symbol for: a base symbol with a
/// small badge symbol in one corner, the base knocked out around it
/// (#3284, owner-picked from renders). Named `kiwi.*` so every
/// symbol slot — a row glyph, a window mark, a menu item — carries
/// it as a name; AppKit draws it through `SymbolImage`, SwiftUI
/// through the GUI's `GlyphImage`, both from this one table.
public struct ComposedSymbol: Sendable, Hashable {
    public enum Corner: Sendable, Hashable {
        case topTrailing, bottomTrailing
    }

    public let name: String
    public let base: String
    public let badge: String
    public let corner: Corner

    /// The badge's longer side as a share of the base's.
    public static let badgeShare: CGFloat = 0.56
    /// The knockout circle's diameter as a share of the badge's
    /// longer side, so the badge reads apart from the base.
    public static let haloShare: CGFloat = 1.3

    /// Go to last screen: the screen, turned back.
    public static let lastScreen = ComposedSymbol(
        name: "kiwi.screen.last",
        base: "display",
        badge: "arrow.uturn.backward",
        corner: .bottomTrailing
    )

    /// Sticky on this screen: the sticky pin, on one screen.
    public static let displaySticky = ComposedSymbol(
        name: "kiwi.sticky.screen",
        base: "pin.fill",
        badge: "display",
        corner: .topTrailing
    )

    /// The Desktop overview: the Desktops, as a grid.
    public static let desktopOverview = ComposedSymbol(
        name: "kiwi.desktops.overview",
        base: "rectangle.stack",
        badge: "square.grid.2x2",
        corner: .bottomTrailing
    )

    public static let all = [lastScreen, displaySticky, desktopOverview]

    /// The composed glyph `name` names; nil for a plain symbol.
    public init?(name: String) {
        guard let match = Self.all.first(where: { $0.name == name })
        else { return nil }
        self = match
    }

    private init(
        name: String,
        base: String,
        badge: String,
        corner: Corner
    ) {
        self.name = name
        self.base = base
        self.badge = badge
        self.corner = corner
    }
}
