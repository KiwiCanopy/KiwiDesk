import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A new Lua binding's two empty moments (#2688): its editor names
/// what it edits and shows what goes in the box, and the row Add
/// binding lands clear of the floating save pill. Source scans off
/// the main actor; the one title read is a pure call on it.
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
        #expect(editor.contains("HStack{actionsLinkSpacer()"))
        #expect(editor.contains("lineWidth:SettingsTheme.containerStroke"))
        #expect(
            editor.contains(
                "{placeholderText}.clipShape(RoundedRectangle("
            )
        )
        #expect(editor.contains(".strokeBorder(SettingsTheme.hairline,"))
        let row = try Self.source(
            "Components/Lua/AdvancedLuaGroup+Row.swift"
        )
        #expect(row.contains("title:Self.editorTitle(binding.wrappedValue),"))
        #expect(row.contains("placeholder:luaPlaceholder,"))
        let text = try Self.source("Components/Lua/LuaEditorTab.swift")
        #expect(text.contains("setAccessibilityPlaceholderValue(placeholder)"))
        #expect(
            text.contains(
                "iftakesFocus{DispatchQueue.main.async{"
                    + "textView.window?.makeFirstResponder(textView)}}"
            )
        )
        #expect(text.contains("textView.textContainerInset=inset"))
        #expect(editor.contains("takesFocus:true,inset:Self.textInset"))
    }

    /// The title names the binding, never by its first Lua line,
    /// which the editor draws right below it.
    @MainActor
    @Test("the editor title is the description or what the row is")
    func editorTitleNeverQuotesLua() {
        LocalizationManager.shared.select("en")
        var binding = KeyBinding(kind: .custom)
        #expect(AdvancedLuaGroup.editorTitle(binding) == "New binding")
        binding.lua = "KiwiDesk.reload_config()"
        #expect(AdvancedLuaGroup.editorTitle(binding) == "Lua binding")
        binding.desc = "Reload"
        #expect(AdvancedLuaGroup.editorTitle(binding) == "Reload")
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
            field.contains(
                "{startedNew?L(\"shortcuts.group.name_placeholder\""
            )
        )
    }

    /// The page ends with the pill's room while it floats, and Add
    /// binding scrolls to that end, gated.
    @Test("a new binding lands clear of the floating save pill")
    func newRowClearsThePill() throws {
        let page = try Self.source("Sections/ShortcutsSection.swift")
        #expect(
            page.contains(
                ".padding(.bottom,SettingsMetrics.pageBottom(width))"
            )
        )
        #expect(page.contains("Color.clear.frame(height:1).id(Self.pageEnd)"))
        #expect(page.contains("onAdd:{luaAdded+=1}"))
        #expect(
            page.contains(".onChange(of:luaAdded){_,_inscrollToEnd(proxy)}")
        )
        // Animated, gated, then re-issued once laid out.
        #expect(
            page.contains(
                ":.easeInOut(duration:SettingsReveal.scroll))"
                    + "{proxy.scrollTo(Self.pageEnd,anchor:.bottom)}"
            )
        )
        #expect(
            page.contains(
                "guard!Task.isCancelledelse{return}"
                    + "proxy.scrollTo(Self.pageEnd,anchor:.bottom)"
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
        // The pill's room while it floats, the gutter while docked.
        #expect(
            SettingsMetrics.pageBottom(.wide)
                == SettingsMetrics.savePillClearance
        )
        #expect(
            SettingsMetrics.pageBottom(.compact)
                == SettingsMetrics.paneInset
        )
    }
}
