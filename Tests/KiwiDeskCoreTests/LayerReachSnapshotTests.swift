import Foundation
import Testing

@testable import KiwiDeskCore

/// #2022: layer edits are laid over the stored shortcut files
/// ahead of the key table (`rewriteLayers`), and a save writes
/// every file whose layers moved — and only those.
@Suite("Rule reach, layer edits (#2022)")
@MainActor
struct LayerReachSnapshotTests {
    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .custom, label: lua)
    }

    private var gaming: KeyLayer {
        KeyLayer(name: "Gaming", bindings: [row("w", "up()")])
    }

    private var base: [KeyLayer] {
        [
            KeyLayer(name: "default", bindings: [row("alt+g", "go()")]),
            gaming,
        ]
    }

    private func dropping(_ name: String) -> ([KeyLayer]) -> [KeyLayer] {
        { $0.filter { $0.name != name } }
    }

    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-layer-\(UUID().uuidString)")
        )
        var gui = GuiConfig()
        gui.layers = base
        try core.guiConfigStore.save(gui)
        for name in ["Desk", "Laptop", "Travel"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        return core
    }

    private func bytes(_ core: KiwiCore, _ name: String) throws -> Data {
        try Data(contentsOf: core.profiles.fileURL(name: name))
    }

    @Test("leaving one profile out marks it and keeps the base")
    func leaveOneOut() throws {
        let core = try makeCore()
        let laptop = try bytes(core, "Laptop")
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.rewriteLayers(["Desk": dropping("Gaming")])
        #expect(snapshot.isEdited)
        #expect(snapshot.layerTable.leftOut("Gaming") == ["Desk"])
        try core.saveRuleReach(snapshot)
        #expect(
            try core.profiles.read(name: "Desk").layers?.leftOut
                == ["Gaming"]
        )
        #expect(
            core.guiConfigStore.load()?.layers.map(\.name)
                == ["default", "Gaming"]
        )
        #expect(try bytes(core, "Laptop") == laptop)
    }

    @Test("dropping a layer everywhere writes the base alone")
    func deleteEverywhere() throws {
        let core = try makeCore()
        let desk = try bytes(core, "Desk")
        var snapshot = try #require(core.ruleReachSnapshot())
        let drop = dropping("Gaming")
        snapshot.rewriteLayers(
            ["Desk": drop, "Laptop": drop, "Travel": drop],
            base: drop
        )
        try core.saveRuleReach(snapshot)
        #expect(
            core.guiConfigStore.load()?.layers.map(\.name)
                == ["default"]
        )
        // Nothing diverges, so no profile file is rewritten.
        #expect(try bytes(core, "Desk") == desk)
    }

    @Test("a layer leaving the base stays with the profiles that keep it")
    func sharedToListed() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.rewriteLayers(
            ["Travel": dropping("Gaming")],
            base: dropping("Gaming")
        )
        try core.saveRuleReach(snapshot)
        let desk = try core.profiles.read(name: "Desk")
        #expect(desk.layers?.layers == [gaming])
        #expect(try core.profiles.read(name: "Travel").layers == nil)
        let table = try #require(core.ruleReachSnapshot()).layerTable
        #expect(
            table.reach(of: "Gaming", editing: "Desk")
                == .listed(["Desk", "Laptop"])
        )
    }

    @Test("an untouched snapshot is not edited")
    func untouchedIsClean() throws {
        let core = try makeCore()
        var snapshot = try #require(core.ruleReachSnapshot())
        snapshot.rewriteLayers([:])
        #expect(!snapshot.isEdited)
    }

    /// The loaded page lacks a shared layer its profile leaves out;
    /// the base the page derives must keep it, in its place.
    @Test("the loaded page's base keeps a layer its profile left out")
    func pageBaseKeepsLeftOut() {
        let table = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: [("Desk", KeyLayerOverride(leftOut: ["Gaming"]))]
        )
        let page = [base[0]]
        let derived = table.keyLayerBase(
            page: page,
            editing: "Desk",
            storedPage: page,
            storedBase: base,
            templates: [:]
        )
        #expect(derived == base)
    }
}
