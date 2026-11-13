import AppKit

/// A symbol slot's AppKit image: a `ComposedSymbol` drawn from its
/// two symbols, else the SF Symbol of that name (#3284). Every AppKit
/// site that may be handed a composed name — a window mark, a bar
/// badge, a menu item — reads its image here.
public enum SymbolImage {
    /// `name`'s image, configured by `configuration` where given; a
    /// composed image keeps its base's template flag.
    public static func named(
        _ name: String,
        configuration: NSImage.SymbolConfiguration? = nil,
        accessibilityDescription: String? = nil
    ) -> NSImage? {
        guard let composed = ComposedSymbol(name: name) else {
            let image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: accessibilityDescription
            )
            guard let configuration else { return image }
            return image?.withSymbolConfiguration(configuration)
        }
        let image = compose(composed, configuration: configuration)
        image?.accessibilityDescription = accessibilityDescription
        return image
    }

    /// The base at its configured size, the badge in its corner, the
    /// base cleared under a circle around the badge.
    private static func compose(
        _ symbol: ComposedSymbol,
        configuration: NSImage.SymbolConfiguration?
    ) -> NSImage? {
        guard let base = named(symbol.base, configuration: configuration),
            let badge = named(symbol.badge, configuration: configuration)
        else { return nil }
        let size = base.size
        let rect = badgeRect(symbol.corner, badge: badge.size, in: size)
        let halo = max(rect.width, rect.height) * ComposedSymbol.haloShare
        let image = NSImage(size: size, flipped: false) { _ in
            base.draw(in: NSRect(origin: .zero, size: size))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(
                ovalIn: NSRect(
                    x: rect.midX - halo / 2,
                    y: rect.midY - halo / 2,
                    width: halo,
                    height: halo
                )
            ).fill()
            NSGraphicsContext.restoreGraphicsState()
            badge.draw(in: rect)
            return true
        }
        image.isTemplate = base.isTemplate
        return image
    }

    /// The badge scaled to `badgeShare` of the base, in its corner.
    static func badgeRect(
        _ corner: ComposedSymbol.Corner,
        badge: NSSize,
        in size: NSSize
    ) -> NSRect {
        let side = max(size.width, size.height) * ComposedSymbol.badgeShare
        let scale = side / max(badge.width, badge.height, 1)
        let drawn = NSSize(
            width: badge.width * scale,
            height: badge.height * scale
        )
        let y = corner == .bottomTrailing ? 0 : size.height - drawn.height
        return NSRect(
            origin: NSPoint(x: size.width - drawn.width, y: y),
            size: drawn
        )
    }
}
