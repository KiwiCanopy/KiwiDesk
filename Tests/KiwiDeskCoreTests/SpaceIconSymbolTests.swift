import Testing

@testable import KiwiDeskCore

/// `KiwiCore.iconIsSymbol` is the one reading of "does this icon
/// name an SF Symbol"; the bar's `iconGlyph` ladder takes its
/// symbol arm from it and the Bars preview asks the same predicate
/// (#1538). `SymbolClassifierSeamTests` holds that no copy exists.
///
/// `@MainActor` because `KiwiCore` is, and that is all this suite
/// spends there: six `NSImage(systemSymbolName:)` lookups.
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

    /// The instance reading that delegates here is pinned by
    /// `SpaceBarDriverTests` on a live core.
    @Test("The public ladder: icon, empty icon, digits, monogram")
    func staticLadderCoversEveryArm() {
        #expect(
            KiwiCore.spaceIdentifier(id: SpaceID("2"), icon: "book")
                == .symbol("book")
        )
        #expect(
            KiwiCore.spaceIdentifier(id: SpaceID("2"), icon: "")
                == .text("2", tinted: true)
        )
        #expect(
            KiwiCore.spaceIdentifier(id: SpaceID("2026"), icon: nil)
                == .text("202", tinted: true)
        )
        #expect(
            KiwiCore.spaceIdentifier(id: SpaceID("mail"), icon: nil)
                == .text("MA", tinted: true)
        )
    }
}
