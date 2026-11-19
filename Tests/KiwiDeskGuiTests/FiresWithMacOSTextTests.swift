import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The caption of a Carbon row on ⌃Space (#3504): measured by hand
/// with a source poller 2026-11-19, the press fires the row AND
/// switches the keyboard language, so the row reads
/// neither "won't work" nor "takes … away", and says macOS's shortcut
/// must be turned off first. Pure apart from the locale pin.
@MainActor
struct FiresWithMacOSTextTests {
    private let place = "Keyboard ▸ Keyboard Shortcuts ▸ Input Sources"

    private func drawn(_ combo: String) -> String {
        ChordGlyphs.render(
            KeyCombo.parse(combo)!,
            layoutChar: LayoutKeyGlyph.char
        )
    }

    private func layer(_ rows: [KeyBinding]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = [KeyLayer(name: KeyLayer.defaultName, bindings: rows)]
        return config
    }

    /// The reading of a plain Carbon row on `combo` while macOS has
    /// both input-source shortcuts on (`.live` with no plist entry
    /// reads the shipped defaults).
    private func reading(
        _ combo: String,
        disabled: Set<SystemShortcut> = []
    ) throws -> ConflictReading {
        let row = KeyBinding(combo: combo, lua: "a")
        let live = SystemShortcutState.live { _ in nil }
        return try #require(
            ConflictText.reading(
                for: row,
                in: [row],
                config: layer([row]),
                system: SystemShortcutState(
                    disabled: disabled,
                    inputSources: live.inputSources
                ),
                sides: false
            )
        )
    }

    @Test("a Carbon ⌃Space row says both fire and where to turn it off")
    func previousSaysBoth() throws {
        LocalizationManager.shared.select("en")
        let found = try reading("control+space")
        #expect(
            found.severity
                == .firesWithMacOS(.inputSourcePrevious, macOSOn: true)
        )
        let chord = drawn("ctrl+space")
        #expect(
            found.sentence
                == "Each press of \(chord) also runs macOS's shortcut for "
                + "switching to the previous keyboard language. To use "
                + "\(chord) here alone, turn macOS's shortcut off first "
                + "(\(place))."
        )
    }

    @Test("a Carbon ⌃⌥Space row still takes the chord from macOS")
    func nextStillWins() throws {
        LocalizationManager.shared.select("en")
        let found = try reading("control+option+space")
        #expect(found.severity == .winsFromMacOS(.inputSourceNext))
        #expect(found.sentence.hasPrefix("Takes"))
    }

    @Test("a Carbon ⌃Space row never claims to win or to be dead")
    func noFalseClaim() throws {
        LocalizationManager.shared.select("en")
        for disabled: Set<SystemShortcut> in [[], [.inputSourcePrevious]] {
            let found = try reading("control+space", disabled: disabled)
            #expect(!found.severity.isDead)
            #expect(!found.sentence.hasPrefix("Takes"))
            #expect(!found.sentence.contains("Won't work"))
            #expect(!found.sentence.contains("still switches"))
        }
    }

    @Test("with macOS's shortcut off only the row fires, and it says so")
    func offSaysOnlyHere() throws {
        LocalizationManager.shared.select("en")
        let found = try reading(
            "control+space",
            disabled: [.inputSourcePrevious]
        )
        #expect(
            found.severity
                == .firesWithMacOS(.inputSourcePrevious, macOSOn: false)
        )
        #expect(
            found.sentence
                == "macOS's shortcut for switching to the previous "
                + "keyboard language is off (\(place)), so "
                + "\(drawn("ctrl+space")) only fires here. Turn it back "
                + "on and each press switches the language too."
        )
    }

    @Test("a tap row on ⌃Space still takes the chord from macOS")
    func tapRowStillWins() throws {
        LocalizationManager.shared.select("en")
        let row = KeyBinding(combo: "control+space", kind: .sequence)
        let found = try #require(
            ConflictText.reading(
                for: row,
                in: [row],
                config: layer([row]),
                system: .live { _ in nil },
                sides: false
            )
        )
        #expect(found.severity == .winsFromMacOS(.inputSourcePrevious))
        #expect(found.sentence.hasPrefix("Takes"))
    }

    @Test("the banner says the row also runs macOS's shortcut")
    func bannerSaysBoth() {
        LocalizationManager.shared.select("en")
        let model = makeTestModel()
        let row = KeyBinding(
            combo: "control+space",
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            label: "Focus window left"
        )
        model.config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [row])
        ]
        model.warnIfAnyConflict()
        let name = SystemShortcut.inputSourcePrevious.localizedName
        #expect(
            model.keybindingWarning
                == "Shortcut for \"Focus window left\" also runs "
                + "macOS's \"\(name)\" on each press."
        )
        let other = KeyBinding(combo: "command+space", lua: "b")
        model.config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [row, other])
        ]
        model.warnIfAnyConflict()
        #expect(
            model.keybindingWarning?.contains(
                "– \"Focus window left\" also runs macOS's "
                    + "\"\(name)\" on each press"
            ) == true
        )
    }

    /// The ⌃⌥Space caption's "⌃Space still switches" (#3319) asks who
    /// holds ⌃Space by the same rule: a Carbon row there leaves macOS
    /// switching, a tap row takes it.
    @Test("a Carbon ⌃Space row leaves ⌃Space still switching")
    func stillSwitchesBesideACarbonRow() {
        LocalizationManager.shared.select("en")
        let next = KeyBinding(combo: "control+option+space", lua: "a")
        let live = SystemShortcutState.live { _ in nil }
        func text(_ other: KeyBinding, sides: Bool = false) -> String {
            var state = live
            state.sides = sides
            return ConflictText.reading(
                for: next,
                in: [next, other],
                config: layer([next, other]),
                system: state,
                sides: sides
            )?.sentence ?? ""
        }
        let carbon = KeyBinding(combo: "control+space", lua: "b")
        #expect(
            text(carbon).hasSuffix(" \(drawn("ctrl+space")) still switches.")
        )
        let leader = KeyBinding(combo: "control+space", kind: .sequence)
        #expect(!text(leader).contains("still switches"))
        let sided = KeyBinding(combo: "lctrl+space", lua: "b")
        #expect(!text(sided, sides: true).contains("still switches"))
        #expect(text(sided, sides: false).hasSuffix("still switches."))
    }

    @Test("a shared chord off macOS is an info line, not a fix")
    func offIsNothingToFix() {
        #expect(
            ConflictSeverity.firesWithMacOS(
                .inputSourcePrevious,
                macOSOn: false
            ).macOSHasItOff
        )
        #expect(
            !ConflictSeverity.firesWithMacOS(
                .inputSourcePrevious,
                macOSOn: true
            ).macOSHasItOff
        )
        #expect(ConflictSeverity.dormant(.invertColors).macOSHasItOff)
        #expect(!ConflictSeverity.dead(.spotlight).macOSHasItOff)
    }

    /// No other chord answers `.both` today; the fallback still names
    /// the shortcut and its state.
    @Test("another shared chord names its shortcut")
    func genericNamesTheShortcut() {
        LocalizationManager.shared.select("en")
        let name = SystemShortcut.spotlight.localizedName
        let on = ConflictText.sentence(
            for: .firesWithMacOS(.spotlight, macOSOn: true),
            config: GuiConfig(),
            system: .unread
        )
        #expect(
            on == "Each press also runs \(name) in macOS. To use this "
                + "shortcut here alone, turn \(name) off in System "
                + "Settings first."
        )
        let off = ConflictText.sentence(
            for: .firesWithMacOS(.spotlight, macOSOn: false),
            config: GuiConfig(),
            system: .unread
        )
        #expect(off.hasPrefix("\(name) is switched off"))
        #expect(!off.contains("keyboard language"))
    }
}
