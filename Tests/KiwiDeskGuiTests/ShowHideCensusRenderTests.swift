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

    /// Each needle once, and in order.
    private func expectInOrder(
        _ needles: [String],
        in text: String,
        _ what: String
    ) {
        var cursor = text.startIndex
        for needle in needles {
            #expect(text.occurrences(of: needle) == 1, "\(what): \(needle)")
            guard
                let hit = text.range(
                    of: needle,
                    range: cursor..<text.endIndex
                )
            else {
                Issue.record("\(what): \(needle) out of order")
                return
            }
            cursor = hit.upperBound
        }
    }

    /// Each rows view draws its product's heading, anchors that
    /// product's search hit on it, then walks its WHOLE list.
    @Test("each sub-group draws its heading and every row")
    func rowsAreAllDrawn() throws {
        for (rows, control, follows, list) in [
            ("KiwiHubKeyRows", "kiwiHubKeys", "", "kiwiHubAtRest"),
            (
                "KiwiShelfKeyRows", "kiwishelfKeys",
                ",followsGroup:true", "kiwishelfAtRest"
            ),
            (
                "KiwiVisionKeyRows", "kiwiVisionKeys",
                ",followsGroup:true", "kiwiVisionAtRest"
            ),
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
            let catalog = "SettingsCatalog.shortcuts.\(control)"
            expectInOrder(
                [
                    "SettingsGroupHeading(title:\(catalog).text"
                        + "\(follows))",
                    ".searchAnchored(\(catalog))",
                    "ForEach(ShortcutsRowOrder.\(list),id:\\.id)",
                ],
                in: body,
                rows
            )
        }
    }

    /// One card, mounted once, its sub-groups in the ruled order:
    /// KiwiHub, KiwiShelf, then KiwiVision, which grows a row per
    /// lens and so goes last. Which product a key sits under is
    /// held by the three lists alone — the tier test pins their
    /// union — the residue Open applications ▸ KiwiDesk shares.
    @Test("the card mounts its sub-groups in order")
    func subGroupsInOrder() throws {
        let card = try #require(
            SourceScan.declarationBody(
                after: "structShowHideGroup",
                in: try squeezed(
                    "Components/Keybindings/ShowHideGroup.swift"
                )
            )
        )
        expectInOrder(
            [
                "SettingsSection(SettingsCatalog.shortcuts.showHideKeys)",
                "KiwiHubKeyRows(",
                "KiwiShelfKeyRows(",
                "KiwiVisionKeyRows(",
            ],
            in: card,
            "ShowHideGroup"
        )
        let section = try squeezed("Sections/ShortcutsSection.swift")
        #expect(section.occurrences(of: "ShowHideGroup(") == 1)
    }
}
