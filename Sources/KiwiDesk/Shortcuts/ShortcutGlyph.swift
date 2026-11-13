import KiwiDeskCore
import SwiftUI

/// A shortcut row's or a layer chip's glyph: an SF Symbol by name,
/// or an emoji the user picked (#3267 ▸ Ruling 1). Every surface
/// draws it through `ShortcutGlyphView`, never by branching itself
/// (`ShortcutGlyphDoorTests`).
enum ShortcutGlyph: Hashable, Sendable {
    case symbol(String)
    case emoji(String)

    /// A user-set icon — a Space's or a layer's — classified once
    /// by `KiwiCore.iconIsSymbol`; nil where none is set.
    @MainActor init?(icon: String?) {
        guard let icon, !icon.isEmpty else { return nil }
        self = KiwiCore.iconIsSymbol(icon) ? .symbol(icon) : .emoji(icon)
    }
}

/// Draws a `ShortcutGlyph` in a fixed `side`-point square: a symbol
/// in the ambient font and ink, an emoji in full colour at the size
/// whose widest fills the square (#3267 ▸ Ruling 2, 3). The glyph
/// is decorative; the row's or chip's name names it (Ruling 5).
struct ShortcutGlyphView: View {
    let glyph: ShortcutGlyph
    var side: CGFloat = Self.rowSide

    /// The row glyph's square, Settings and the panel alike.
    static let rowSide: CGFloat = 16

    /// An emoji's point size in a `side` square. Apple Color Emoji
    /// advances about 1.45× its point size, so 0.69 keeps the widest
    /// inside the square (`ShortcutGlyphRenderTests`).
    static func emojiSize(side: CGFloat) -> CGFloat {
        (side * 0.69).rounded(.down)
    }

    var body: some View {
        mark
            .frame(width: side, height: side)
            .accessibilityHidden(true)
    }

    /// The glyph unframed, at its own drawn size.
    @ViewBuilder var mark: some View {
        switch glyph {
        case .symbol(let name):
            Image(systemName: name)
        case .emoji(let emoji):
            Text(verbatim: emoji)
                .font(.system(size: Self.emojiSize(side: side)))
                .fixedSize()
        }
    }
}

extension KeyLayer {
    /// Each layer's icon by name — what its chip and its switch rows
    /// draw (#3267). `default` and a layer with none are left out; a
    /// repeated name takes the last, as Core's registry does.
    static func icons(of layers: [KeyLayer]) -> [String: String] {
        var icons: [String: String] = [:]
        for layer in layers where !layer.isDefault {
            icons[layer.name] = layer.icon.flatMap { $0.isEmpty ? nil : $0 }
        }
        return icons
    }
}
