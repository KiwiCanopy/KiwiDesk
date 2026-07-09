import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Guards the hazard flagged when `NavCommand` gained a
/// localized `resolvedLabel`: `KeybindingImportClassifier`
/// matches recovered `.custom` rows on `lua` (never on display
/// text), and the `label` it writes back is the stable English
/// canonical string — both must hold no matter which GUI
/// language is active when classification runs. `.serialized`
/// mirrors `LocalizationManagerTests` (`LocalizationManager` is
/// a process-wide singleton).
@Suite("Import classifier is language-independent", .serialized)
@MainActor
struct ImportClassifierLanguageTests {
    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    private func customRow(_ lua: String) -> KeyBinding {
        KeyBinding(combo: "alt+h", lua: lua, kind: .custom)
    }

    @Test("classifies a navigation row the same under German")
    func classifiesNavigationUnderGerman() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.modes = [
            KeyMode(
                name: KeyMode.defaultName,
                bindings: [
                    customRow("KiwiDesk.focus(\"left\")")
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.modes[0].bindings[0]
        #expect(row.kind == .navigation)
        // The persisted label is the stable English canonical
        // text, matching `NavCommand.label` — never the
        // localized `resolvedLabel`, even while German is
        // active.
        #expect(row.label == "Focus window to the left")
    }

    @Test("classifies the same row identically in English and German")
    func classificationIsLanguageIndependent() {
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.modes = [
            KeyMode(
                name: KeyMode.defaultName,
                bindings: [
                    customRow(
                        "KiwiDesk.focus_space(\"1\")"
                    )
                ]
            )
        ]

        reset()
        var english = config
        KeybindingImportClassifier.classify(&english)

        LocalizationManager.shared.select("de")
        var german = config
        KeybindingImportClassifier.classify(&german)
        reset()

        #expect(
            english.modes[0].bindings[0].kind
                == german.modes[0].bindings[0].kind
        )
        #expect(
            english.modes[0].bindings[0].label
                == german.modes[0].bindings[0].label
        )
        #expect(english.modes[0].bindings[0].kind == .navigation)
    }

    @Test("classifies a switch-mode row under German")
    func classifiesSwitchModeUnderGerman() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        var config = GuiConfig()
        config.modes = [
            KeyMode(name: KeyMode.defaultName),
            KeyMode(
                name: "Deep Work",
                bindings: [
                    customRow(
                        "KiwiDesk.switch_mode(\"default\")"
                    )
                ]
            ),
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.modes[1].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Switch to default")
    }
}
