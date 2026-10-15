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

    @Test("Hyper combines with every modifier")
    func combinesWithAll() throws {
        let combo = try #require(KeyCombo.parse("hyper+cmd+ctrl+x"))
        #expect(combo.modifiers == [.hyper, .command, .control])
        #expect(combo.comboString() == "hyper+control+command+x")
        #expect(ComboSymbols.modifierSymbols(combo.modifiers) == "✦⌃⌘")
        #expect(combo.registered == KeyCombo.parse("cmd+ctrl+x"))
    }

    @Test("✦ leads the modifier glyphs")
    func glyphLeads() {
        #expect(ComboSymbols.modifierSymbols([.hyper]) == "✦")
        #expect(
            ComboSymbols.modifierSymbols([.shift, .hyper]) == "✦⇧"
        )
    }
}

/// A held Hyper row IS its bare chord, so the conflict check
/// compares what is registered (#1870).
@Suite("Hyper conflicts")
struct HyperConflictTests {
    @Test("a Hyper row meets the bare row it registers as")
    func heldChordCollides() {
        let hyper = KeyBinding(combo: "hyper+shift+x", lua: "a")
        let plain = KeyBinding(combo: "shift+x", lua: "b")
        let hit = KeybindingConflicts.conflict(
            for: hyper,
            in: [hyper, plain]
        )
        #expect(hit?.target == .otherBinding(plain))
    }

    @Test("a Hyper row meets the system chord it registers as")
    func heldChordMeetsSystem() {
        let spotlight = KeyBinding(combo: "hyper+cmd+space", lua: "a")
        #expect(
            KeybindingConflicts.conflict(
                for: spotlight,
                in: [spotlight]
            )?.target == .systemShortcut(.spotlight)
        )
    }

    @Test("a free Hyper row conflicts with nothing")
    func freeRowIsClean() {
        let free = KeyBinding(combo: "hyper+h", lua: "a")
        #expect(
            KeybindingConflicts.conflict(for: free, in: [free]) == nil
        )
    }
}
