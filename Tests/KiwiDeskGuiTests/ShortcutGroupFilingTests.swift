import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Where KiwiHub lists a binding of the user's own (#2544 ▸ Ruling):
/// a built-in group's token files it into that group, any other name
/// into a group of its own after the built-in ones and before Custom,
/// none into Custom; it reads under its description, wearing its
/// symbol where that is an SF Symbol and `</>` otherwise.
@Suite("KiwiHub files a shortcut by its group (#2544)")
@MainActor
struct ShortcutGroupFilingTests {
    private func reference(
        _ bindings: [KeyBinding],
        unread: [UnreadChord] = []
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: KeyLayer.defaultName, bindings: bindings),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName],
            unread: unread
        )
    }

    private func own(
        _ combo: String,
        desc: String = "",
        group: String = "",
        symbol: String = ""
    ) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: "my_\(combo.filter(\.isLetter))()",
            desc: desc,
            group: group,
            symbol: symbol
        )
    }

    @Test("A built-in token files the row into its group")
    func tokenFilesIntoTheBand() throws {
        let built = reference([own("alt+h", desc: "Mine", group: "layout")])
        let layout = try #require(built.controls.first { $0.group == .layout })
        #expect(layout.rows.map(\.label) == ["Mine"])
        #expect(built.custom.isEmpty)
        let apps = reference([own("alt+a", desc: "App", group: "apps")])
        #expect(apps.apps.map(\.label) == ["App"])
    }

    @Test("Any other name makes a group, in first-named order")
    func ownGroupsInOrder() {
        let built = reference([
            own("alt+b", desc: "One", group: "Beta"),
            own("alt+a", desc: "Two", group: "Alpha"),
            own("alt+c", desc: "Three", group: "Beta"),
        ])
        #expect(built.groups.map(\.title) == ["Beta", "Alpha"])
        #expect(built.groups.first?.rows.map(\.label) == ["One", "Three"])
        #expect(built.custom.isEmpty)
    }

    @Test("No group lists it under Custom, as its Lua without a desc")
    func noGroupIsCustom() throws {
        let built = reference([own("alt+x"), own("alt+y", desc: "Why")])
        #expect(built.custom.count == 2)
        let raw = try #require(
            built.custom.first { $0.label.hasPrefix("my_") }
        )
        #expect(raw.monospaced)
        let described = try #require(built.custom.first { $0.label == "Why" })
        #expect(!described.monospaced)
    }

    @Test("A real symbol is worn; none or an unknown name wears </>")
    func symbolOrLuaMark() throws {
        let built = reference([
            own("alt+s", desc: "Star", symbol: "star"),
            own("alt+n", desc: "None"),
            own("alt+u", desc: "Unknown", symbol: "kiwidesk.no.such"),
        ])
        func icon(_ label: String) -> String? {
            built.custom.first { $0.label == label }?.icon
        }
        #expect(icon("Star") == "star")
        #expect(icon("None") == LuaMark.symbol)
        #expect(icon("Unknown") == LuaMark.symbol)
        #expect(
            LuaMark.symbol
                == "chevron.left.forwardslash.chevron.right"
        )
    }

    @Test("An unread chord takes its description, group and symbol")
    func unreadRowsTakeTheirMeta() throws {
        let built = reference(
            [],
            unread: [
                UnreadChord(
                    chord: "option+f",
                    meta: KeyBindingMeta(
                        desc: "Follow",
                        group: "Mine",
                        symbol: "star"
                    )
                ),
                UnreadChord(chord: "option+g"),
            ]
        )
        let mine = try #require(built.groups.first { $0.title == "Mine" })
        #expect(mine.rows.map(\.label) == ["Follow"])
        #expect(mine.rows.first?.icon == "star")
        let generic = try #require(built.custom.first)
        #expect(generic.icon == LuaMark.symbol)
    }

    @Test("The panel lists a binding's own groups after Apps, before Custom")
    func sectionsInOrder() {
        let built = reference([
            own("alt+a", desc: "App", group: "apps"),
            own("alt+b", desc: "Own", group: "Mine"),
            own("alt+c", desc: "Loose"),
        ])
        let titles = ShortcutsSheetView(reference: built, needle: "").sections(
            built
        )
        .map(\.title)
        let apps = titles.firstIndex(of: L("shortcuts.panel.apps", "Apps"))
        let mine = titles.firstIndex(of: "Mine")
        let custom = titles.firstIndex(
            of: L("shortcuts.panel.custom", "Custom")
        )
        #expect(apps != nil && mine != nil && custom != nil)
        if let apps, let mine, let custom {
            #expect(apps < mine && mine < custom)
        }
    }
}
