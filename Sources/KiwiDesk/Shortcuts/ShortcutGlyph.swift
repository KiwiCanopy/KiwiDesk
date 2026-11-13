import KiwiDeskCore
import SwiftUI

/// A shortcut row's or a layer chip's glyph: an SF Symbol by name,
/// or an emoji the user picked (#3267 ▸ Ruling 1). Every surface
/// draws it through `ShortcutGlyphView`, never by branching itself.
enum ShortcutGlyph: Hashable, Sendable {
    case symbol(String)
    case emoji(String)

    /// A user-set icon — a Space's or a layer's — classified once
    /// by `KiwiCore.iconIsSymbol`; nil where none is set.
    @MainActor init?(icon: String?) {
        guard let icon, !icon.isEmpty else { return nil }
        self = KiwiCore.iconIsSymbol(icon) ? .symbol(icon) : .emoji(icon)
    }

    /// The symbol's name; nil for an emoji.
    var symbolName: String? {
        guard case .symbol(let name) = self else { return nil }
        return name
    }
}

/// Draws a `ShortcutGlyph` in a fixed `side`-point square: a symbol
/// in the ambient font and ink, an emoji in full colour, sized to
/// sit as tall as the symbol beside it (#3267 ▸ Ruling 2, 3). The
/// glyph is decorative; the row's or chip's name names it (Ruling 5).
struct ShortcutGlyphView: View {
    let glyph: ShortcutGlyph
    var side: CGFloat = Self.rowSide

    /// The row glyph's square, Settings and the panel alike.
    static let rowSide: CGFloat = 16

    /// An emoji's point size in a `side` square. Apple Color Emoji
    /// advances about 1.45× its point size, so 0.69 keeps the widest
    /// inside the square at the ink height of a body-size symbol
    /// (`ShortcutGlyphRenderTests`).
    static func emojiSize(side: CGFloat) -> CGFloat {
        (side * 0.69).rounded(.down)
    }

    var body: some View {
        Group {
            switch glyph {
            case .symbol(let name):
                Image(systemName: name)
            case .emoji(let emoji):
                Text(verbatim: emoji)
                    .font(.system(size: Self.emojiSize(side: side)))
                    .fixedSize()
            }
        }
        .frame(width: side, height: side)
        .accessibilityHidden(true)
    }
}
