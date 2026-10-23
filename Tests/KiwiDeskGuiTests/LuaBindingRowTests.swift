import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A Lua binding's Settings row (#2544 ▸ Ruling): its Description,
/// symbol and shortcut group write the binding, a body of more than
/// one line reads as a readout rather than a field, the editor writes
/// the draft as it is typed, and the symbol picker offers symbols
/// alone. Source scans, off the main actor.
@Suite("Lua binding row")
struct LuaBindingRowTests {
    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    @Test("one line edits in place; more lines read as their first")
    func bodyShape() {
        #expect(!LuaBodyShape.isMultiline("KiwiDesk.reload_config()\n"))
        let body = "local s = KiwiDesk.get_state()\nKiwiDesk.focus(s)\n"
        #expect(LuaBodyShape.isMultiline(body))
        #expect(
            LuaBodyShape.firstLine(body) == "local s = KiwiDesk.get_state()"
        )
        #expect(LuaBodyShape.lineCount(body) == 2)
        #expect(LuaBodyShape.lineCount("a\n\nb") == 3)
    }

    /// The editor's body reaches its own row by id, wherever the row
    /// has moved since the editor opened.
    @Test("the editor's binding writes its own row by id")
    @MainActor
    func luaBindingWritesItsRow() {
        var rows = [
            KeyBinding(lua: "one"), KeyBinding(lua: "two"),
            KeyBinding(lua: "three"),
        ]
        let array = Binding(get: { rows }, set: { rows = $0 })
        let second = rows[1].id
        let body = AdvancedLuaGroup.luaBinding(second, in: array)
        #expect(body.wrappedValue == "two")
        rows.swapAt(1, 2)
        body.wrappedValue = "edited"
        #expect(rows.map(\.lua) == ["one", "three", "edited"])
        rows.removeAll { $0.id == second }
        body.wrappedValue = "gone"
        #expect(rows.map(\.lua) == ["one", "three"])
    }

    @Test("the fields write the binding's own description, symbol, group")
    func fieldsWriteTheBinding() throws {
        let row = try Self.source("Lua/AdvancedLuaGroup+Row.swift")
        #expect(row.contains("text:binding.desc)"))
        #expect(
            row.contains(
                "IconPicker(icon:binding.symbol,preview:.chip,"
                    + "symbolsOnly:true,placeholder:LuaMark.symbol)"
            )
        )
        #expect(row.contains("ShortcutGroupField(group:binding.group,"))
        // The picker speaks the symbol it shows (gui.md, #812).
        #expect(
            row.contains(
                ".accessibilityValue(binding.wrappedValue.symbol.isEmpty"
                    + "?L(\"shortcuts.lua.default_symbol\",\"</>\")"
                    + ":binding.wrappedValue.symbol)"
            )
        )
        let group = try Self.source("Lua/AdvancedLuaGroup.swift")
        #expect(group.contains("row($binding)"))
    }

    /// A field that ignores typing is never drawn: a multi-line body
    /// is a button opening the editor, a one-line body a field.
    @Test("a multi-line body is a readout, never a field")
    func multilineIsAReadout() throws {
        let row = try Self.source("Lua/AdvancedLuaGroup+Row.swift")
        #expect(
            row.contains(
                "ifLuaBodyShape.isMultiline(lua){Button{"
                    + "editing=LuaEditRequest(id:id)}"
            )
        )
        #expect(
            row.contains("}else{TextField(luaPlaceholder,text:binding.lua)")
        )
        #expect(row.contains(".popover(item:editBinding(id))"))
    }

    /// One binding to VoiceOver, named as KiwiHub names it.
    @Test("the row speaks as one binding, by its name")
    func rowSpeaksByName() throws {
        let row = try Self.source("Lua/AdvancedLuaGroup+Row.swift")
        #expect(
            row.contains(
                ".accessibilityElement(children:.contain)"
                    + ".accessibilityLabel(name)"
            )
        )
        #expect(row.contains("set:{if$0!=nil||editing?.id==id{"))
        #expect(row.contains("KeyRecorderField(name:name,"))
        #expect(row.contains("rowName:name)"))
    }

    /// The body is the draft's from the first keystroke, so a click
    /// away keeps it and no write can land after a Save or a Revert;
    /// only Cancel puts the opening body back.
    @Test("the editor writes as typed, Cancel restores")
    func editorWritesLive() throws {
        let editor = try Self.source("Lua/LuaBindingEditor.swift")
        #expect(editor.contains("LuaSourceEditor(text:typed,"))
        #expect(editor.contains("set:{written=$0text=$0}"))
        #expect(!editor.contains("onDisappear"))
        #expect(
            editor.contains(
                "privatefunccancel(){iftext==written{text=seed}dismiss()}"
            )
        )
        let row = try Self.source("Lua/AdvancedLuaGroup+Row.swift")
        #expect(row.contains("text:luaBinding(id),"))
    }

    /// A shortcut's symbol is an SF Symbol name, so nothing else is
    /// offered (`docs/design-decisions.md` ▸ the icon picker).
    @Test("the symbol picker offers symbols alone")
    func symbolsOnly() throws {
        let picker = try Self.source("Icons/IconPicker.swift")
        #expect(picker.contains("ifsearch.trimmed.isEmpty&&symbolsOnly{"))
        #expect(picker.contains("if!symbolsOnly{gridSection("))
        #expect(picker.contains("ifquery.count==1,!symbolsOnly{"))
        #expect(
            picker.contains(".filter{!symbolsOnly||isSymbolName($0)}")
        )
        #expect(
            picker.contains(
                "choices:symbolsOnly?IconCatalog.symbols:tab.choices"
            )
        )
    }
}
