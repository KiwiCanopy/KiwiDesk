import Foundation
import Testing

@testable import KiwiDeskCore

/// What a binding says of itself (#2544) has one home and travels
/// with the row: `KeyBinding.meta` holds the three fields whole, and
/// every comparison, re-import, profile diff and live re-derivation
/// carries a change to them alone.
@Suite("A binding's description travels with it (#2544)", .serialized)
@MainActor
struct ShortcutMetaCarryTests {
    private func loaded(_ lua: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-carry-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    private func symbolIssues(_ core: KiwiCore) -> [ConfigIssue] {
        core.configIssues.filter {
            if case .unknownShortcutSymbol = $0.kind { return true }
            return false
        }
    }

    /// A field added to `KeyBinding` is either one of its own or
    /// joins `KeyBindingMeta`, so no comparison can skip it.
    @Test("KeyBindingMeta is exactly the fields beyond the row's own")
    func metaIsTheOneHome() {
        let own: Set = ["id", "combo", "lua", "kind", "label"]
        #expect(
            fieldNames(KeyBinding()).subtracting(own)
                == fieldNames(KeyBindingMeta())
        )
        var row = KeyBinding()
        let meta = KeyBindingMeta(desc: "D", group: "G", symbol: "star")
        row.meta = meta
        #expect(row.meta == meta)
        #expect(row.desc == "D" && row.group == "G" && row.symbol == "star")
    }

    @Test("A change to one field alone is a different binding")
    func eachFieldCounts() {
        let base = KeyBinding(combo: "alt+h", lua: "x()")
        let changes: [WritableKeyPath<KeyBinding, String>] = [
            \.desc, \.group, \.symbol,
        ]
        for path in changes {
            var changed = base
            changed[keyPath: path] = "new"
            #expect(changed != base)
            let layers = { (row: KeyBinding) in
                [KeyLayer(name: KeyLayer.defaultName, bindings: [row])]
            }
            #expect(
                !RuleReachTable<String>.sameShortcuts(
                    layers(base),
                    layers(changed)
                )
            )
        }
    }

    @Test("Re-import refreshes the fields and clears dropped ones")
    func reimportCarriesMeta() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "x()",
                        desc: "Old",
                        group: "Mine",
                        symbol: "star"
                    )
                ]
            )
        ]
        KeybindingMerge.merge(
            recovered: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [
                        KeyBinding(combo: "alt+h", lua: "x()", desc: "New")
                    ]
                )
            ],
            into: &config
        )
        let row = config.layers[0].bindings
        #expect(row.count == 1)
        #expect(row.first?.meta == KeyBindingMeta(desc: "New"))
    }

    @Test("A profile row that only re-describes the base row is kept")
    func profileKeepsMetaOnlyRow() throws {
        let base = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [KeyBinding(combo: "alt+h", lua: "x()")]
            )
        ]
        var edited = base
        edited[0].bindings[0].desc = "Mine"
        let diff = try #require(
            KeyLayerOverride.diff(base: base, edited: edited)
        )
        #expect(diff.layers.first?.bindings.first?.desc == "Mine")
        #expect(KeyLayerOverride.diff(base: base, edited: base) == nil)
    }

    @Test("Binding a chord again without options clears what it said")
    func rebindClearsMeta() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("alt+h", function() KiwiDesk.focus("left") end,
              { desc = "Left", group = "Mine", symbol = "star" })
            KiwiDesk.bind("alt+h", function() KiwiDesk.focus("left") end)
            """
        )
        let snapshot = try #require(core.liveKeybindingSnapshot())
        let row = try #require(
            snapshot.keyLayers.first?.bindings.first {
                $0.combo == "option+h"
            }
        )
        #expect(row.meta == .none)
    }

    /// The groups and the symbol issue read the chords whose body
    /// was not read back as well as the rows that were.
    @Test("Unread chords reach list_groups and the symbol issue")
    func unreadChordsAreRead() throws {
        let core = try loaded(
            """
            local function follow() KiwiDesk.focus("left") end
            KiwiDesk.bind("alt+f", follow,
              { group = "Hidden", symbol = "kiwidesk.no.such.symbol" })
            """
        )
        #expect(core.customShortcutGroups() == ["Hidden"])
        #expect(
            symbolIssues(core).map(\.kind) == [
                .unknownShortcutSymbol(
                    layer: KeyLayer.defaultName,
                    chord: "option+f",
                    symbol: "kiwidesk.no.such.symbol"
                )
            ]
        )
    }

    @Test("One chord in two key modes is two issues")
    func issuePerLayer() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("h", function() KiwiDesk.focus("left") end,
              { symbol = "kiwidesk.no.such.symbol" })
            KiwiDesk.define_layer("resize", {
              ["h"] = { fn = function() KiwiDesk.focus("left") end,
                        symbol = "kiwidesk.no.such.symbol" },
            })
            """
        )
        let issues = symbolIssues(core)
        #expect(issues.count == 2)
        #expect(Set(issues.map(\.id)).count == 2)
    }

    /// The issue is derived, so a republish that hands in only the
    /// load's own issues must keep it.
    @Test("The issue survives a derived-issue republish")
    func issueSurvivesRepublish() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("alt+h", function() KiwiDesk.focus("left") end,
              { symbol = "kiwidesk.no.such.symbol" })
            """
        )
        #expect(symbolIssues(core).count == 1)
        core.syncDerivedIssues()
        core.setConfigIssues([])
        #expect(symbolIssues(core).count == 1)
    }

    /// A structured install re-derives the issue itself, and names
    /// the active profile's file where its override holds the row.
    @Test("A structured install files the issue against its source")
    func structuredInstallSourcesTheIssue() throws {
        let core = try loaded("")
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        #expect(
            core.execute("load_profile", args: [.string("Work")]).isSuccess
        )
        let lua = try #require(core.keys.lua)
        let layer = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: [
                KeyBinding(
                    combo: "alt+h",
                    lua: "KiwiDesk.focus(\"left\")",
                    symbol: "kiwidesk.no.such.symbol"
                )
            ]
        )
        core.applyStructuredKeybindings(
            layers: [layer],
            profile: nil,
            lua: lua
        )
        #expect(symbolIssues(core).map(\.source) == ["gui.json"])
        core.applyStructuredKeybindings(
            layers: [],
            profile: KeyLayerOverride(layers: [layer]),
            lua: lua
        )
        #expect(symbolIssues(core).map(\.source) == ["Work.json"])
    }
}
