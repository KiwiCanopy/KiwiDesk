import CoreGraphics

/// A glyph SF Symbols has no single symbol for: a base symbol with a
/// small badge symbol on one corner, overhanging it, the base
/// cleared in a ring around the badge (#3284, owner-picked from
/// renders). Named `kiwi.*` so every symbol slot — a row glyph, a
/// window mark, a menu item — carries it as a name; AppKit draws it
/// through `SymbolImage`, SwiftUI through the GUI's `GlyphImage`,
/// both from this one table and its one `layout`.
public struct ComposedSymbol: Sendable, Hashable {
    public enum Corner: Sendable, Hashable {
        case topTrailing, bottomTrailing
    }

    public let name: String
    public let base: String
    public let badge: String
    public let corner: Corner
    /// How far the badge square reaches past the base's trailing
    /// edge and its corner's edge, as shares of the square's side.
    public let overhang: CGVector

    /// The badge square's side as a share of the base's longer side.
    public static let badgeShare: CGFloat = 0.5
    /// The ring cleared around the badge square, as a share of its
    /// side, so the badge reads apart from the base.
    public static let gapShare: CGFloat = 0.12
    /// How many weight steps the badge draws above the base, since
    /// scaling it down thins its strokes (ui-designer, #3284).
    public static let badgeWeightSteps = 2

    /// Go to last screen: the screen, turned back.
    public static let lastScreen = ComposedSymbol(
        name: "kiwi.screen.last",
        base: "display",
        badge: "arrow.uturn.backward",
        corner: .bottomTrailing,
        overhang: CGVector(dx: 0.3, dy: 0.3)
    )

    /// Sticky on this screen: the sticky pin, a screen beside its
    /// head (owner, option A of the 2026-11-13 renders).
    public static let displaySticky = ComposedSymbol(
        name: "kiwi.sticky.screen",
        base: "pin.fill",
        badge: "display",
        corner: .topTrailing,
        overhang: CGVector(dx: 0.55, dy: 0)
    )

    /// The Desktop overview: the Desktops, as a grid.
    public static let desktopOverview = ComposedSymbol(
        name: "kiwi.desktops.overview",
        base: "rectangle.stack",
        badge: "square.grid.2x2",
        corner: .bottomTrailing,
        overhang: CGVector(dx: 0.3, dy: 0.3)
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
        corner: Corner,
        overhang: CGVector
    ) {
        self.name = name
        self.base = base
        self.badge = badge
        self.corner = corner
        self.overhang = overhang
    }
}

extension ComposedSymbol {
    /// Where the parts sit, in the base's own coordinates (the base
    /// is `0, 0, size`), so a rect may reach past the base.
    public struct Layout: Equatable, Sendable {
        /// The square the badge fits into, flush in its corner.
        public let badge: CGRect
        /// The base's cleared area: the square grown by the gap and
        /// carried past the base in its corner's directions, so no
        /// part of the base is cut off from the rest.
        public let knockout: CGRect
        /// The knockout's corner radius; only its inner corner lies
        /// on the base.
        public let radius: CGFloat
        /// The base and the badge together: the composed image.
        public let canvas: CGRect
    }

    /// The one geometry both composers draw (`SymbolImage`, the GUI's
    /// `ComposedSymbolView`); `flipped` for y running down.
    public func layout(in size: CGSize, flipped: Bool) -> Layout {
        let side = max(size.width, size.height) * Self.badgeShare
        let gap = side * Self.gapShare
        let reach = CGVector(
            dx: side * overhang.dx,
            dy: side * overhang.dy
        )
        // y-up: the bottom corner reaches below 0.
        let low = corner == .bottomTrailing
        let y = low ? -reach.dy : size.height + reach.dy - side
        let badge = CGRect(
            x: size.width + reach.dx - side,
            y: y,
            width: side,
            height: side
        )
        let top = max(badge.maxY, size.height) + gap
        let bottom = min(badge.minY, 0) - gap
        let knockout = CGRect(
            x: badge.minX - gap,
            y: low ? bottom : badge.minY - gap,
            width: max(badge.maxX, size.width) + 2 * gap - badge.minX,
            height: (low ? badge.maxY + gap : top)
                - (low ? bottom : badge.minY - gap)
        )
        let canvas = CGRect(origin: .zero, size: size).union(badge)
        guard flipped else {
            return Layout(
                badge: badge,
                knockout: knockout,
                radius: gap,
                canvas: canvas
            )
        }
        func flip(_ rect: CGRect) -> CGRect {
            CGRect(
                x: rect.minX,
                y: size.height - rect.maxY,
                width: rect.width,
                height: rect.height
            )
        }
        return Layout(
            badge: flip(badge),
            knockout: flip(knockout),
            radius: gap,
            canvas: flip(canvas)
        )
    }
}
