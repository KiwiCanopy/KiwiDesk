import AppKit

/// The hovered Space mark's name (#761, owner 2026-10-19): while
/// the pointer grows the mark, the current Space's dot widens into
/// a pill carrying the Space's identifier — its icon, number or
/// monogram, as the Space Bar draws it (`spaceIdentifier`), never
/// its layout symbol. At rest no dot carries it: an 8 pt mark
/// holds no legible glyph.
extension ShelfIndicatorSpec {
    struct Label: Equatable {
        let glyph: SpaceGlyph
        let font: NSFont
        /// The glyph's width along the edge (pt).
        let width: CGFloat
    }

    struct Position: Equatable {
        /// From 1.
        let index: Int
        let count: Int
    }

    /// The hovered pill's depth across the edge: inside the
    /// hovered plate (`depth` + 2 × `hoverGrowth`) with a point
    /// each side.
    static let labelDepth: CGFloat = depth + 2 * hoverGrowth - 4
    /// Room either side of the label inside its pill.
    static let labelPad: CGFloat = 3

    /// How much longer the hovered pill is than the current dot,
    /// which the panel keeps room for so a hover never resizes it.
    var labelExtra: CGFloat {
        guard let label else { return 0 }
        return max(0, label.width + 2 * Self.labelPad - Self.currentDot)
    }

    /// `glyph` measured in `font`: a symbol at the font's size,
    /// text by its advance.
    @MainActor static func label(_ glyph: SpaceGlyph, font: NSFont) -> Label {
        let width: CGFloat
        switch glyph {
        case .symbol(let name):
            width = symbol(name, font: font)?.size.width ?? 0
        case .text(let text, _):
            width =
                (text as NSString).size(
                    withAttributes: [.font: font]
                ).width
        }
        return Label(glyph: glyph, font: font, width: ceil(width))
    }

    /// The SF Symbol `name` at `font`'s size.
    static func symbol(_ name: String, font: NSFont) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(
                .init(pointSize: font.pointSize, weight: .semibold)
            )
    }
}
