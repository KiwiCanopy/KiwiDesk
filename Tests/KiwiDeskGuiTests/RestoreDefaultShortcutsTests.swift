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
/// installs only.
///
/// The restore replaces only what the seed AUTHORS, because those
/// are the only shortcuts KiwiDesk provides and so the only ones
/// it can restore (owner ruling). App launchers and anything else
/// the user invented are not customised defaults; they survive.
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

    private func row(
        _ combo: String,
        _ lua: String,
        _ label: String = "Mine"
    ) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: lua,
            kind: .navigation,
            label: label
        )
    }

    private func setBindings(
        _ model: SettingsModel,
        _ rows: [KeyBinding]
    ) {
        var layer = model.config.layers[0]
        layer.bindings = rows
        model.config.layers = [layer]
    }

    /// Derived from the LIVE config, not a snapshot: a user gets
    /// what this machine would have been given.
    @Test("the reset yields the seed for this config")
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

    /// The owner's ruling, and the case his question found: an
    /// app launcher is not a default, so a restore must not
    /// delete it. It sits on a chord the seed never claims.
    @Test("a shortcut KiwiDesk never provided survives")
    func inventedRowsSurvive() {
        let model = model()
        let app = row(
            "control+option+command+j",
            "KiwiDesk.open_or_focus(\"com.apple.Safari\")",
            "Safari"
        )
        setBindings(model, [app])
        model.resetShortcutsToDefaults()
        let after = model.config.layers[0].bindings
        #expect(
            after.contains {
                $0.lua == app.lua && $0.combo == app.combo
            }
        )
        // …and it is not reported as a loss.
        #expect(model.shortcutsTheResetWouldDiscard == 0)
    }

    /// The cost that IS real, so the confirmation counts it: a
    /// row of the user's parked on a chord the seed reclaims
    /// cannot stay, or the restore manufactures a conflict.
    @Test("a row on a chord the seed reclaims is discarded")
    func rowsOnShippedChordsGo() {
        let model = model()
        model.resetShortcutsToDefaults()
        let taken = model.config.layers[0].bindings[0].combo
        let mine = row(taken, "KiwiDesk.open_or_focus(\"x\")")
        setBindings(model, [mine])
        #expect(model.shortcutsTheResetWouldDiscard == 1)
        model.resetShortcutsToDefaults()
        #expect(
            !model.config.layers[0].bindings.contains {
                $0.lua == mine.lua
            }
        )
    }

    /// A default whose combo the user moved is still the seed's
    /// row, so it goes — otherwise the verb would be bound twice.
    @Test("a moved default is replaced, not duplicated")
    func movedDefaultsAreReplaced() {
        let model = model()
        model.resetShortcutsToDefaults()
        let shipped = model.config.layers[0].bindings
        let float = shipped.first {
            $0.lua == "KiwiDesk.toggle_floating()"
        }!
        setBindings(
            model,
            [row("control+option+shift+f", float.lua)]
        )
        // NOT a loss: the verb returns on its shipped chord,
        // which is the whole point of the button. Counting it
        // was the design review's "if you do one thing".
        #expect(model.shortcutsTheResetWouldDiscard == 0)
        model.resetShortcutsToDefaults()
        let after = model.config.layers[0].bindings
        #expect(after.filter { $0.lua == float.lua }.count == 1)
        #expect(
            after.first { $0.lua == float.lua }?.combo
                == float.combo
        )
    }

    /// Scoped to the layer the seed authored. A layer the user
    /// invented has no defaults to restore, and the header
    /// disables the row rather than hiding it.
    ///
    /// Asserts only NEGATIVES, so it passes against a do-nothing
    /// reset — discriminating in company with the tests above,
    /// never alone (`guard-prover`, 2026-08-29).
    @Test("a user's own layer is left alone")
    func otherLayersAreUntouched() {
        let model = model()
        let mine = row("control+option+j", "KiwiDesk.focus(\"left\")")
        model.config.layers.append(
            KeyLayer(name: "Gaming", bindings: [mine])
        )
        model.resetShortcutsToDefaults()
        let gaming = model.config.layers.first {
            $0.name == "Gaming"
        }
        #expect(gaming?.bindings.count == 1)
        #expect(gaming?.bindings.first?.combo == mine.combo)
        #expect(model.shortcutsTheResetWouldDiscard == 0)
    }

    /// Rows targeting a Space that no longer exists are STALE
    /// DEFAULTS, not inventions — a fresh install with these
    /// Spaces would have none of them — so a restore drops them.
    ///
    /// #92 keeps them as holders through ordinary editing, in
    /// case the Space returns; an explicit restore is a different
    /// act. Owner observation on the running build, 2026-08-29:
    /// they survived the first implementation.
    @Test("a shortcut for a Space that is gone does not survive")
    func orphanedRowsAreDropped() {
        let model = model(spaces: [SpaceID("1"), SpaceID("2")])
        // Space 9 is not in `spaces`, so this row is inactive.
        let stale = row(
            "control+option+9",
            "KiwiDesk.focus_space(\"9\")",
            "Go to Space 9"
        )
        setBindings(model, [stale])
        #expect(model.shortcutsTheResetWouldDiscard == 0)
        model.resetShortcutsToDefaults()
        #expect(
            !model.config.layers[0].bindings.contains {
                $0.lua == stale.lua
            }
        )
        // Not counted as a loss: it is KiwiDesk's own row for a
        // Space that is gone, not a shortcut the user invented.
        #expect(model.shortcutsTheResetWouldDiscard == 0)
    }

}
