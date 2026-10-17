import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A search opens a fold (#2312): a folded row stays whole only
/// where every member matches, and otherwise opens to the members
/// the query names, each with its own chord.
@Suite("Shortcuts overview fold search", .serialized)
@MainActor
struct ShortcutFoldSearchTests {
    private func sheet() -> ShortcutsSheet {
        let spaces = ["1", "2", "3"].map { SpaceID($0) }
        let bindings =
            KeybindingCatalog.goToSpace(spaces).enumerated().map {
                ("control+option+\($0.offset + 1)", $0.element.lua)
            }
            + KeybindingCatalog.moveToSpaceRows(spaces).enumerated().map {
                ("control+option+shift+\($0.offset + 1)", $0.element.lua)
            }
        return ShortcutsSheet(
            reference: ShortcutsReferenceBuilder.build(
                layer: KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: bindings.map {
                        KeyBinding(
                            combo: $0.0,
                            lua: $0.1,
                            kind: .navigation
                        )
                    }
                ),
                spaces: spaces,
                spaceIcons: [:],
                desktops: [],
                resizeStep: 50,
                layerNames: [KeyLayer.defaultName]
            )
        )
    }

    private func shown(_ query: String) -> [String]? {
        var sheet = sheet()
        sheet.setQuery(query)
        return sheet.shown?.controls.flatMap(\.rows).map(\.label)
    }

    @Test("a query naming one member opens the fold to it")
    func searchOpensTheFold() {
        LocalizationManager.shared.select("en")
        #expect(shown("space 3") == ["Go to Space 3", "Move to Space 3"])
        // The range's low end is in the fold's own label, and still
        // opens the fold like any other number.
        #expect(shown("space 1") == ["Go to Space 1", "Move to Space 1"])
    }

    @Test("a query every member matches keeps the fold whole")
    func searchKeepsTheFold() {
        LocalizationManager.shared.select("en")
        var sheet = sheet()
        sheet.setQuery("go to space")
        let rows = sheet.shown?.controls.flatMap(\.rows).map(\.label)
        #expect(rows == ["Go to Space 1–3"])
        #expect(sheet.matchCount == 1)
    }
}
