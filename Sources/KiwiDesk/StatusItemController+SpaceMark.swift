import AppKit
import KiwiDeskCore

/// The active Space in the menu bar while the Space Bar is off
/// (#1413), composed the way the bar composes: `<layer> |
/// <space>`, one Space per screen in desk reading order. ONE
/// image, so the #1013 mark composites on it like on the brand
/// icon: a template unless an emoji is in it — an emoji keeps
/// its colour at the cost the mark already pays (no highlight
/// inversion while the menu is open).
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

    /// The button's name and tooltip: the layer, then each
    /// screen's Space in the drawn order.
    static func spaceMarkName(_ mark: StatusSpaceMark) -> String {
        let spaces = LocalizedList.join(
            screens(of: mark).map(\.space.raw)
        )
        let several = mark.screens.count > 1
        if let layer = mark.layer {
            return several
                ? L(
                    "menu.status.layer_spaces.a11y",
                    "KiwiDesk (%1$@ layer, Spaces %2$@)",
                    layer.name,
                    spaces
                )
                : L(
                    "menu.status.layer_space.a11y",
                    "KiwiDesk (%1$@ layer, Space %2$@)",
                    layer.name,
                    spaces
                )
        }
        return several
            ? L("menu.status.spaces.a11y", "KiwiDesk (Spaces %1$@)", spaces)
            : L("menu.status.space.a11y", "KiwiDesk (Space %1$@)", spaces)
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
    static func spaceMarkGlyphs(_ mark: StatusSpaceMark) -> [SpaceMark] {
        [mark.layer?.glyph].compactMap { $0 }
            + screens(of: mark).map(\.glyph)
    }

    static func spaceMarkImage(_ mark: StatusSpaceMark) -> SpaceMarkImage {
        let runs = spaceMarkGlyphs(mark).map(Run.init)
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
        image.isTemplate = !spaceMarkGlyphs(mark).contains(where: \.isEmoji)
        return image
    }

    /// One glyph measured for the composite: a symbol at the
    /// menu bar's weight, text in the menu bar's font.
    private struct Run {
        let image: NSImage?
        let text: NSAttributedString?
        let size: CGSize

        init(_ glyph: SpaceMark) {
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
            case .text(let string):
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
            if let image {
                NSColor.labelColor.set()
                image.draw(
                    in: CGRect(
                        x: x,
                        y: (StatusItemController.height - size.height) / 2,
                        width: size.width,
                        height: size.height
                    )
                )
            }
            text?.draw(
                at: CGPoint(
                    x: x,
                    y: (StatusItemController.height - size.height) / 2
                )
            )
        }
    }
}
