import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A binding's own fields win where it sets them (#2544 ▸ Ruling):
/// a binding KiwiHub recognises keeps its built-in name, group and
/// symbol for whatever it leaves empty; every built-in token files a
/// row into its own band; and the Shortcuts side's filter and counts
/// read the groups a binding made.
@Suite("A recognised binding's own fields win (#2544)", .serialized)
@MainActor
struct ShortcutRecognisedMetaTests {
    private static let left = "KiwiDesk.focus(\"left\")"

    private func reference(_ bindings: [KeyBinding]) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: KeyLayer.defaultName, bindings: bindings),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    private func focusRow(
        _ built: ShortcutsReference
    ) -> ShortcutRow? {
        built.controls.first { $0.group == .focus }?.rows
            .first { $0.id == Self.left }
    }

    @Test("Its description and symbol replace the built-in ones")
    func ownFieldsWin() throws {
        LocalizationManager.shared.select("en")
        let plain = try #require(
            focusRow(reference([KeyBinding(combo: "alt+h", lua: Self.left)]))
        )
        let own = try #require(
            focusRow(
                reference([
                    KeyBinding(
                        combo: "alt+h",
                        lua: Self.left,
                        desc: "West",
                        symbol: "star"
                    )
                ])
            )
        )
        #expect(own.label == "West" && own.icon == "star")
        let described = try #require(
            focusRow(
                reference([
                    KeyBinding(
                        combo: "alt+h",
                        lua: Self.left,
                        desc: "West",
                        symbol: "kiwidesk.no.such.symbol"
                    )
                ])
            )
        )
        #expect(described.label == "West")
        #expect(described.icon == plain.icon)
        #expect(plain.icon != LuaMark.symbol)
    }

    @Test("Its own group moves the row, keeping its name and symbol")
    func ownGroupMovesIt() throws {
        LocalizationManager.shared.select("en")
        let plain = try #require(
            focusRow(reference([KeyBinding(combo: "alt+h", lua: Self.left)]))
        )
        let built = reference([
            KeyBinding(combo: "alt+h", lua: Self.left, group: "Mine")
        ])
        #expect(focusRow(built) == nil)
        let mine = try #require(built.groups.first { $0.title == "Mine" })
        #expect(mine.rows.map(\.label) == [plain.label])
        #expect(mine.rows.map(\.icon) == [plain.icon])
        #expect(built.custom.isEmpty)
    }

    @Test("Every built-in token files a row into its own band")
    func everyTokenFiles() throws {
        for group in ShortcutGroup.allCases {
            let built = reference([
                KeyBinding(
                    combo: "alt+x",
                    lua: "mine()",
                    desc: "Token",
                    group: group.rawValue
                )
            ])
            let rows =
                group == .apps
                ? built.apps
                : built.controls.first { $0.group == group }?.rows ?? []
            #expect(rows.map(\.label) == ["Token"], "\(group)")
            #expect(built.custom.isEmpty && built.groups.isEmpty)
        }
    }

    @Test("The filter, the count and emptiness read the own groups")
    func sheetReadsOwnGroups() throws {
        let built = reference([
            KeyBinding(combo: "alt+a", lua: "a()", desc: "Alpha", group: "G"),
            KeyBinding(combo: "alt+b", lua: "b()", desc: "Beta", group: "G"),
        ])
        #expect(!built.isEmpty)
        var sheet = ShortcutsSheet(reference: built)
        sheet.setQuery("Alpha")
        let shown = try #require(sheet.shown)
        #expect(shown.groups.flatMap(\.rows).map(\.label) == ["Alpha"])
        #expect(sheet.matchCount == 1)
        sheet.setQuery("Nothing at all")
        #expect(sheet.shown?.groups.isEmpty == true)
        #expect(sheet.matchCount == 0)
    }
}
