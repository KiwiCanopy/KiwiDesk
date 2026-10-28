import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A sided chord is spoken and explained in words (#2601 ▸ Ruling
/// 1), and the keyboard board marks the caps a chip holds.
@Suite("Sided chords in words and on the board (#2601)")
@MainActor
struct SidedChordWordsTests {
    /// What `ChordGlyphs` draws for `combo`, the input every
    /// consumer hands the words.
    private func drawn(_ combo: String) throws -> String {
        ChordGlyphs.render(
            try #require(KeyCombo.parse(combo)),
            layoutChar: { _ in nil }
        )
    }

    @Test("a drawn run is named key by key with the Hyper card's names")
    func spokenNamesTheSide() throws {
        LocalizationManager.shared.select("en")
        #expect(SidedChordWords.spoken(try drawn("rcmd+h")) == "Right ⌘ H")
        #expect(
            SidedChordWords.spoken(try drawn("lshift+lcmd+k"))
                == "Left ⇧ Left ⌘ K"
        )
        #expect(
            SidedChordWords.spoken(try drawn("lctrl+ralt+j"))
                == "Left ⌃ Right ⌥ J"
        )
    }

    @Test("a chord keeping no side reads as drawn")
    func unsidedIsNil() throws {
        LocalizationManager.shared.select("en")
        #expect(SidedChordWords.spoken(try drawn("cmd+l")) == nil)
        #expect(SidedChordWords.label("⌃⌥R") == "⌃⌥R")
        #expect(SidedChordWords.help(try drawn("cmd+h")).isEmpty)
    }

    @Test("a label names ✦ by the Hyper key's name")
    func hyperIsNamed() {
        LocalizationManager.shared.select("en")
        let name = HyperKeyWords.keyName
        #expect(SidedChordWords.label("✦⌘K") == name + " ⌘K")
        #expect(SidedChordWords.label("✦ ← →") == name + " ← →")
        #expect(
            SidedChordWords.label("✦ Right ⌘ K") == name + " Right ⌘ K"
        )
        #expect(SidedChordWords.label("✦") == name)
    }

    /// The point of reading the drawn words back: a short catalog
    /// word is spoken as the full key name, in every locale.
    @Test("every catalog's drawn side reads back as its key names")
    func readsTheDrawnFormEverywhere() throws {
        defer { LocalizationManager.shared.select("en") }
        let locales = LocaleCatalog.availableLocales() + ["en"]
        #expect(locales.count > 1)
        for locale in locales {
            LocalizationManager.shared.select(locale)
            for side in ModifierSide.allCases {
                let modifiers = HotkeyModifiers.control
                    .union(.option)
                    .union(.side(side, of: .control))
                    .union(.side(side, of: .option))
                let glyphs =
                    ChordGlyphs.modifiers(modifiers)
                    + ChordGlyphs.separator(modifiers) + "J"
                let names = [ModifierKind.control, .option].map {
                    HyperKeyWords.name(.key(side, of: $0))
                }
                #expect(
                    SidedChordWords.spoken(glyphs)
                        == (names + ["J"]).joined(separator: " "),
                    "\(locale): \(glyphs)"
                )
            }
        }
    }

    @Test("a chip holds its own side's cap, and either-side holds both")
    func boardHoldsTheCaps() throws {
        let sided = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(
                modifiers: try #require(KeyCombo.parse("rcmd+h")).modifiers
            )
        )
        #expect(
            KeyboardCensus.holds(.rightCommand, scope: sided, hyper: nil)
        )
        #expect(
            !KeyboardCensus.holds(.leftCommand, scope: sided, hyper: nil)
        )
        #expect(!KeyboardCensus.holds(.leftOption, scope: sided, hyper: nil))
        #expect(KeyboardCensus.heldSides(scope: sided) == [.rightCommand])
        let plain = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(modifiers: .command)
        )
        #expect(KeyboardCensus.holds(.leftCommand, scope: plain, hyper: nil))
        #expect(
            !KeyboardCensus.holds(
                .rightCommand,
                scope: plain,
                hyper: .rightCommand
            )
        )
        #expect(KeyboardCensus.heldSides(scope: plain).isEmpty)
        #expect(!KeyboardCensus.holds(.leftCommand, scope: .all, hyper: nil))
    }

    @Test("a sided chip meets the either-side reservation")
    func sidedLayerSeesReservations() throws {
        let sided = KeyboardCensus.Scope.one(
            KeyboardCensus.ModifierLayer(
                modifiers: try #require(KeyCombo.parse("rcmd+space"))
                    .modifiers
            )
        )
        #expect(KeyboardCensus.reservedKeys(scope: sided).contains(49))
    }

    @Test("the board speaks the caps it holds")
    func boardSpeaksHolding() {
        LocalizationManager.shared.select("en")
        let sentence = KeyboardBoardSpoken.sentence(
            buckets: .init(),
            scopeLabel: "Right ⌘",
            layerLabel: nil,
            hyperName: nil,
            holding: ["Right ⌘"],
            conflictDetail: []
        )
        #expect(sentence.contains("Holding Right ⌘."))
    }

    @Test("every drawn sided chord is wired to its words")
    func surfacesSpeakTheSide() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        func read(_ path: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(path),
                    encoding: .utf8
                )
            )
        }
        let keys = "Settings/Components/Keybindings/"
        #expect(
            try read("Shortcuts/ShortcutsBands.swift").contains(
                ".accessibilityLabel(SidedChordWords.label(row.combo))"
            )
        )
        #expect(
            try read(keys + "KeyboardChrome.swift").contains(
                ".accessibilityLabel(SidedChordWords.label(label))"
            )
        )
        #expect(
            try read(keys + "Recorder/KeyRecorderField.swift").contains(
                ".accessibilityValue(SidedChordWords.label(label))"
            )
        )
        #expect(
            try read("Jump/LayoutPickText.swift").contains(
                "SidedChordWords.label(chord)"
            )
        )
        #expect(
            try read("Onboarding/OnboardingKeyFamily.swift").contains(
                "SidedChordWords.label(glyphs)"
            )
        )
        #expect(
            try read("Onboarding/OnboardingKeys+KiwiHub.swift")
                .filter { !$0.isWhitespace }
                .contains("rendered(combo:combo).map(SidedChordWords.label)")
        )
        #expect(
            try read(keys + "KeyboardPreviewPanel+Slot.swift").contains(
                "read($0).lines.map(SidedChordWords.label)"
            )
        )
        #expect(
            try read("Shortcuts/ShortcutsBands.swift").contains(
                ".help(SidedChordWords.help(row.combo))"
            )
        )
        #expect(
            try read(keys + "KeyboardChrome.swift").contains(
                ".help(SidedChordWords.help(label))"
            )
        )
        let board = try read(keys + "KeyboardBoardSpoken.swift")
        #expect(board.contains("KeyboardCensus.heldSides(scope: scope)"))
        #expect(
            board.contains(
                "return SidedChordWords.label(\n"
                    + "                KeyboardKeyLabel.chipLabel(for: layer)"
            )
        )
        let caps = try read(keys + "KeyboardBoard.swift")
        #expect(caps.contains("held: KeyboardCensus.holds("))
    }
}
