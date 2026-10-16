import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The shortcuts overview folds (#2312): a regular digit ladder
/// and a complete mirrored set become one row; anything the user
/// changed stands alone, and a search opens a fold to the members
/// it names.
@Suite("Shortcuts overview fold", .serialized)
@MainActor
struct ShortcutFoldTests {
    private let spaces = ["1", "2", "3", "4", "5"].map { SpaceID($0) }

    private func build(
        _ bindings: [(String, String)],
        icons: [SpaceID: String] = [:]
    ) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: bindings.map {
                    KeyBinding(combo: $0.0, lua: $0.1, kind: .navigation)
                }
            ),
            spaces: spaces,
            spaceIcons: icons,
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    private func goTo(_ n: Int, _ combo: String? = nil) -> (String, String) {
        (
            combo ?? "control+option+\(n)",
            KeybindingCatalog.goToSpace([SpaceID("\(n)")])[0].lua
        )
    }

    private func rows(_ reference: ShortcutsReference) -> [ShortcutRow] {
        reference.controls.flatMap(\.rows)
    }

    @Test("a regular ladder folds to one row, members kept")
    func ladderFolds() throws {
        LocalizationManager.shared.select("en")
        let row = try #require(rows(build((1...3).map { goTo($0) })).first)
        #expect(row.label == "Go to Space 1–3")
        #expect(row.spokenLabel == "Go to Space 1 to 3")
        #expect(row.combo == "⌃⌥1–3")
        #expect(
            row.members.map(\.label) == [
                "Go to Space 1", "Go to Space 2", "Go to Space 3",
            ]
        )
    }

    @Test("a rebound key or a named Space stands alone")
    func changedRowsStandAlone() {
        LocalizationManager.shared.select("en")
        let rebound = rows(
            build([
                goTo(1), goTo(2, "control+option+w"), goTo(3), goTo(4),
                goTo(5),
            ])
        )
        #expect(
            rebound.map(\.label) == [
                "Go to Space 1", "Go to Space 2", "Go to Space 3–5",
            ]
        )
        let named = rows(
            build((1...5).map { goTo($0) }, icons: [SpaceID("3"): "star"])
        )
        #expect(
            named.map(\.label) == [
                "Go to Space 1–2", "Go to Space 3", "Go to Space 4–5",
            ]
        )
    }

    @Test("a mirrored set folds only while every member is bound")
    func setsFoldWhole() {
        LocalizationManager.shared.select("en")
        let arrows = ["left", "down", "up", "right"]
        let all = KeybindingCatalog.focusDirections.enumerated().map {
            ("control+option+\(arrows[$0.offset])", $0.element.lua)
        }
        let whole = rows(build(all))
        #expect(whole.map(\.label) == ["Focus window left, down, up, right"])
        #expect(whole.first?.combo == "⌃⌥←↓↑→")
        #expect(rows(build(Array(all.dropLast()))).count == 3)
        let width = [
            (
                "option+command+2",
                KeybindingCatalog.resizeRow(.growWidth, step: 50).lua
            ),
            (
                "option+command+1",
                KeybindingCatalog.resizeRow(.shrinkWidth, step: 50).lua
            ),
        ]
        let resize = rows(build(width))
        #expect(resize.map(\.label) == ["Shrink / grow width"])
        #expect(resize.first?.combo == "⌥⌘12")
    }

    @Test("a search opens a fold to the members it names")
    func searchOpensTheFold() {
        LocalizationManager.shared.select("en")
        let moves = (1...3).map {
            (
                "control+option+shift+\($0)",
                KeybindingCatalog.moveToSpaceRows([SpaceID("\($0)")])[0].lua
            )
        }
        var sheet = ShortcutsSheet(
            reference: build((1...3).map { goTo($0) } + moves)
        )
        sheet.setQuery("space 3")
        let named = sheet.shown?.controls.flatMap(\.rows).map(\.label)
        #expect(named == ["Go to Space 3", "Move to Space 3"])
        sheet.setQuery("go to space")
        let folded = sheet.shown?.controls.flatMap(\.rows).map(\.label)
        #expect(folded == ["Go to Space 1–3"])
        #expect(sheet.matchCount == 1)
    }
}
