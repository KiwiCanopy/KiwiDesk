import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class CountingRegistrar: HotkeyRegistrar {
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {}
}

/// Shortcuts take effect on Save, like every other setting: a
/// recording, a clear or a deleted row changes only the draft,
/// and the running hotkey table is rebuilt from the saved files
/// alone. A table that ran ahead of the file outlived the window
/// that showed it and vanished at the next restart.
@Suite("Shortcuts apply on Save", .serialized)
@MainActor
struct ShortcutsApplyOnSaveTests {
    private func makeModel() throws -> (SettingsModel, KiwiCore) {
        let core = makeTestCore(
            hotkeyRegistrar: CountingRegistrar()
        )
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "marker = 'keep'"
                    )
                ]
            )
        ]
        try core.saveGuiConfig(config)
        return (makeTestModel(core: core), core)
    }

    private func isRegistered(
        _ combo: String,
        core: KiwiCore
    ) throws -> Bool {
        let parsed = try #require(KeyCombo.parse(combo))
        return core.keys
            .bindings(for: KeyLayer.defaultName)[parsed] != nil
    }

    /// A smoke check of the model half: the recorder's arm and
    /// disarm bracket a draft write the way the field does, and
    /// the disarm resumes the saved table. The row views' closures
    /// are private, so the census below is what reds on a view
    /// that registers ahead of Save.
    @Test("a recorded, cleared or deleted row registers nothing")
    func draftEditsLeaveTheTable() throws {
        let (model, core) = try makeModel()
        #expect(try isRegistered("alt+h", core: core))
        let mode = try #require(
            model.config.layers.firstIndex {
                $0.name == KeyLayer.defaultName
            }
        )

        model.setRecorderArmed(true)
        model.config.layers[mode].bindings.append(
            KeyBinding(combo: "alt+j", lua: "marker = 'new'")
        )
        model.setRecorderArmed(false)
        model.config.layers[mode].bindings.removeAll {
            $0.combo == "alt+h"
        }

        #expect(!(try isRegistered("alt+j", core: core)))
        #expect(try isRegistered("alt+h", core: core))
    }

    /// Every call that writes the running hotkey table, with the
    /// saved source it reads. A new entry is a new way for the
    /// table to run ahead of the files — rule it here.
    private static let installers: [String: (Int, String)] = [
        "KiwiDeskCore/App/KiwiCore+StructuredKeybindings.swift":
            (1, "the one structured door's manager swap"),
        "KiwiDeskCore/App/KiwiCore+StructuredConfig.swift":
            (
                3,
                "config load, profile re-apply and rule refresh,"
                    + " each from the saved gui.json"
            ),
        "KiwiDeskCore/Profiles/KiwiCore+StarterRescale.swift":
            (1, "the digit top-up, from the sidecar it just saved"),
        "KiwiDeskCore/App/KiwiCore+Config.swift":
            (1, "config load clears the table before the file runs"),
        "KiwiDeskCore/Lua/KiwiCore+LuaAPI.swift":
            (2, "init.lua's own bind and layer verbs, run from disk"),
    ]

    @Test("the running table is written only from saved files")
    func installersAreCensused() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let sources = root.appendingPathComponent("Sources")
        // The structured door and the manager's writers, by
        // name alone: arguments are what a new caller changes.
        let call = try NSRegularExpression(
            pattern: #"(?<!func )\b(applyStructuredKeybindings"#
                + #"|replaceLayers|keys\.(bind|defineLayer|reset))\("#
        )
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: sources) {
            let source = SourceScan.stripComments(
                try String(contentsOf: file, encoding: .utf8)
            )
            let count = call.numberOfMatches(
                in: source,
                range: NSRange(source.startIndex..., in: source)
            )
            guard count > 0 else { continue }
            let path = file.path.replacingOccurrences(
                of: sources.path + "/",
                with: ""
            )
            found[path] = count
        }
        #expect(found == Self.installers.mapValues(\.0))
    }
}
