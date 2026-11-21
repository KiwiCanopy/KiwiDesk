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
        // A raw newline inside a Lua string is a syntax error.
        #expect(
            AppleShortcutAction.command("a\nb")
                == "KiwiDesk.run_shortcut(\"a\\nb\")"
        )
    }

    @Test("Lua it never writes reads as no shortcut")
    func foreignLuaIsNone() {
        for lua in [
            "KiwiDesk.run_shortcut(\"\")",
            "KiwiDesk.run_shortcut(\"a\" .. b)",
            "KiwiDesk.run_shortcut(\"a\" .. \"b\")",
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

    @Test("KiwiHub files a shortcut key with the user's own, not Apps")
    func hubFilesTheKey() {
        var binding = AppleShortcutAction.binding("Focus", combo: "alt+f")
        binding.id = UUID()
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [binding]
            ),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: [1],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        let id = binding.id.uuidString
        #expect(!reference.apps.contains { $0.id == id })
        let own =
            (reference.groups + reference.controls)
            .flatMap(\.rows) + reference.custom
        let row = own.first { $0.id == id }
        #expect(row?.label == "Focus")
        #expect(row?.icon == .symbol(AppleShortcutAction.symbol))
    }

    @Test("a shortcut row lands on its own card")
    func ownerIsTheCard() {
        var binding = AppleShortcutAction.binding("Focus", combo: "alt+f")
        binding.id = UUID()
        let part = ShortcutsPagePart.owner(
            of: binding.id.uuidString,
            expander: ShortcutsFamilyRows.ofDraft(
                makeTestModel(),
                layer: KeyLayer.defaultName
            ),
            bindings: [binding]
        )
        #expect(part == .appleShortcuts)
    }

    @Test("a shortcut row is no app row, and an app row no shortcut")
    func rowPredicates() {
        let shortcut = AppleShortcutAction.binding("Focus")
        let app = KeyBinding(
            combo: "",
            lua: KeybindingCatalog.appCommand("com.apple.safari"),
            kind: .application,
            label: "Safari"
        )
        #expect(AppleShortcutAction.isRow(shortcut))
        #expect(!AppleShortcutAction.isAppRow(shortcut))
        #expect(AppleShortcutAction.isAppRow(app))
        #expect(!AppleShortcutAction.isRow(app))
    }

    @Test("the library mirrors Core's list once attached")
    func libraryMirrorsCore() {
        let core = makeTestCore()
        let library = AppleShortcutLibrary()
        library.attach(core)
        core.appleShortcuts.onNamesChanged(["B", "A"])
        #expect(library.names == ["B", "A"])
    }

    @Test("a hand-written run_shortcut row is filed as a shortcut")
    func classifierFilesTheRow() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+m",
                        lua: AppleShortcutAction.command("Start"),
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .application)
        #expect(row.label == "Start")
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
