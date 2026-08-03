import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("LuaBindingBody extraction")
struct LuaBindingBodyTests {
    @Test("Pulls a one-line body out of the whole call")
    func inlineBody() {
        let source =
            "KiwiDesk.bind(\"alt+h\", function() "
            + "KiwiDesk.focus(\"left\") end)"
        #expect(
            // Leading indent and per-line trailing space are both
            // stripped, so the inline form has no dangling space.
            LuaBindingBody.extract(
                from: source,
                firstLine: 1,
                lastLine: 1
            ) == "KiwiDesk.focus(\"left\")"
        )
    }

    @Test("Balances nested if/end and dedents")
    func nestedIf() {
        let source = """
            KiwiDesk.bind("x", function()
              if cond then
                do_thing()
              end
            end)
            """
        #expect(
            LuaBindingBody.extract(
                from: source,
                firstLine: 1,
                lastLine: 5
            ) == "if cond then\n  do_thing()\nend"
        )
    }

    @Test("A for loop's do is closed by its own end")
    func forLoop() {
        let source = """
            bind(function()
              for i = 1, 3 do
                step(i)
              end
            end)
            """
        #expect(
            LuaBindingBody.extract(
                from: source,
                firstLine: 1,
                lastLine: 5
            ) == "for i = 1, 3 do\n  step(i)\nend"
        )
    }

    @Test("`end` inside a string or comment isn't counted")
    func endInTrivia() {
        let source = """
            bind(function()
              local s = "end"  -- end here
              print(s)
            end)
            """
        #expect(
            LuaBindingBody.extract(
                from: source,
                firstLine: 1,
                lastLine: 4
            ) == "local s = \"end\"  -- end here\nprint(s)"
        )
    }

    @Test("An empty body comes back empty, not nil")
    func emptyBody() {
        #expect(
            LuaBindingBody.extract(
                from: "bind(function() end)",
                firstLine: 1,
                lastLine: 1
            ) == ""
        )
    }

    @Test("A range with no function returns nil")
    func noFunction() {
        #expect(
            LuaBindingBody.extract(
                from: "local x = 1",
                firstLine: 1,
                lastLine: 1
            ) == nil
        )
    }
}

@Suite("KeyCombo instance round-trip")
struct KeyComboInstanceTests {
    @Test("comboString() reverses parse for import")
    func roundTrip() throws {
        let combo = try #require(KeyCombo.parse("cmd+shift+left"))
        let text = try #require(combo.comboString())
        #expect(text == "shift+command+left")
        #expect(KeyCombo.parse(text) == combo)
    }
}

@Suite("KeybindingMerge")
struct KeybindingMergeTests {
    private func layer(
        _ name: String,
        _ rows: [KeyBinding],
        icon: String? = nil
    ) -> KeyLayer {
        KeyLayer(name: name, icon: icon, bindings: rows)
    }

    private func row(
        _ combo: String,
        _ lua: String,
        _ kind: KeyBinding.Kind = .custom
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: kind)
    }

    @Test("A new layer is appended whole")
    func appendsNewMode() {
        var config = GuiConfig()
        config.layers = [layer("default", [])]
        KeybindingMerge.merge(
            recovered: [layer("resize", [row("h", "x()")])],
            into: &config
        )
        #expect(config.layers.map(\.name) == ["default", "resize"])
        #expect(config.layers[1].bindings.count == 1)
    }

    @Test("Same combo is replaced, a free combo appended")
    func upsertByCombo() {
        var config = GuiConfig()
        config.layers = [
            layer("default", [row("alt+h", "old()")])
        ]
        KeybindingMerge.merge(
            recovered: [
                layer(
                    "default",
                    [
                        row("alt+h", "new()", .navigation),
                        row("alt+j", "down()"),
                    ]
                )
            ],
            into: &config
        )
        let rows = config.layers[0].bindings
        #expect(rows.count == 2)
        let updated = rows.first { $0.combo == "alt+h" }
        #expect(updated?.lua == "new()")
        #expect(updated?.kind == .navigation)
        #expect(rows.contains { $0.combo == "alt+j" })
    }

    @Test("A combo-less recovered row is ignored")
    func ignoresComboless() {
        var bindings = [row("alt+h", "keep()")]
        KeybindingMerge.upsert(row("", "noop()"), into: &bindings)
        #expect(bindings.count == 1)
        #expect(bindings[0].lua == "keep()")
    }

    @Test("An existing layer keeps its icon unless it had none")
    func iconFill() {
        var config = GuiConfig()
        config.layers = [
            layer("kept", [], icon: "📐"),
            layer("filled", []),
        ]
        KeybindingMerge.merge(
            recovered: [
                layer("kept", [], icon: "🆕"),
                layer("filled", [], icon: "🆕"),
            ],
            into: &config
        )
        #expect(config.layers[0].icon == "📐")
        #expect(config.layers[1].icon == "🆕")
    }
}

/// Minimal registrar so a `KeybindingManager` can accept binds in
/// the importer integration test.
@MainActor
private final class CapturingRegistrar: HotkeyRegistrar {
    private var next: UInt32 = 1
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { next += 1 }
        return next
    }
    func unregister(id: UInt32) {}
}

@Suite("KeybindingImporter integration", .serialized)
@MainActor
struct KeybindingImporterIntegrationTests {
    @Test("Recovers combos and bodies from a real file")
    func recoversFromFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("kiwi-import-\(UUID())")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let file = dir.appendingPathComponent("init.lua")
        try """
        KiwiDesk.grab("alt+h", function()
          KiwiDesk.focus("left")
        end)
        """.write(to: file, atomically: true, encoding: .utf8)

        let lua = try #require(LuaInterpreter())
        let manager = KeybindingManager(
            registrar: CapturingRegistrar()
        )
        // Mimic the real `KiwiDesk.bind`: capture the combo and
        // the function ref straight from the loaded file.
        lua.register("grab") { args in
            guard case .string(let comboText) = args.first,
                case .functionRef(let ref) = args.dropFirst().first,
                let combo = KeyCombo.parse(comboText)
            else { return .none }
            manager.bind(combo, ref: ref)
            return .none
        }
        try lua.runFile(file).get()

        let layers = KeybindingImporter.layers(
            from: manager,
            interpreter: lua,
            readFile: {
                try? String(contentsOfFile: $0, encoding: .utf8)
            }
        )
        let defaultLayer = try #require(
            layers.first { $0.name == KeyLayer.defaultName }
        )
        let row = try #require(defaultLayer.bindings.first)
        #expect(row.combo == "option+h")
        #expect(row.lua == "KiwiDesk.focus(\"left\")")
        #expect(row.kind == .custom)
    }
}
