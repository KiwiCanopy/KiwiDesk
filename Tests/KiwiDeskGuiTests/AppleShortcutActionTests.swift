import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An Apple Shortcut row is derived from its Lua (#3526), as an app
/// row is: the call the pickers write, and the name read back.
@Suite("Apple Shortcut action")
@MainActor
struct AppleShortcutActionTests {
    @Test("a name round-trips through the Lua it writes")
    func roundTrips() {
        for name in [
            "Start Meeting", "say \"hi\"", "back\\slash", "two\nlines",
            "Ünïcode ☕️",
        ] {
            let lua = AppleShortcutAction.command(name)
            #expect(AppleShortcutAction.name(from: lua) == name)
        }
    }

    @Test("the Lua it writes is the verb's exact call")
    func writesTheVerb() {
        #expect(
            AppleShortcutAction.command("a\"b")
                == "KiwiDesk.run_shortcut(\"a\\\"b\")"
        )
    }

    @Test("Lua it never writes reads as no shortcut")
    func foreignLuaIsNone() {
        for lua in [
            "KiwiDesk.run_shortcut(\"\")",
            "KiwiDesk.run_shortcut(\"a\" .. b)",
            "KiwiDesk.run_shortcut(\"a\\q\")",
            "KiwiDesk.focus_or_spawn(\"com.apple.notes\")",
            "KiwiDesk.run_shortcut(x)",
        ] {
            #expect(AppleShortcutAction.name(from: lua) == nil)
        }
    }

    @Test("a row is an application row the Apps group lists")
    func bindingShape() {
        let binding = AppleShortcutAction.binding("Focus", combo: "alt+f")
        #expect(binding.kind == .application)
        #expect(binding.label == "Focus")
        #expect(binding.combo == "alt+f")
        #expect(KeybindingCatalog.appBundleID(from: binding.lua) == nil)
        let action = AppleShortcutAction.action("Focus")
        #expect(action.kind == .application)
        #expect(action.meta.desc == "Focus")
    }

    @Test("KiwiHub gives the row the Shortcut glyph")
    func hubGlyph() {
        let lua = AppleShortcutAction.command("Focus")
        #expect(
            ShortcutsReferenceBuilder.verbIcon(for: lua)
                == AppleShortcutAction.symbol
        )
        var binding = AppleShortcutAction.binding("Focus", combo: "alt+f")
        binding.id = UUID()
        let row = ShortcutsReferenceBuilder.shortcutRow(binding)
        #expect(row?.label == "Focus")
        #expect(row?.icon == .symbol(AppleShortcutAction.symbol))
        #expect(row?.bundleID == nil)
    }

    @Test("a row is missing only once a read lacks its name")
    func missingNeedsARead() {
        let library = AppleShortcutLibrary()
        #expect(!library.isMissing("Gone"))
        library.setNamesForTesting(["Here"])
        #expect(library.isMissing("Gone"))
        #expect(!library.isMissing("Here"))
    }
}
