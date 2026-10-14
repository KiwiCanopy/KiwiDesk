import Testing

@testable import KiwiDeskCore

/// `hyper` as a combo modifier (#1870): parsed, written back and
/// drawn as ✦ ahead of the macOS modifiers.
@Suite("Hyper combo")
struct HyperComboTests {
    @Test("hyper parses and round-trips")
    func roundTrips() throws {
        let combo = try #require(KeyCombo.parse("hyper+shift+h"))
        #expect(combo.modifiers == [.hyper, .shift])
        #expect(combo.comboString() == "hyper+shift+h")
        #expect(KeyCombo.parse("hyper+h") != KeyCombo.parse("h"))
    }

    @Test("✦ leads the modifier glyphs")
    func glyphLeads() {
        #expect(ComboSymbols.modifierSymbols([.hyper]) == "✦")
        #expect(
            ComboSymbols.modifierSymbols([.shift, .hyper]) == "✦⇧"
        )
    }
}
