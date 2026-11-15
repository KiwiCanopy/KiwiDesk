import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The takes-away caption of a row on macOS's previous-input-source
/// shortcut, ⌃Space (#3331), the mirror of #3319's: the plain
/// meaning, the place it is changed, and the next-source chord while
/// it still switches. Pure apart from the locale pin.
@MainActor
struct InputSourcePreviousTextTests {
    private let ctrlSpace = KeyCombo.parse("ctrl+space")!
    private let ctrlOptSpace = KeyCombo.parse("ctrl+alt+space")!
    private let moved = KeyCombo.parse("ctrl+alt+shift+space")!

    private func drawn(_ combo: KeyCombo) -> String {
        ChordGlyphs.render(combo, layoutChar: LayoutKeyGlyph.char)
    }

    private func layer(_ rows: [KeyBinding]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = [KeyLayer(name: KeyLayer.defaultName, bindings: rows)]
        return config
    }

    private func sentence(
        _ severity: ConflictSeverity,
        next: KeyCombo?,
        previous: KeyCombo? = nil,
        config: GuiConfig = GuiConfig()
    ) -> String {
        var chords: [SystemShortcut: KeyCombo] = [:]
        chords[.inputSourceNext] = next
        chords[.inputSourcePrevious] = previous
        return ConflictText.sentence(
            for: severity,
            config: config,
            system: SystemShortcutState(disabled: [], inputSources: chords)
        )
    }

    @Test("a winning row names the meaning, the place, and ⌃Space")
    func winsNamesThePlace() {
        LocalizationManager.shared.select("en")
        let text = sentence(.winsFromMacOS(.inputSourcePrevious), next: nil)
        #expect(
            text
                == "Takes \(drawn(ctrlSpace)) away from macOS's shortcut "
                + "for switching to the previous keyboard language "
                + "(Keyboard ▸ Keyboard Shortcuts ▸ Input Sources) while "
                + "it is bound here."
        )
        let step = sentence(.takesFromMacOS(.inputSourcePrevious), next: nil)
        #expect(step.hasSuffix("while this sequence is open."))
        #expect(step.contains("previous keyboard language"))
    }

    @Test("hotkey 61's live chord is named while it is free")
    func nextSwitchIsNamed() {
        LocalizationManager.shared.select("en")
        let wins = sentence(
            .winsFromMacOS(.inputSourcePrevious),
            next: ctrlOptSpace,
            previous: ctrlSpace
        )
        #expect(wins.hasSuffix(" \(drawn(ctrlOptSpace)) still switches."))
        #expect(wins.contains("while it is bound here."))
        let step = sentence(
            .takesFromMacOS(.inputSourcePrevious),
            next: moved
        )
        #expect(step.contains("while this sequence is open."))
        #expect(step.hasSuffix(" \(drawn(moved)) still switches."))
    }

    @Test("a row on ⌃Space never names ⌃Space as still switching")
    func ownChordIsNeverTheOther() {
        LocalizationManager.shared.select("en")
        let text = sentence(
            .winsFromMacOS(.inputSourcePrevious),
            next: nil,
            previous: ctrlSpace
        )
        #expect(!text.contains("still switches"))
    }

    @Test("a KiwiDesk row on 61's chord leaves the clause out")
    func boundNextIsLeftOut() {
        LocalizationManager.shared.select("en")
        for row in [
            KeyBinding(combo: "control+option+space", lua: "a"),
            KeyBinding(combo: "control+option+space", kind: .sequence),
        ] {
            let text = sentence(
                .winsFromMacOS(.inputSourcePrevious),
                next: ctrlOptSpace,
                config: layer([row])
            )
            #expect(!text.contains("still switches"))
            #expect(text.contains("previous keyboard language"))
        }
    }

    @Test("the live state reads hotkey 61 as macOS answers it")
    func liveReadsHotkey61() {
        let id = SystemShortcut.inputSourceNext.symbolicHotkey!.id
        #expect(id == 61)
        let absent = SystemShortcutState.live { _ in nil }
        #expect(absent.inputSources[.inputSourceNext] == ctrlOptSpace)
        let off = SystemShortcutState.live {
            $0 == id ? SymbolicHotkeyEntry(enabled: false) : nil
        }
        #expect(off.inputSources[.inputSourceNext] == nil)
        #expect(off.inputSources[.inputSourcePrevious] == ctrlSpace)
        let relocated = SystemShortcutState.live {
            $0 == id ? SymbolicHotkeyEntry(enabled: true, combo: moved) : nil
        }
        #expect(relocated.inputSources[.inputSourceNext] == moved)
    }

    @Test("a ⌃Space row's reading carries the state to the caption")
    func readingThreadsTheState() throws {
        LocalizationManager.shared.select("en")
        let row = KeyBinding(combo: "control+space", kind: .sequence)
        let reading = try #require(
            ConflictText.reading(
                for: row,
                in: [row],
                config: layer([row]),
                system: .live { _ in nil },
                sides: false
            )
        )
        #expect(reading.severity == .winsFromMacOS(.inputSourcePrevious))
        #expect(
            reading.sentence.hasSuffix(
                " \(drawn(ctrlOptSpace)) still switches."
            )
        )
    }

    /// Measured by hand 2026-11-15 (#3331 amendment), macOS 27.2: a
    /// plain `KiwiDesk.bind("ctrl+space", …)` fired its action and
    /// the keyboard language did not switch.
    @Test("a Carbon row on ⌃Space takes it from macOS")
    func carbonRowWins() throws {
        let row = KeyBinding(combo: "control+space", lua: "a")
        let reading = try #require(
            ConflictText.reading(
                for: row,
                in: [row],
                config: layer([row]),
                system: .live { _ in nil },
                sides: false
            )
        )
        #expect(reading.severity == .winsFromMacOS(.inputSourcePrevious))
    }
}
