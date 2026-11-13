import AppKit

/// A symbol slot's AppKit image: a `ComposedSymbol` drawn from its
/// two symbols, else the SF Symbol of that name (#3284). An AppKit
/// site handed a symbol name it did not spell reads its image here
/// (`SymbolNameDoorTests`). The GUI's own `kiwi.*` `CustomGlyph`s are
/// SwiftUI art and are not drawn here.
public enum SymbolImage {
    /// How a symbol is drawn: an `NSImage.SymbolConfiguration` whose
    /// weight a composed badge can raise, which a configuration
    /// cannot report.
    public struct Style: Sendable {
        public var pointSize: CGFloat
        public var weight: NSFont.Weight
        /// One palette colour, or nil for a template symbol.
        public var palette: NSColor?

        public init(
            pointSize: CGFloat = NSFont.systemFontSize,
            weight: NSFont.Weight = .regular,
            palette: NSColor? = nil
        ) {
            self.pointSize = pointSize
            self.weight = weight
            self.palette = palette
        }

        public var configuration: NSImage.SymbolConfiguration {
            let sized = NSImage.SymbolConfiguration(
                pointSize: pointSize,
                weight: weight
            )
            guard let palette else { return sized }
            return sized.applying(.init(paletteColors: [palette]))
        }

        /// The badge's style: `ComposedSymbol.badgeWeightSteps`
        /// heavier, since scaling the badge thins its strokes.
        var badge: Style {
            var style = self
            let ladder: [NSFont.Weight] = [
                .ultraLight, .thin, .light, .regular, .medium,
                .semibold, .bold, .heavy, .black,
            ]
            let at = ladder.lastIndex { $0.rawValue <= weight.rawValue } ?? 3
            let raised = at + ComposedSymbol.badgeWeightSteps
            style.weight = ladder[min(raised, ladder.count - 1)]
            return style
        }
    }

    /// `name`'s image, drawn in `style` where given (a plain symbol
    /// keeps its own default otherwise); a composed image keeps its
    /// base's template flag.
    public static func named(
        _ name: String,
        style: Style? = nil,
        accessibilityDescription: String? = nil
    ) -> NSImage? {
        guard let composed = ComposedSymbol(name: name) else {
            let image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: accessibilityDescription
            )
            guard let style else { return image }
            return image?.withSymbolConfiguration(style.configuration)
        }
        let image = compose(composed, style: style ?? Style())
        image?.accessibilityDescription = accessibilityDescription
        return image
    }

    /// The base, cleared in a ring around the badge, then the badge
    /// fitted flush into its square (`ComposedSymbol.layout`), on a
    /// canvas holding both.
    private static func compose(
        _ symbol: ComposedSymbol,
        style: Style
    ) -> NSImage? {
        guard let base = named(symbol.base, style: style),
            let badge = named(symbol.badge, style: style.badge)
        else { return nil }
        let size = base.size
        let layout = symbol.layout(in: size, flipped: false)
        let rect = fitted(badge.size, into: layout.badge, symbol.corner)
        let canvas = layout.canvas
        let image = NSImage(size: canvas.size, flipped: false) { _ in
            let shift = NSAffineTransform()
            shift.translateX(by: -canvas.minX, yBy: -canvas.minY)
            shift.concat()
            base.draw(in: NSRect(origin: .zero, size: size))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(
                roundedRect: layout.knockout,
                xRadius: layout.radius,
                yRadius: layout.radius
            ).fill()
            NSGraphicsContext.restoreGraphicsState()
            badge.draw(in: rect)
            return true
        }
        image.isTemplate = base.isTemplate
        return image
    }

    /// `size` scaled to fit `square`, flush in `corner`, y up.
    static func fitted(
        _ size: NSSize,
        into square: NSRect,
        _ corner: ComposedSymbol.Corner
    ) -> NSRect {
        let scale = square.width / max(size.width, size.height, 1)
        let drawn = NSSize(
            width: size.width * scale,
            height: size.height * scale
        )
        let y =
            corner == .bottomTrailing
            ? square.minY : square.maxY - drawn.height
        return NSRect(
            origin: NSPoint(x: square.maxX - drawn.width, y: y),
            size: drawn
        )
    }
}
