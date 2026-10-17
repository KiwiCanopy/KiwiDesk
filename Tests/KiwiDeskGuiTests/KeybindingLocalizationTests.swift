import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Pins the localization split introduced alongside the
/// keybinding catalog audit: `NavCommand.label` is the stable
/// English identity persisted into `KeyBinding.label` and
/// matched on by `KeybindingImportClassifier`; `resolvedLabel`
/// is what the GUI renders and DOES change under a language
/// switch. `.serialized` mirrors `LocalizationManagerTests`
/// (`LocalizationManager` is a process-wide singleton).
@Suite("Keybinding catalog localization", .serialized)
@MainActor
struct KeybindingLocalizationTests {
    private func reset() {
        LocalizationManager.shared.select(nil)
    }

    @Test("a focus-direction label resolves to German")
    func focusDirectionResolvesGerman() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let command = KeybindingCatalog.focusDirections[0]
        // English canonical identity never changes.
        #expect(command.label == "Focus window to the left")
        // What German says is the catalog's; that it translates
        // at all is the split under test.
        #expect(command.resolvedLabel != command.label)
    }

    @Test("a resize preset label resolves to German")
    func resizePresetResolvesGerman() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let grow = KeybindingCatalog.resizeAndFloat(step: 50)[0]
        #expect(grow.label == "Grow width")
        #expect(
            grow.resolvedLabel
                == L("keybinding.grow_width", "Grow width")
        )
        #expect(grow.resolvedLabel != grow.label)
    }

    @Test("a go-to-space label keeps the space name untranslated")
    func goToSpaceKeepsSpaceNameLiteral() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let command = KeybindingCatalog.goToSpace([
            SpaceID("Studio")
        ])[0]
        #expect(command.label == "Go to Space Studio")
        // The sentence translates; the user-authored space
        // name inside it (positional %1$@) does not.
        #expect(
            command.resolvedLabel
                == L("keybinding.go_to_space", "Go to Space %1$@", "Studio")
        )
        #expect(command.resolvedLabel != command.label)
        #expect(command.resolvedLabel.contains("Studio"))
    }

    @Test("switchLayerCommand keeps the mode name untranslated")
    func switchModeKeepsNameLiteral() {
        reset()
        LocalizationManager.shared.select("de")
        defer { reset() }
        let command = KeybindingCatalog.switchLayerCommand(
            "Deep Work"
        )
        #expect(command.label == "Switch to Deep Work")
        #expect(
            command.resolvedLabel
                == L(
                    "keybinding.switch_to_layer",
                    "Switch to %1$@",
                    "Deep Work"
                )
        )
        #expect(command.resolvedLabel != command.label)
        #expect(command.resolvedLabel.contains("Deep Work"))
    }

    @Test("without a translation, resolvedLabel falls back to English")
    func fallsBackToEnglishWithoutTranslation() {
        // An explicit, unshipped locale rather than `nil` —
        // `nil` ("System default") would legitimately resolve
        // to German on a machine whose OS language is German,
        // making this assertion environment-dependent.
        LocalizationManager.shared.select("xx-not-a-real-locale")
        defer { reset() }
        let command = KeybindingCatalog.focusDirections[0]
        #expect(command.resolvedLabel == command.label)
    }
}
