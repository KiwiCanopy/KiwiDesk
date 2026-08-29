import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Restoring the shipped shortcuts into an EXISTING install
/// (#1096).
///
/// The seed fires only into an empty config
/// (`KiwiCore+GuiConfigSeed`), so before this there was no way to
/// take up an improved default — every seed change reached new
/// installs only. These pin what the action produces and what it
/// admits to discarding.
@Suite("Restore default shortcuts (#1096)")
@MainActor
struct RestoreDefaultShortcutsTests {
    private func model(
        spaces: [SpaceID] = [SpaceID("1"), SpaceID("2")]
    ) -> SettingsModel {
        let model = makeTestModel()
        model.config.spaces = spaces
        model.config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [])
        ]
        return model
    }

    /// Derived from the LIVE config, not a snapshot: the same
    /// `spaces` and `resizeStep` the seeder reads, so a user gets
    /// what this machine would have been given.
    @Test("the reset yields exactly the seed for this config")
    func resetMatchesTheSeed() {
        let model = model(
            spaces: [SpaceID("1"), SpaceID("2"), SpaceID("3")]
        )
        model.config.settings.resizeStep = 80
        model.resetShortcutsToDefaults()
        let expected = DefaultKeybindings.bindings(
            spaces: model.config.spaces,
            resizeStep: 80
        )
        let got = model.config.layers[0].bindings
        #expect(got.map(\.combo) == expected.map(\.combo))
        #expect(got.map(\.lua) == expected.map(\.lua))
        #expect(!got.isEmpty)
        // The step is read live, not baked: a row carries it.
        #expect(got.contains { $0.lua.contains("80") })
    }

    @Test("a customised row is gone afterwards")
    func resetDiscardsCustomisations() {
        let model = model()
        model.resetShortcutsToDefaults()
        var layer = model.config.layers[0]
        layer.bindings.append(
            KeyBinding(
                combo: "control+option+j",
                lua: "KiwiDesk.focus(\"left\")",
                kind: .navigation,
                label: "Mine"
            )
        )
        model.config.layers = [layer]
        #expect(
            model.config.layers[0].bindings.contains {
                $0.combo == "control+option+j"
            }
        )
        model.resetShortcutsToDefaults()
        #expect(
            !model.config.layers[0].bindings.contains {
                $0.combo == "control+option+j"
            }
        )
    }

    /// The number the confirmation names. Zero for an untouched
    /// layer, so the dialog can say "nothing of yours is lost"
    /// instead of threatening.
    @Test("the discard count counts only the user's own rows")
    func discardCountIsTheUsersRows() {
        let model = model()
        model.resetShortcutsToDefaults()
        #expect(model.shortcutsTheResetWouldDiscard == 0)
        var layer = model.config.layers[0]
        layer.bindings.append(
            KeyBinding(
                combo: "control+option+j",
                lua: "KiwiDesk.focus(\"left\")",
                kind: .navigation,
                label: "Mine"
            )
        )
        // An EDITED default counts too: same verb, moved combo.
        if let i = layer.bindings.firstIndex(where: {
            $0.lua == "KiwiDesk.toggle_floating()"
        }) {
            layer.bindings[i].combo = "control+option+shift+f"
        }
        model.config.layers = [layer]
        #expect(model.shortcutsTheResetWouldDiscard == 2)
    }

    /// Scoped to the layer the seed authored. A layer the user
    /// invented has no defaults to restore, and the header
    /// disables the row rather than hiding it.
    @Test("a user's own layer is left alone")
    func otherLayersAreUntouched() {
        let model = model()
        let mine = KeyBinding(
            combo: "control+option+j",
            lua: "KiwiDesk.focus(\"left\")",
            kind: .navigation,
            label: "Mine"
        )
        model.config.layers.append(
            KeyLayer(name: "Gaming", bindings: [mine])
        )
        model.resetShortcutsToDefaults()
        let gaming = model.config.layers.first { $0.name == "Gaming" }
        #expect(gaming?.bindings.count == 1)
        #expect(gaming?.bindings.first?.combo == "control+option+j")
        // And the count ignores it, so the dialog cannot claim
        // to discard a row this action will not touch.
        #expect(model.shortcutsTheResetWouldDiscard == 0)
    }
}
