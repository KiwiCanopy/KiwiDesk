import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Show & hide card renders FROM the census, split from
/// `ShortcutsCensusRenderTests` (§2.1): its one tier is the union
/// of its three sub-group lists, and the card draws each list
/// whole, under its heading, in the ruled order.
@Suite("Show & hide render ↔ census parity")
struct ShowHideCensusRenderTests {
    private func censusRows(_ tier: SettingTier) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .shortcuts
                    && $0.placement.container == .showHide
                    && $0.placement.tier == tier
            }
        )
    }

    /// The sub-group lists, in drawing order.
    private var lists: [[SettingKey]] {
        [
            ShortcutsRowOrder.kiwiHubAtRest,
            ShortcutsRowOrder.kiwishelfAtRest,
            ShortcutsRowOrder.kiwiVisionAtRest,
        ]
    }

    @Test("the card's one tier is its three lists, each key once")
    func showHideTier() {
        let all = lists.flatMap { $0 }
        #expect(Set(all) == censusRows(.atRest))
        #expect(all.count == Set(all).count)
        #expect(lists.allSatisfy { !$0.isEmpty })
        #expect(
            ShortcutsRowOrder.kiwiHubAtRest.count
                == KiwiHubSide.allCases.count
        )
        #expect(censusRows(.showMore).isEmpty)
        #expect(censusRows(.immediate).isEmpty)
    }

    private func squeezed(_ file: String) throws -> String {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        return SourceScan.stripComments(
            try String(
                contentsOf: root.appendingPathComponent(file),
                encoding: .utf8
            )
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
    }

    /// Each rows view walks its WHOLE list as it stands.
    @Test("each sub-group draws every row")
    func rowsAreAllDrawn() throws {
        for (rows, list) in [
            ("KiwiHubKeyRows", "kiwiHubAtRest"),
            ("KiwiShelfKeyRows", "kiwishelfAtRest"),
            ("KiwiVisionKeyRows", "kiwiVisionAtRest"),
        ] {
            let body = try #require(
                SourceScan.declarationBody(
                    after: "struct\(rows)",
                    in: try squeezed(
                        "Components/Keybindings/\(rows).swift"
                    )
                ),
                "\(rows)"
            )
            #expect(
                body.contains("ForEach(ShortcutsRowOrder.\(list),id:\\.id)"),
                "\(rows)"
            )
        }
    }

    /// One card, mounted once, each sub-group under its own
    /// heading in the ruled order: KiwiHub, KiwiShelf, then
    /// KiwiVision, which grows a row per lens and so goes last.
    @Test("the card mounts its sub-groups in order, under headings")
    func subGroupsInOrder() throws {
        let card = try #require(
            SourceScan.declarationBody(
                after: "structShowHideGroup",
                in: try squeezed(
                    "Components/Keybindings/ShowHideGroup.swift"
                )
            )
        )
        let needles = [
            "SettingsSection(SettingsCatalog.shortcuts.showHideKeys)",
            "heading(SettingsCatalog.shortcuts.kiwiHubKeys)",
            ".searchAnchored(SettingsCatalog.shortcuts.kiwiHubKeys)",
            "KiwiHubKeyRows(",
            "heading(SettingsCatalog.shortcuts.kiwishelfKeys,follows:true)",
            ".searchAnchored(SettingsCatalog.shortcuts.kiwishelfKeys)",
            "KiwiShelfKeyRows(",
            "heading(SettingsCatalog.shortcuts.kiwiVisionKeys,follows:true)",
            ".searchAnchored(SettingsCatalog.shortcuts.kiwiVisionKeys)",
            "KiwiVisionKeyRows(",
        ]
        var cursor = card.startIndex
        for needle in needles {
            #expect(card.occurrences(of: needle) == 1, "\(needle)")
            guard
                let hit = card.range(
                    of: needle,
                    range: cursor..<card.endIndex
                )
            else {
                Issue.record("\(needle) out of order")
                return
            }
            cursor = hit.upperBound
        }
        let section = try squeezed("Sections/ShortcutsSection.swift")
        #expect(section.occurrences(of: "ShowHideGroup(") == 1)
    }
}
