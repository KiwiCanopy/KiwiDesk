import Foundation
import Testing

@testable import KiwiDesk

/// A new Lua binding's two empty moments (#2688): its editor names
/// what it edits and shows what goes in the box, and the row Add
/// binding lands lands clear of the floating save pill. Source
/// scans, off the main actor.
@Suite("Lua binding empty state")
struct LuaBindingEmptyStateTests {
    private static func source(_ path: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/\(path)"
                    ),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    /// Title always drawn, never the first Lua line; placeholder
    /// drawn only while empty and never written; the actions page
    /// through the drawer link's own door.
    @Test("the editor names its binding and shows a placeholder")
    func editorEmptyState() throws {
        let editor = try Self.source(
            "Components/Lua/LuaBindingEditor.swift"
        )
        #expect(
            editor.contains(
                "VStack(alignment:.leading,spacing:8){Text(title)"
            )
        )
        #expect(!editor.contains("if!title.isEmpty"))
        #expect(
            editor.contains(".overlay(alignment:.topLeading){placeholderText}")
        )
        #expect(editor.contains("iftext.isEmpty{Text(placeholder)"))
        #expect(editor.contains("placeholder:placeholder,takesFocus:true"))
        #expect(editor.contains("Button(action:ActionsListLink.open)"))
        #expect(
            editor.contains(
                "{placeholderText}.clipShape(RoundedRectangle("
            )
        )
        #expect(editor.contains(".strokeBorder(SettingsTheme.hairline,"))
        let row = try Self.source(
            "Components/Lua/AdvancedLuaGroup+Row.swift"
        )
        #expect(row.contains("title:editorTitle(binding.wrappedValue),"))
        #expect(row.contains("placeholder:luaPlaceholder,"))
        let title =
            row.components(separatedBy: "funceditorTitle(")
            .dropFirst().first?
            .components(separatedBy: "privatefunc").first ?? ""
        #expect(title.contains("ifbinding.lua.isEmpty{"))
        #expect(!title.contains("firstLine"))
        let text = try Self.source("Components/Lua/LuaEditorTab.swift")
        #expect(text.contains("setAccessibilityPlaceholderValue(placeholder)"))
        #expect(text.contains("iftakesFocus{"))
        #expect(text.contains("textView.textContainerInset=inset"))
        #expect(editor.contains("takesFocus:true,inset:Self.textInset"))
    }

    /// A group being named reads as a name to type, never as
    /// Custom, which picks no group.
    @Test("a new shortcut group's empty field does not read Custom")
    func newGroupPlaceholder() throws {
        let field = try Self.source(
            "Components/Lua/ShortcutGroupField.swift"
        )
        #expect(field.contains("TextField(placeholder,text:$text)"))
        #expect(
            field.contains("startedNew?L(\"shortcuts.group.name_placeholder\"")
        )
    }

    /// The page ends with the pill's room while it floats, and Add
    /// binding scrolls to that end, gated.
    @Test("a new binding lands clear of the floating save pill")
    func newRowClearsThePill() throws {
        let page = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            page.contains(
                "width.docksSavePill?SettingsMetrics.paneInset"
                    + ":SettingsMetrics.savePillClearance"
            )
        )
        #expect(page.contains("Color.clear.frame(height:1).id(Self.pageEnd)"))
        #expect(page.contains("onAdd:{luaAdded+=1}"))
        #expect(
            page.contains(
                ".onChange(of:luaAdded)"
            )
        )
        #expect(
            page.contains(
                "withAnimation(reduceMotion?nil:.default){"
                    + "proxy.scrollTo(Self.pageEnd,anchor:.bottom)}"
            )
        )
        let group = try Self.source(
            "Components/Lua/AdvancedLuaGroup.swift"
        )
        #expect(
            group.contains(
                "bindings.append(KeyBinding(kind:.custom))onAdd()"
            )
        )
        let chrome = try Self.source("SettingsView+Chrome.swift")
        #expect(
            chrome.contains(
                "SettingsFooter(model:model).padding(.bottom,"
                    + "SettingsMetrics.savePillLift)"
            )
        )
        #expect(
            SettingsMetrics.savePillClearance
                > SettingsMetrics.savePillLift + 40
        )
    }
}
