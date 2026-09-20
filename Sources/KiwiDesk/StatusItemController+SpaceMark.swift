import AppKit
import KiwiDeskCore

/// The active layer and, while the Space Bar is off, the Space
/// each screen shows, in the menu bar (#1413): one composite
/// image, a template unless an emoji is in it, so the #1013 mark
/// composites on it like on the brand icon — the argument is in
/// `docs/design-decisions.md` ▸ the menu bar item is the Space
/// Bar's stand-in.
extension StatusItemController {
    /// The composite's type, so a test can tell it from the brand
    /// icon without reading pixels.
    final class SpaceMarkImage: NSImage {}

    nonisolated private static let height: CGFloat = 18
    private static let gap: CGFloat = 5
    private static let dividerHeight: CGFloat = 12

    func applySpaceMark(
        _ mark: StatusSpaceMark,
        to button: NSStatusBarButton
    ) {
        let name = Self.spaceMarkName(mark)
        button.setAccessibilityLabel(name)
        button.toolTip = name
        button.image = Self.spaceMarkImage(mark)
        button.title = ""
    }

    /// The bar-on shape: the layer's icon alone, as before #1413.
    /// Naming the button is load-bearing — a label on an `NSView`
    /// PERSISTS until replaced, so every path owes a name — and
    /// the name is the app's, never the icon string's.
    func applyLayerIcon(
        _ glyph: StatusSpaceMark.Glyph,
        to button: NSStatusBarButton
    ) {
        button.setAccessibilityLabel(L("menu.status.a11y", "KiwiDesk"))
        switch glyph {
        case .symbol(let name):
            button.image = NSImage(
                systemSymbolName: name,
                accessibilityDescription: name
            )
            button.title = ""
        case .text(let text, _):
            button.image = nil
            button.title = text
        }
    }

    /// The button's name and tooltip: the layer, then each
    /// screen's Space in the drawn order.
    static func spaceMarkName(_ mark: StatusSpaceMark) -> String {
        let names = screens(of: mark).map(\.space.raw)
        let spaces = LocalizedList.join(names)
        let several = names.count > 1
        if let layer = mark.layer {
            return several
                ? L(
                    "menu.status.layer_space.many",
                    "KiwiDesk (“%1$@” layer, Spaces %2$@)",
                    layer.name,
                    spaces
                )
                : L(
                    "menu.status.layer_space.one",
                    "KiwiDesk (“%1$@” layer, Space %2$@)",
                    layer.name,
                    spaces
                )
        }
        return several
            ? L("menu.status.space.many", "KiwiDesk (Spaces %1$@)", spaces)
            : L("menu.status.space.one", "KiwiDesk (Space %1$@)", spaces)
    }

    /// The screens in desk reading order (#752).
    static func screens(
        of mark: StatusSpaceMark
    ) -> [StatusSpaceMark.Screen] {
        let ordered = DeskOrder.reading(mark.screens.map(\.display))
        return ordered.compactMap { display in
            mark.screens.first { $0.display.id == display.id }
        }
    }

    /// The glyphs in drawn order, with a divider between each.
    static func spaceMarkGlyphs(
        _ mark: StatusSpaceMark
    ) -> [StatusSpaceMark.Glyph] {
        [mark.layer?.glyph].compactMap { $0 }
            + screens(of: mark).map(\.glyph)
    }

    static func spaceMarkImage(
        _ mark: StatusSpaceMark
    ) -> SpaceMarkImage {
        let glyphs = spaceMarkGlyphs(mark)
        let runs = glyphs.map(Run.init)
        var width = runs.reduce(0) { $0 + $1.size.width }
        width += CGFloat(runs.count - 1) * (gap * 2 + 1)
        let size = CGSize(width: max(width, 1), height: height)
        let image = SpaceMarkImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            for (index, run) in runs.enumerated() {
                if index > 0 {
                    NSColor.labelColor.withAlphaComponent(0.35).setFill()
                    CGRect(
                        x: x + gap,
                        y: (height - dividerHeight) / 2,
                        width: 1,
                        height: dividerHeight
                    ).fill()
                    x += gap * 2 + 1
                }
                run.draw(atX: x)
                x += run.size.width
            }
            return true
        }
        image.isTemplate = !glyphs.contains(where: \.keepsColour)
        return image
    }

    /// One glyph measured for the composite: a symbol at the
    /// menu bar's weight, text in the menu bar's font.
    private struct Run {
        let image: NSImage?
        let text: NSAttributedString?
        let size: CGSize

        init(_ glyph: StatusSpaceMark.Glyph) {
            switch glyph {
            case .symbol(let name):
                let symbol = NSImage(
                    systemSymbolName: name,
                    accessibilityDescription: nil
                )?.withSymbolConfiguration(
                    .init(pointSize: 14, weight: .medium)
                )
                image = symbol
                text = nil
                size = symbol?.size ?? .zero
            case .text(let string, _):
                let attributed = NSAttributedString(
                    string: string,
                    attributes: [
                        .font: NSFont.menuBarFont(ofSize: 0),
                        .foregroundColor: NSColor.labelColor,
                    ]
                )
                image = nil
                text = attributed
                size = attributed.size()
            }
        }

        func draw(atX x: CGFloat) {
            let origin = CGPoint(
                x: x,
                y: (StatusItemController.height - size.height) / 2
            )
            if let image {
                // A symbol draws in its own black whatever is
                // set; the label tint lands on it as `badged`
                // does — a fill through its alpha.
                let rect = CGRect(origin: origin, size: size)
                image.draw(in: rect)
                NSColor.labelColor.set()
                rect.fill(using: .sourceAtop)
            }
            text?.draw(at: origin)
        }
    }
}
