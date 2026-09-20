import Testing

@testable import KiwiDeskCore

/// `KiwiCore.iconIsSymbol` is the one reading of "does this icon
/// name an SF Symbol" — the bar's own `iconGlyph` ladder takes its
/// symbol arm from it, and the Bars preview asks the same
/// predicate (#1538), so the two cannot disagree on an icon.
@Suite("Space icon symbol reading")
@MainActor
struct SpaceIconSymbolTests {
    @Test("iconGlyph's symbol arm is iconIsSymbol's verdict")
    func glyphLadderTakesThePredicate() {
        for icon in ["book", "headphones", "star.fill", "⭐", "AB", ""] {
            let isSymbol = KiwiCore.iconIsSymbol(icon)
            let glyph = KiwiCore.iconGlyph(icon)
            #expect(
                (glyph == .symbol(icon)) == isSymbol,
                Comment(rawValue: icon)
            )
        }
        #expect(KiwiCore.iconIsSymbol("book"))
        #expect(!KiwiCore.iconIsSymbol("⭐"))
    }
}
