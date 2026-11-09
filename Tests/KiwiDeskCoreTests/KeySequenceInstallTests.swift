import Foundation
import Testing

@testable import KiwiDeskCore

/// A sequence reaches the running table through both owners — Lua's
/// `define_sequence` and a structured install — and never as a
/// Carbon hotkey (#1871).
@MainActor
@Suite("Key sequence install")
struct KeySequenceInstallTests {
    private func loaded(_ lua: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-seq-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    static let script = """
        KiwiDesk.define_sequence("ctrl+alt+space", {
          w = { name = "Windows", keys = {
            h = function() KiwiDesk.focus("left") end,
          } },
          t = { fn = function() KiwiDesk.toggle_float() end,
                desc = "Float it" },
        }, { name = "Leader" })
        """

    @Test("define_sequence builds the tree in the default layer")
    func luaDefines() throws {
        let core = try loaded(Self.script)
        let held = core.keys.sequences(for: "default")
        #expect(held.count == 1)
        #expect(held.first?.label == "Leader")
        #expect(held.first?.steps.map(\.stored) == ["t", "w"])
        #expect(held.first?.refs.count == 2)
    }

    @Test("Two spellings of one step chord keep the last")
    func luaStepDuplicate() throws {
        let core = try loaded(
            """
            KiwiDesk.define_sequence("ctrl+alt+space", {
              ["alt+a"] = function() KiwiDesk.focus("left") end,
              ["opt+a"] = function() KiwiDesk.focus("right") end,
            })
            """
        )
        let held = try #require(core.keys.sequences(for: "default").first)
        #expect(held.steps.map(\.stored) == ["opt+a"])
        #expect(held.refs.count == 1)
    }

    @Test("A leader registers no Carbon hotkey")
    func leaderIsNotCarbon() throws {
        let core = try loaded(Self.script)
        let leader = try #require(KeyCombo.parse("ctrl+alt+space"))
        #expect(core.keys.bindings(for: "default")[leader] == nil)
        #expect(
            !core.keys.activeBindings.values.contains { $0.combo == leader }
        )
    }

