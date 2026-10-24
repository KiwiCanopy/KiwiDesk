import Foundation
import Testing

@testable import KiwiDeskCore

/// A shortcut row the install cannot take is a Config Issue, not a
/// log line alone (#2574): its Lua does not compile, or its chord
/// does not parse. The issue is derived from the last install,
/// sourced to the file holding the row, and leaves with the row.
@Suite("A shortcut the install skips is a Config Issue (#2574)", .serialized)
@MainActor
struct DeadShortcutIssueTests {
    private func core() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-dead-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try "".write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    private func dead(_ core: KiwiCore) -> [ConfigIssue] {
        core.configIssues.filter {
            if case .deadShortcut = $0.kind { return true }
            return false
        }
    }

    private func layer(_ rows: KeyBinding...) -> KeyLayer {
        KeyLayer(name: KeyLayer.defaultName, bindings: rows)
    }

    private static let good = KeyBinding(
        combo: "alt+h",
        lua: "KiwiDesk.focus(\"left\")"
    )

    @Test("Lua that does not compile names the row and the message")
    func luaErrorIsAnIssue() throws {
        let core = try core()
        var config = GuiConfig()
        config.layers = [
            layer(Self.good, KeyBinding(combo: "alt+j", lua: "test "))
        ]
        try core.saveGuiConfig(config)
        let issue = try #require(dead(core).first)
        #expect(dead(core).count == 1)
        #expect(issue.source == "gui.json")
        guard
            case .deadShortcut(let name, let chord, .luaError(let message)) =
                issue.kind
        else {
            Issue.record("expected a Lua error, got \(issue.kind)")
            return
        }
        #expect(name == KeyLayer.defaultName)
        #expect(chord == "alt+j")
        #expect(message.contains("syntax error"))
    }

    @Test("A chord that does not parse is an issue")
    func invalidChordIsAnIssue() throws {
        let core = try core()
        var config = GuiConfig()
        config.layers = [
            layer(KeyBinding(combo: "alt+nosuchkey", lua: "local x = 1"))
        ]
        try core.saveGuiConfig(config)
        #expect(
            dead(core).map(\.kind) == [
                .deadShortcut(
                    layer: KeyLayer.defaultName,
                    chord: "alt+nosuchkey",
                    reason: .invalidChord
                )
            ]
        )
    }

    @Test("Fixing the row clears its issue; a good row raises none")
    func fixedRowClears() throws {
        let core = try core()
        var config = GuiConfig()
        config.layers = [layer(KeyBinding(combo: "alt+j", lua: "test "))]
        try core.saveGuiConfig(config)
        #expect(dead(core).count == 1)
        config.layers = [layer(Self.good)]
        try core.saveGuiConfig(config)
        #expect(dead(core).isEmpty)
    }

    /// A chord another row of the layer installs still fires, and a
    /// chord two failing rows share is one issue.
    @Test("Only a chord nothing installed is dead, once")
    func duplicateChords() throws {
        let core = try core()
        let bad = KeyBinding(combo: "alt+h", lua: "test ")
        var config = GuiConfig()
        config.layers = [layer(bad, Self.good)]
        try core.saveGuiConfig(config)
        #expect(dead(core).isEmpty)
        config.layers = [layer(Self.good, bad)]
        try core.saveGuiConfig(config)
        #expect(dead(core).isEmpty)
        config.layers = [
            layer(bad, KeyBinding(combo: "alt+h", lua: "also bad "))
        ]
        try core.saveGuiConfig(config)
        #expect(dead(core).count == 1)
    }

    /// The issue is derived, so a republish that hands in only the
    /// load's own issues keeps it.
    @Test("The issue survives a derived-issue republish")
    func survivesRepublish() throws {
        let core = try core()
        var config = GuiConfig()
        config.layers = [layer(KeyBinding(combo: "alt+j", lua: "test "))]
        try core.saveGuiConfig(config)
        core.syncDerivedIssues()
        #expect(dead(core).count == 1)
        core.setConfigIssues([])
        #expect(dead(core).count == 1)
    }

    /// `get_config_status` spells it as a machine contract.
    @Test("The status JSON spells both reasons")
    func statusSpelling() {
        let lua = KiwiCore.issueJSON(
            ConfigIssue(
                source: "gui.json",
                kind: .deadShortcut(
                    layer: "default",
                    chord: "alt+j",
                    reason: .luaError("boom")
                )
            )
        )
        let chord = KiwiCore.issueJSON(
            ConfigIssue(
                source: "gui.json",
                kind: .deadShortcut(
                    layer: "default",
                    chord: "alt+x",
                    reason: .invalidChord
                )
            )
        )
        guard case .object(let luaFields) = lua,
            case .object(let chordFields) = chord
        else {
            Issue.record("issues are objects")
            return
        }
        #expect(luaFields["kind"] == .string("dead_shortcut"))
        #expect(luaFields["layer"] == .string("default"))
        #expect(luaFields["chord"] == .string("alt+j"))
        #expect(luaFields["reason"] == .string("lua_error"))
        #expect(luaFields["message"] == .string("boom"))
        #expect(chordFields["reason"] == .string("invalid_chord"))
        #expect(chordFields["message"] == nil)
    }

    @Test("A profile's row files its issue against the profile")
    func profileRowSourcesTheProfile() throws {
        let core = try core()
        let lua = try #require(core.keys.lua)
        core.applyStructuredKeybindings(
            layers: [],
            profile: Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings(),
                layers: KeyLayerOverride(layers: [
                    layer(KeyBinding(combo: "alt+j", lua: "test "))
                ])
            ),
            lua: lua
        )
        #expect(dead(core).map(\.source) == ["Work.json"])
    }
}
