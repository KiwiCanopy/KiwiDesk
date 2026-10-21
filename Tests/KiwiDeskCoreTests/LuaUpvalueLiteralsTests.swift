import Foundation
import Testing

@testable import KiwiDeskCore

/// A binding body's scalar upvalues read as literals, all or
/// nothing (#2485).
@Suite("LuaUpvalueLiterals")
struct LuaUpvalueLiteralsTests {
    private let loop = """
        for i = 1, 9 do
          KiwiDesk.bind("ctrl+alt+" .. i, function()
            KiwiDesk.focus_space(i)
          end)
        end
        """

    private func resolve(
        _ body: String,
        _ upvalues: [String: LuaValue?],
        file: String? = nil
    ) -> String {
        LuaUpvalueLiterals.resolve(
            body: body,
            upvalues: upvalues,
            file: file ?? loop
        )
    }

    @Test("A loop variable reads as its value")
    func loopVariable() {
        #expect(
            resolve(
                "KiwiDesk.focus_space(i)",
                ["i": .number(3), "_ENV": nil]
            ) == "KiwiDesk.focus_space(3)"
        )
    }

    @Test("Strings are quoted and escaped, booleans and floats spelled")
    func scalarSpellings() {
        #expect(
            resolve("KiwiDesk.focus(dir)", ["dir": .string("left")])
                == "KiwiDesk.focus(\"left\")"
        )
        #expect(
            resolve("f(s)", ["s": .string("a\"b\\\n\u{1}")])
                == "f(\"a\\\"b\\\\\\n\\001\")"
        )
        #expect(resolve("f(b)", ["b": .bool(true)]) == "f(true)")
        #expect(resolve("f(x)", ["x": .number(0.5)]) == "f(0.5)")
    }

    @Test("A non-scalar or non-finite upvalue keeps the raw body")
    func nonScalarKeepsRaw() {
        let raw = "helper(i)"
        let upvalues: [String: LuaValue?] = [
            "helper": nil, "i": .number(3),
        ]
        #expect(resolve(raw, upvalues) == raw)
        #expect(resolve("f(n)", ["n": .number(.nan)]) == "f(n)")
    }

    @Test("Fields, strings, comments and labels are left alone")
    func onlyVariableReads() {
        #expect(
            resolve(
                "t.i(i, \"i\") -- i\nobj:i()",
                ["i": .number(3)]
            ) == "t.i(3, \"i\") -- i\nobj:i()"
        )
    }

    @Test("A literal that would fuse with its neighbour is wrapped")
    func adjoiningLiteralsWrap() {
        #expect(resolve("f(i..x)", ["i": .number(3)]) == "f((3)..x)")
        #expect(
            resolve("s:upper()", ["s": .string("a")])
                == "(\"a\"):upper()"
        )
        #expect(resolve("f(x-i)", ["i": .number(-1)]) == "f(x-(-1))")
        #expect(resolve("f(i)", ["i": .number(-1)]) == "f(-1)")
    }

    @Test("A name the body declares keeps the raw body")
    func bodyDeclarationKeepsRaw() {
        for body in [
            "local i = 5 KiwiDesk.focus_space(i)",
            "for i = 1, 2 do f(i) end",
            "g(function(a, i) return i end)",
        ] {
            #expect(resolve(body, ["i": .number(3)]) == body)
        }
    }

    @Test("A name the file assigns anywhere keeps the raw body")
    func fileAssignmentKeepsRaw() {
        let body = "KiwiDesk.focus(mode)"
        let upvalues: [String: LuaValue?] = ["mode": .string("left")]
        for file in [
            "local mode = \"left\"\nmode = \"right\"",
            "local mode = 1\nlocal a\na, mode = 1, 2",
            "local mode\nfunction mode() end",
            "local mode = 1 f(x) mode = 2",
            "local mode <const> = 1\nt[k] = 2 mode = 3",
        ] {
            #expect(resolve(body, upvalues, file: file) == body)
        }
    }

    @Test("Declarations, keys and field writes are not assignments")
    func notAssignments() {
        let body = "KiwiDesk.focus(mode)"
        let upvalues: [String: LuaValue?] = ["mode": .string("up")]
        for file in [
            "local mode <const> = \"up\"",
            "local a, mode = 1, \"up\"",
            "for mode = 1, 2 do end",
            "local t = { a = 1, mode = 2, [k] = 3, f(), mode = 4 }",
            "t.mode = 1 t[mode] = 2 x = mode == 3",
            "local function mode() end",
        ] {
            #expect(
                resolve(body, upvalues, file: file)
                    == "KiwiDesk.focus(\"up\")",
                "file: \(file)"
            )
        }
    }
}

/// A Space call reads as the catalog spells it, so a loop's
/// bare number matches its Space row (#2485).
@Suite("SpaceLuaArg catalog spelling")
struct SpaceCatalogSpellingTests {
    @Test("A bare-number Space call is quoted, anything else kept")
    func quotesTheSpace() {
        #expect(
            SpaceLuaArg.catalogSpelling(of: "KiwiDesk.focus_space(3)")
                == "KiwiDesk.focus_space(\"3\")"
        )
        #expect(
            SpaceLuaArg.catalogSpelling(
                of: "KiwiDesk.move_to_space(12)"
            ) == "KiwiDesk.move_to_space(\"12\")"
        )
        for kept in [
            "KiwiDesk.focus_space(\"web\")",
            "KiwiDesk.focus(\"left\")",
            "KiwiDesk.focus_space(i)",
        ] {
            #expect(SpaceLuaArg.catalogSpelling(of: kept) == kept)
        }
    }
}

/// The importer resolves upvalues read from a real interpreter
/// (#2485): a loop-built binding by value, a shared mutable one
/// raw.
@Suite("LuaUpvalueLiterals capture", .serialized)
@MainActor
struct LuaUpvalueCaptureTests {
    @Test("Loop-built bindings read by value, mutable state stays raw")
    func capturesByValue() throws {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("kiwi-upvalue-\(UUID())")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        let file = dir.appendingPathComponent("init.lua")
        try """
        for i = 1, 3 do
          KiwiDesk.grab("ctrl+alt+" .. i, function()
            KiwiDesk.focus_space(i)
          end)
        end
        local dir = "left"
        KiwiDesk.grab("alt+h", function() KiwiDesk.focus(dir) end)
        dir = "right"
        """.write(to: file, atomically: true, encoding: .utf8)

        let lua = try #require(LuaInterpreter())
        let manager = KeybindingManager(registrar: SilentRegistrar())
        lua.register("grab") { args in
            guard case .string(let comboText) = args.first,
                case .functionRef(let ref) = args.dropFirst().first,
                let combo = KeyCombo.parse(comboText)
            else { return .none }
            manager.bind(combo, ref: ref)
            return .none
        }
        try lua.runFile(file).get()

        let rows = KeybindingImporter.layers(
            from: manager,
            interpreter: lua,
            readFile: KeybindingImporter.readSource
        ).flatMap(\.bindings).map(\.lua).sorted()
        #expect(
            rows == [
                "KiwiDesk.focus(dir)",
                "KiwiDesk.focus_space(\"1\")",
                "KiwiDesk.focus_space(\"2\")",
                "KiwiDesk.focus_space(\"3\")",
            ]
        )
    }
}

@MainActor
private final class SilentRegistrar: HotkeyRegistrar {
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
