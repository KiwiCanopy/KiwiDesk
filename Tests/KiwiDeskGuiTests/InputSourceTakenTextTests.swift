import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The takes-away caption of a row on macOS's next-input-source
/// shortcut (#3319 ▸ Ruling amendment): the plain meaning, the
/// place it is changed, and the other input-source chord while it
/// still switches. Pure apart from the locale pin.
@MainActor
struct InputSourceTakenTextTests {
    private let ctrlSpace = KeyCombo.parse("ctrl+space")!
    private let ctrlShiftSpace = KeyCombo.parse("ctrl+shift+space")!

    private func drawn(_ combo: KeyCombo) -> String {
        ChordGlyphs.render(combo, layoutChar: LayoutKeyGlyph.char)
    }

    private func sentence(
        _ severity: ConflictSeverity,
        other: KeyCombo?,
        config: GuiConfig = GuiConfig()
    ) -> String {
        ConflictText.sentence(
            for: severity,
            config: config,
            system: SystemShortcutState(
                disabled: [],
                previousInputSource: other
            )
        )
    }

    @Test("a winning row names the meaning, the place, and the chord")
    func winsNamesThePlace() {
        LocalizationManager.shared.select("en")
        let text = sentence(.winsFromMacOS(.inputSourceNext), other: nil)
        let chord = drawn(KeyCombo.parse("ctrl+alt+space")!)
        #expect(
            text
                == "Takes \(chord) away from macOS's shortcut for "
                + "switching to the next keyboard language (Keyboard ▸ "
                + "Keyboard Shortcuts ▸ Input Sources) while it is "
                + "bound here."
        )
    }

    @Test("the other switch is named while it is live and free")
    func otherSwitchIsNamed() {
        LocalizationManager.shared.select("en")
        let text = sentence(
            .winsFromMacOS(.inputSourceNext),
            other: ctrlShiftSpace
        )
        #expect(text.hasSuffix(" \(drawn(ctrlShiftSpace)) still switches."))
        let step = sentence(
            .takesFromMacOS(.inputSourceNext),
            other: ctrlSpace
        )
        #expect(step.contains("while this sequence is open."))
        #expect(step.hasSuffix(" \(drawn(ctrlSpace)) still switches."))
    }

    @Test("a KiwiDesk row on the other chord leaves the clause out")
    func boundOtherIsLeftOut() {
        LocalizationManager.shared.select("en")
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [KeyBinding(combo: "control+space", lua: "a")]
            )
        ]
        let text = sentence(
            .winsFromMacOS(.inputSourceNext),
            other: ctrlSpace,
            config: config
        )
        #expect(!text.contains("still switches"))
        #expect(text.contains("Input Sources"))
    }

    @Test("another shortcut keeps its own caption")
    func otherShortcutsUnchanged() {
        LocalizationManager.shared.select("en")
        let text = sentence(.takesFromMacOS(.spotlight), other: ctrlSpace)
        #expect(!text.contains("still switches"))
        #expect(!text.contains("Input Sources"))
    }

    @Test("the live state reads hotkey 60 as macOS answers it")
    func liveReadsTheOtherHotkey() {
        let id = SymbolicHotkeys.previousInputSource.id
        let absent = SystemShortcutState.live { _ in nil }
        #expect(absent.previousInputSource == ctrlSpace)
        let off = SystemShortcutState.live {
            $0 == id ? SymbolicHotkeyEntry(enabled: false) : nil
        }
        #expect(off.previousInputSource == nil)
        let moved = SystemShortcutState.live {
            $0 == id
                ? SymbolicHotkeyEntry(enabled: true, combo: ctrlShiftSpace)
                : nil
        }
        #expect(moved.previousInputSource == ctrlShiftSpace)
        let invert = SystemShortcut.invertColors.symbolicHotkey!.id
        let disabled = SystemShortcutState.live {
            $0 == invert ? SymbolicHotkeyEntry(enabled: false) : nil
        }
        #expect(disabled.disabled.contains(.invertColors))
    }

    @Test("a row's reading carries the section's state to the caption")
    func readingThreadsTheState() throws {
        LocalizationManager.shared.select("en")
        let row = KeyBinding(combo: "ctrl+alt+space", lua: "a")
        let reading = try #require(
            ConflictText.reading(
                for: row,
                in: [row],
                config: GuiConfig(),
                system: SystemShortcutState(
                    disabled: [],
                    previousInputSource: ctrlSpace
                ),
                sides: false
            )
        )
        #expect(reading.severity == .winsFromMacOS(.inputSourceNext))
        #expect(reading.sentence.hasSuffix("still switches."))
    }
}
