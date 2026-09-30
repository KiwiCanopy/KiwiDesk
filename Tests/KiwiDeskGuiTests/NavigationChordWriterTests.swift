import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Every GUI writer of layer rows leaves a navigation action one
/// chord per layer (#1797, #1807): each door is driven with a
/// fixture that would hand an action a second chord, and the one
/// predicate below is asked of what it wrote. A new writer joins
/// this suite.
@Suite("Navigation chord writers (#1807)", .serialized)
@MainActor
struct NavigationChordWriterTests {
    /// The navigation actions holding more than one chord in any
    /// layer, as `NavigationChords` counts them.
    private func duplicated(_ config: GuiConfig) -> [String] {
        config.layers.flatMap { layer in
            let rows = layer.bindings
            let deduped = NavigationChords.deduplicated(
                rows,
                liveSpaces: Set(config.spaces)
            )
            return deduped.dropped.map { "\(layer.name): \($0.dropped.lua)" }
        }
    }

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation, label: "")
    }

    private func goTo(_ space: String) -> String {
        "KiwiDesk.focus_space(\"\(space)\")"
    }

    /// A Lua-owned core whose `init.lua` binds Space 1 and focus-left
    /// twice each.
    private func luaCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-chords-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        let lua = """
            KiwiDesk.bind("ctrl+alt+f1", function()
                KiwiDesk.focus_space("1")
            end)
            KiwiDesk.bind("ctrl+alt+1", function()
                KiwiDesk.focus_space("1")
            end)
            KiwiDesk.bind("ctrl+alt+left", function()
                KiwiDesk.focus("left")
            end)
            KiwiDesk.bind("ctrl+alt+h", function()
                KiwiDesk.focus("left")
            end)
            """
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        core.state.workspaces.ensureSpace(SpaceID("1"))
        return core
    }

    @Test("a rename over a deleted Space's rows")
    func renameWriter() {
        var config = GuiConfig()
        config.spaces = [SpaceID("3")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    row("control+option+3", goTo("3")),
                    row("control+option+7", goTo("7")),
                ]
            )
        ]
        let renamed = config.renameSpace(
            from: SpaceID("3"),
            to: SpaceID("7")
        )
        #expect(renamed)
        #expect(duplicated(config).isEmpty)
        // Vacuity: the rename reached the rows.
        #expect(config.layers[0].bindings.allSatisfy { $0.lua == goTo("7") })
    }

    @Test("the digit top-up over a reordered list")
    func topUpWriter() {
        var config = GuiConfig()
        config.spaces = ["2", "3", "4", "Mail", "1", "5"].map { SpaceID($0) }
        let seed = DefaultKeybindings.bindings(
            spaces: ["1", "2", "3", "4"].map { SpaceID($0) },
            resizeStep: 50
        )
        let added = DefaultKeybindings.digitTopUp(
            existing: seed,
            spaces: config.spaces
        )
        #expect(!added.isEmpty)
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: seed + added)
        ]
        #expect(duplicated(config).isEmpty)
    }

    @Test("a restore of the default shortcuts")
    func resetWriter() {
        let model = makeTestModel()
        model.config.spaces = [SpaceID("1")]
        let desktop = "KiwiDesk.focus_desktop(2)"
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    row("control+option+f2", desktop),
                    row("control+option+f3", desktop),
                ]
            )
        ]
        model.resetShortcutsToDefaults()
        #expect(duplicated(model.config).isEmpty)
        #expect(model.config.layers[0].bindings.contains { $0.lua == desktop })
    }

    @Test("an import from init.lua")
    func importWriter() throws {
        let core = try luaCore()
        let model = makeTestModel(core: core)
        model.config.spaces = [SpaceID("1")]
        model.importCurrentShortcuts()
        #expect(duplicated(model.config).isEmpty)
        // Vacuity and the report: both extras were named.
        #expect(model.droppedChords.count == 2)
        #expect(
            model.droppedChords.contains {
                KeyCombo.parse($0.kept.combo)
                    == KeyCombo.parse("ctrl+alt+1")
            }
        )
    }

    @Test("an adoption of init.lua into Settings")
    func adoptionWriter() throws {
        let core = try luaCore()
        let model = makeTestModel(core: core)
        model.adoptIntoGui()
        let saved = try #require(core.guiConfigStore.load())
        #expect(duplicated(saved).isEmpty)
        #expect(model.droppedChords.count == 2)
    }
}
