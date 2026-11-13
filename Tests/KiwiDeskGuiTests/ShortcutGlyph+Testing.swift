@testable import KiwiDesk

extension ShortcutGlyph {
    /// The symbol's name; nil for an emoji. Test-only: a surface
    /// draws a glyph through `ShortcutGlyphView`, never by reading
    /// its kind (#3267, `ShortcutGlyphDoorTests`).
    var symbolName: String? {
        guard case .symbol(let name) = self else { return nil }
        return name
    }
}
