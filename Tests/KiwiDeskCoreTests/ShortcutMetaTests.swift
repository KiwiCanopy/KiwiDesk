import Foundation
import Testing

@testable import KiwiDeskCore

/// A binding says what it does (#2544 ▸ Ruling): `desc`, `group` and
/// `symbol` ride `KiwiDesk.bind`'s option table and `define_layer`'s
/// `{ fn = … }` entries through a real VM onto the bindings a
/// Lua-owned load installs, are stored sparsely on a `KeyBinding`,
/// and a symbol that is no SF Symbol is a Config Issue.
@Suite("Shortcut description, group and symbol (#2544)", .serialized)
@MainActor
struct ShortcutMetaTests {
    private func loaded(_ lua: String) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-meta-\(UUID().uuidString)")
        )
        try FileManager.default.createDirectory(
            at: core.configDirectory,
            withIntermediateDirectories: true
        )
        try lua.write(to: core.configURL, atomically: true, encoding: .utf8)
        core.loadConfig()
        return core
    }

    private func layer(
        _ name: String,
        of core: KiwiCore
    ) throws -> KeyLayer {
        let snapshot = try #require(core.liveKeybindingSnapshot())
        return try #require(snapshot.keyLayers.first { $0.name == name })
    }

    @Test("bind's option table rides onto the installed binding")
    func bindCarriesItsOptions() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("alt+h", function()
              KiwiDesk.focus("left")
            end, { desc = "Left", group = "Mine", symbol = "star" })
            KiwiDesk.bind("alt+l", function()
              KiwiDesk.focus("right")
            end)
            """
        )
        let rows = try layer(KeyLayer.defaultName, of: core).bindings
        let left = try #require(rows.first { $0.combo == "option+h" })
        #expect(left.desc == "Left")
        #expect(left.group == "Mine")
        #expect(left.symbol == "star")
        let right = try #require(rows.first { $0.combo == "option+l" })
        #expect(right.desc.isEmpty && right.group.isEmpty)
    }

    @Test("A define_layer entry may be { fn = …, desc = … }")
    func layerEntryCarriesItsOptions() throws {
        let core = try loaded(
            """
            KiwiDesk.define_layer("resize", {
              ["h"] = { fn = function() KiwiDesk.focus("left") end,
                        desc = "Narrower", group = "size_float" },
              ["l"] = function() KiwiDesk.focus("right") end,
            })
            """
        )
        let rows = try layer("resize", of: core).bindings
        #expect(rows.count == 2)
        let h = try #require(rows.first { $0.combo == "h" })
        #expect(h.desc == "Narrower")
        #expect(h.group == "size_float")
        let l = try #require(rows.first { $0.combo == "l" })
        #expect(l.desc.isEmpty)
    }

    /// A named handler's body is not read back, yet what it says of
    /// itself still is — the reporter's case.
    @Test("An unread chord keeps what it says of itself")
    func unreadChordKeepsItsMeta() throws {
        let core = try loaded(
            """
            local function follow() KiwiDesk.focus("left") end
            KiwiDesk.bind("alt+f", follow, { desc = "Follow", group = "Mine" })
            """
        )
        let snapshot = try #require(core.liveKeybindingSnapshot())
        #expect(
            snapshot.unreadChords(in: KeyLayer.defaultName) == [
                UnreadChord(
                    chord: "option+f",
                    meta: KeyBindingMeta(desc: "Follow", group: "Mine")
                )
            ]
        )
    }

    @Test("The fields are stored sparsely and decode from old files")
    func codingIsSparse() throws {
        let plain = KeyBinding(combo: "alt+h", lua: "x()")
        let json = try JSONEncoder().encode(plain)
        let object = try #require(
            try JSONSerialization.jsonObject(with: json) as? [String: Any]
        )
        #expect(object["desc"] == nil && object["group"] == nil)
        #expect(object["symbol"] == nil)
        let full = KeyBinding(
            combo: "alt+h",
            lua: "x()",
            desc: "D",
            group: "G",
            symbol: "star"
        )
        let back = try JSONDecoder().decode(
            KeyBinding.self,
            from: try JSONEncoder().encode(full)
        )
        #expect(back == full)
        #expect(back != plain)
        let old = Data(#"{"combo":"alt+h","lua":"x()"}"#.utf8)
        #expect(try JSONDecoder().decode(KeyBinding.self, from: old) == plain)
    }

    @Test("A built-in token is matched; any other name is a group of its own")
    func groupsResolve() {
        #expect(ShortcutGroup.filing("focus") == .builtIn(.focus))
        #expect(
            ShortcutGroup.filing(" Move_Windows ") == .builtIn(.moveWindows)
        )
        #expect(ShortcutGroup.filing(" Mine ") == .own("Mine"))
        #expect(ShortcutGroup.filing("  ") == .none)
        let names = ShortcutGroup.custom(
            in: ["B", "focus", "A", " B", ""]
        )
        #expect(names == ["B", "A"])
    }

    @Test("shortcut.list_groups lists the tokens and the groups in use")
    func listGroups() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("alt+h", function() KiwiDesk.focus("left") end,
              { group = "Mine" })
            KiwiDesk.bind("alt+j", function() KiwiDesk.focus("down") end,
              { group = "layout" })
            """
        )
        let response = core.execute("shortcut.list_groups", args: [])
        #expect(response.isSuccess)
        guard case .object(let body)? = response.data,
            case .array(let builtIn)? = body["built_in"],
            case .array(let custom)? = body["custom"]
        else {
            Issue.record(
                "unexpected shape: \(String(describing: response.data))"
            )
            return
        }
        #expect(builtIn.count == ShortcutGroup.allCases.count)
        #expect(custom == [.string("Mine")])
    }

    @Test("A symbol that is no SF Symbol is a Config Issue; a real one is not")
    func unknownSymbolIsAnIssue() throws {
        let core = try loaded(
            """
            KiwiDesk.bind("alt+h", function() KiwiDesk.focus("left") end,
              { symbol = "kiwidesk.no.such.symbol" })
            KiwiDesk.bind("alt+l", function() KiwiDesk.focus("right") end,
              { symbol = "star" })
            """
        )
        let symbols = core.configIssues.compactMap { issue -> String? in
            guard case .unknownShortcutSymbol(_, _, let symbol) = issue.kind
            else { return nil }
            return symbol
        }
        #expect(symbols == ["kiwidesk.no.such.symbol"])
    }
}
