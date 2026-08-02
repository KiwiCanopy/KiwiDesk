import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// `SettingsModel.copyGlobals` mirrors `GuiConfig.CodingKeys` —
/// the set of fields `gui.json` actually persists — and that is
/// a hand-kept field list, so `.claude/rules/parity-tests.md`
/// wants a guard that **derives** the truth rather than
/// re-enumerating it.
///
/// The drift is silent and permanent in both directions. Add a
/// seventh key to `gui.json` and forget `copyGlobals`, and the
/// globals-only save writes it but never marks it clean: the
/// footer reads "Unsaved changes" forever and the user re-saves
/// into a void. Drop a key from the file and leave it in
/// `copyGlobals`, and the model calls clean something that was
/// never written.
///
/// `CodingKeys` is `private`, so this asks the encoder instead
/// of the type: whatever survives a `gui.json` round-trip is,
/// by definition, what the file persists.
@Suite("gui.json field parity")
@MainActor
struct GlobalsFieldParityTests {
    /// A config with every persisted field moved off its
    /// default, so a missed field cannot coincidentally match.
    private func editedConfig() -> GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID("alpha"), SpaceID("beta")]
        config.appRules = ["com.example.app": SpaceID("beta")]
        config.floatRules = ["com.example.floaty"]
        config.ignoreRules = ["com.example.ignored"]
        config.profileBindings = [3: "Desk"]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "alt+q", lua: "x = 1")
                ]
            )
        ]
        // Tiling is deliberately NOT in `gui.json` — it rides
        // the profile. Moving it here proves the round-trip
        // drops it and that `copyGlobals` does not carry it.
        config.settings.gapsGlobal.inner.horizontal = 31
        return config
    }

    @Test("copyGlobals carries exactly what gui.json persists")
    func copyGlobalsMatchesTheEncodedShape() throws {
        let edited = editedConfig()

        // What the file actually round-trips.
        let data = try JSONEncoder().encode(edited)
        let persisted = try JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )

        // What the model carries into its clean baseline.
        var carried = GuiConfig()
        SettingsModel.copyGlobals(from: edited, into: &carried)

        #expect(
            carried == persisted,
            """
            copyGlobals and gui.json disagree about which \
            fields are global. A field persisted but not \
            copied leaves the footer permanently dirty; a \
            field copied but not persisted marks unsaved work \
            clean.
            """
        )
    }

    /// The other half of the same invariant, stated positively
    /// so a reader sees what "global" excludes: tiling survives
    /// neither the file nor the copy.
    @Test("tiling is carried by neither the file nor the copy")
    func tilingIsNotGlobal() throws {
        let edited = editedConfig()
        let data = try JSONEncoder().encode(edited)
        let persisted = try JSONDecoder().decode(
            GuiConfig.self,
            from: data
        )
        var carried = GuiConfig()
        SettingsModel.copyGlobals(from: edited, into: &carried)

        let untouched = GuiConfig().settings.gapsGlobal.inner
            .horizontal
        #expect(
            persisted.settings.gapsGlobal.inner.horizontal
                == untouched
        )
        #expect(
            carried.settings.gapsGlobal.inner.horizontal
                == untouched
        )
    }
}
