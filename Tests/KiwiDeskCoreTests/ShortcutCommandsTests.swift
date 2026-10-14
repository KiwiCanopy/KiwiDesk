import Foundation
import Testing

@testable import KiwiDeskCore

/// The `shortcut.*` verbs (#1685 ▸ Ruling 6c): a shortcut saves at
/// once, the shortcut rows alone; it binds a command `run` could
/// send, never raw Lua; and it never replaces a binding.
@Suite("Shortcut commands", .serialized)
@MainActor
struct ShortcutCommandsTests {
    private func run(
        _ core: KiwiCore,
        _ command: String,
        _ args: [JSONValue]
    ) -> CommandResponse {
        core.execute(command, args: args)
    }

    private func baseRows(_ core: KiwiCore) -> [KeyBinding] {
        core.guiConfigStore.load()?.layers.first(where: \.isDefault)?
            .bindings ?? []
    }

    @Test("a set saves one row in the shared default layer")
    func setSavesTheRow() throws {
        let core = try KeepFixture.core()
        // The keys run on the VM a config load boots.
        try core.saveGuiConfig(try #require(core.guiConfigStore.load()))
        let set = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+h"), .string("focus"),
                .array([.string("left")]),
            ]
        )
        #expect(set.isSuccess)
        #expect(
            baseRows(core).contains {
                $0.combo == "control+option+h"
                    && $0.lua == "KiwiDesk.focus(\"left\")"
            }
        )
        #expect(try core.profiles.read(name: "Work").layers == nil)
        // The bound Lua runs: a core verb is the KiwiDesk table's.
        let lua = try #require(
            baseRows(core).first { $0.combo == "control+option+h" }?.lua
        )
        let ran = try #require(core.lua?.run(lua))
        if case .failure(let error) = ran {
            Issue.record("bound Lua failed: \(error)")
        }
        // Keys load only from the files: the saved row registers now.
        let combo = try #require(KeyCombo.parse("ctrl+alt+h"))
        #expect(core.keys.bindings(for: KeyLayer.defaultName)[combo] != nil)
        _ = run(core, "shortcut.remove", [.string("ctrl+alt+h")])
        #expect(core.keys.bindings(for: KeyLayer.defaultName)[combo] == nil)
    }

    @Test("a set leaves other unkept changes live and unwritten")
    func setLeavesOtherChangesLive() throws {
        let core = try KeepFixture.core()
        #expect(
            run(core, "app_rule.set_space", [.string("com.x"), .string("1")])
                .isSuccess
        )
        _ = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+j"), .string("focus"),
                .array([.string("down")]),
            ]
        )
        #expect(core.state.appRules["com.x"] == "1")
        #expect(core.guiConfigStore.load()?.appRules["com.x"] == nil)
    }

    @Test("only a command run could send is bound, never Lua")
    func onlyRunnableCommandsBind() throws {
        let core = try KeepFixture.core()
        let refused: [(String, [JSONValue])] = [
            ("exec", [.string("rm -rf ~")]),
            ("close_window", []),
            ("keep_settings", []),
            ("shortcut.remove", [.string("ctrl+alt+h")]),
            ("no_such_verb", []),
            ("focus", [.array([])]),
            ("focus", [.string("left"), .string("extra"), .string("x")]),
            ("focus", [.number(42)]),
            ("focus", [.string("sideways")]),
        ]
        for (name, args) in refused {
            let set = run(
                core,
                "shortcut.set",
                [.string("ctrl+alt+k"), .string(name), .array(args)]
            )
            #expect(!set.isSuccess, "\(name)")
        }
        #expect(!baseRows(core).contains { $0.combo == "control+option+k" })
    }

    @Test("a taken chord or a bound command is refused")
    func neverReplaces() throws {
        let core = try KeepFixture.core()
        let first: [JSONValue] = [
            .string("ctrl+alt+h"), .string("focus"), .array([.string("left")]),
        ]
        #expect(run(core, "shortcut.set", first).isSuccess)
        #expect(run(core, "shortcut.set", first).isSuccess)
        let taken = run(
            core,
            "shortcut.set",
            [.string("alt+ctrl+h"), .string("focus"), .array([.string("up")])]
        )
        #expect(taken.error?.contains("remove it first") == true)
        let moved = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+y"), .string("focus"),
                .array([.string("left")]),
            ]
        )
        #expect(moved.error?.contains("remove it first") == true)
        #expect(
            baseRows(core).filter { $0.lua == "KiwiDesk.focus(\"left\")" }
                .count == 1
        )
    }

    @Test("a remove unbinds the chord and refuses a free one")
    func removeUnbinds() throws {
        let core = try KeepFixture.core()
        _ = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+h"), .string("focus"),
                .array([.string("left")]),
            ]
        )
        #expect(
            run(core, "shortcut.remove", [.string("ctrl+alt+h")]).isSuccess
        )
        #expect(!baseRows(core).contains { $0.combo == "control+option+h" })
        #expect(
            !run(core, "shortcut.remove", [.string("ctrl+alt+h")]).isSuccess
        )
    }

    @Test("an init.lua config's shortcuts are not written")
    func luaOwnsShortcuts() throws {
        let core = try KeepFixture.core(gui: false)
        let set = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+h"), .string("focus"),
                .array([.string("left")]),
            ]
        )
        #expect(!set.isSuccess)
    }

    @Test("a string argument is quoted as one Lua literal")
    func literalsAreQuoted() {
        #expect(
            ShortcutCall.literal(.string("a\"b\\c\n")) == "\"a\\\"b\\\\c\\n\""
        )
        #expect(ShortcutCall.literal(.number(3)) == "3")
        #expect(ShortcutCall.literal(.bool(false)) == "false")
        #expect(ShortcutCall.literal(.string("\u{07}")) == nil)
        #expect(ShortcutCall.literal(.array([])) == nil)
    }

    /// A Space verb is one action whatever its argument's spelling
    /// (`NavigationChords.sameAction`), so a seeded row with a
    /// string Space refuses a second chord given a number.
    @Test("a seeded action written another way is still bound")
    func seededActionIsBound() throws {
        let core = try KeepFixture.core()
        var base = try #require(core.guiConfigStore.load())
        base.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "control+option+1",
                        lua: "KiwiDesk.focus_space(\"1\")"
                    )
                ]
            )
        ]
        try core.guiConfigStore.save(base)
        let set = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+9"), .string("focus_space"),
                .array([.number(1)]),
            ]
        )
        #expect(set.error?.contains("remove it first") == true)
        #expect(baseRows(core).count == 1)
    }

    /// A base row every profile leaves out is still the shared one a
    /// write would take over, so its chord is refused.
    @Test("a base chord every page leaves out is still taken")
    func leftOutBaseChordIsTaken() throws {
        let core = try KeepFixture.core()
        var base = try #require(core.guiConfigStore.load())
        base.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "control+option+x",
                        lua: "KiwiDesk.focus(\"up\")"
                    )
                ]
            )
        ]
        try core.guiConfigStore.save(base)
        let leftOut = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["control+option+x"]]
        )
        for name in ["Work", "Odd"] {
            var profile = KeepFixture.profile(name)
            profile.layers = leftOut
            try core.profiles.save(profile)
        }
        KeepFixture.load("Odd", core)
        let set = run(
            core,
            "shortcut.set",
            [
                .string("ctrl+alt+x"), .string("focus"),
                .array([.string("left")]),
            ]
        )
        #expect(set.error?.contains("remove it first") == true)
    }
}