    @Test("A leader takes its chord from a press row on it")
    func leaderWinsItsChord() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("ctrl+alt+space",
              function() KiwiDesk.focus("up") end)
            """ + "\n" + Self.script
        )
        let leader = try #require(KeyCombo.parse("ctrl+alt+space"))
        #expect(
            !core.keys.activeBindings.values.contains { $0.combo == leader }
        )
    }

    @Test("The importer reads a Lua sequence back whole")
    func importerReadsItBack() throws {
        let core = try loaded(Self.script)
        let lua = try #require(core.keys.lua)
        let captured = KeybindingImporter.capture(
            from: core.keys,
            interpreter: lua,
            readFile: KeybindingImporter.readSource
        )
        let row = try #require(
            captured.layers.first { $0.isDefault }?.sequences.first
        )
        #expect(row.combo == "ctrl+alt+space")
        #expect(row.label == "Leader")
        #expect(
            row.endKeys.map(\.path) == [
                ["ctrl+alt+space", "t"], ["ctrl+alt+space", "w", "h"],
            ]
        )
        #expect(row.steps?.first?.desc == "Float it")
        #expect(row.steps?.last?.label == "Windows")
        #expect(
            row.endKeys.last?.binding.lua == "KiwiDesk.focus(\"left\")"
        )
    }

    @Test("One unread end key leaves the whole sequence unread")
    func unreadEndKeyDropsTheSequence() throws {
        let core = try loaded(
            """
            local named = function() KiwiDesk.focus("left") end
            KiwiDesk.define_sequence("ctrl+alt+space", {
              h = named,
              t = function() KiwiDesk.toggle_float() end,
            })
            """
        )
        let lua = try #require(core.keys.lua)
        let captured = KeybindingImporter.capture(
            from: core.keys,
            interpreter: lua,
            readFile: { _ in nil }
        )
        #expect(captured.layers.first?.sequences.isEmpty == true)
        #expect(
            captured.unread["default"]?.map(\.chord) == ["ctrl+alt+space"]
        )
    }

    @Test("An unread Lua sequence still names its keys for the panel")
    func runningTreeForUnread() throws {
        let core = try loaded(
            """
            KiwiDesk.define_sequence("ctrl+alt+space", {
              h = { fn = KiwiDesk.toggle_float, name = "Left" },
            }, { name = "Leader" })
            """
        )
        let tree = try #require(
            core.runningKeySequence(leader: "ctrl+alt+space")
        )
        #expect(tree.label == "Leader")
        #expect(tree.steps?.map(\.label) == ["Left"])
        #expect(core.runningKeySequence(leader: "ctrl+k") == nil)
    }

    @Test("A structured sequence compiles beside the press table")
    func structuredInstall() throws {
        let core = try loaded("")
        let lua = try #require(core.keys.lua)
        let press = KeyBinding(combo: "alt+h", lua: "KiwiDesk.focus(\"left\")")
        core.applyStructuredKeybindings(
            layers: [
                KeyLayer(
                    name: "default",
                    bindings: [press, KeySequenceStorageTests.windows]
                )
            ],
            profile: nil,
            lua: lua
        )
        let leader = try #require(KeyCombo.parse("ctrl+alt+space"))
        #expect(core.keys.bindings(for: "default")[leader] == nil)
        #expect(core.keys.bindings(for: "default").count == 1)
        let held = try #require(core.keys.sequences(for: "default").first)
        #expect(held.refs.count == 3)
        // The installed snapshot keeps the tree the router answers.
        let snapshot = try #require(core.liveKeybindingSnapshot())
        #expect(
            snapshot.keyLayers.first?.sequences
                == [KeySequenceStorageTests.windows]
        )
    }

    @Test("A broken end key is skipped and filed under its leader")
    func brokenEndKeyIsFiled() throws {
        let core = try loaded("")
        let lua = try #require(core.keys.lua)
        let broken = KeyBinding.sequence(
            combo: "ctrl+alt+space",
            steps: [
                KeyBinding(combo: "h", lua: "this is not lua ("),
                KeyBinding(combo: "t", lua: "KiwiDesk.toggle_float()"),
            ]
        )
        core.applyStructuredKeybindings(
            layers: [KeyLayer(name: "default", bindings: [broken])],
            profile: nil,
            lua: lua
        )
        let held = try #require(core.keys.sequences(for: "default").first)
        #expect(held.steps.map(\.stored) == ["t"])
        guard case .structured(_, _, let skipped)? = core.installedKeybindings
        else {
            Issue.record("not a structured install")
            return
        }
        #expect(skipped.map(\.chord) == ["ctrl+alt+space"])
        // The panel reads the pruned tree, never the broken key.
        #expect(
            core.liveKeybindingSnapshot()?.keyLayers.first?.sequences
                .first?.steps?.map(\.combo) == ["t"]
        )
    }

    @Test("A reset releases every end key's ref")
    func resetReleases() throws {
        let core = try loaded(Self.script)
        let lua = try #require(core.keys.lua)
        let ref = try #require(core.keys.sequences(for: "default").first)
            .refs[0]
        #expect((try? lua.call(ref: ref).get()) != nil)
        core.keys.reset()
        #expect(core.keys.sequences(for: "default").isEmpty)
        #expect((try? lua.call(ref: ref).get()) == nil)
    }

    @Test("A fired end key runs its function")
    func firedRuns() throws {
        let core = try loaded(
            """
            KiwiDesk.define_sequence("ctrl+alt+space", {
              t = function() seq_hit = (seq_hit or 0) + 1 end,
            })
            """
        )
        let lua = try #require(core.keys.lua)
        let ref = try #require(core.keys.sequences(for: "default").first)
            .refs[0]
        core.keys.sequenceDecided(
            KeySequenceDecision(
                outcome: .fired(ref: ref),
                progress: nil,
                generation: core.keys.sequenceGeneration
            )
        )
        #expect((try? lua.run("assert(seq_hit == 1)").get()) != nil)
    }
}
