import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The KiwiHub group renders FROM the census (#2265), split from
/// `ShortcutsCensusRenderTests` (§2.1): its one tier is the
/// census's, and the group draws its whole order list.
@Suite("KiwiHub render ↔ census parity")
struct KiwiHubCensusRenderTests {
    private func censusRows(
        _ container: SettingsContainer,
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .shortcuts
                    && $0.placement.container == container
                    && $0.placement.tier == tier
            }
        )
    }

    private func pin(
        _ rendered: [SettingKey],
        _ container: SettingsContainer,
        _ tier: SettingTier,
        _ what: Comment
    ) {
        #expect(Set(rendered) == censusRows(container, tier), what)
        #expect(rendered.count == Set(rendered).count, what)
    }

    @Test("KiwiHub's one tier is the census's (#2265)")
    func kiwiHubTier() {
        let keys = ShortcutsRowOrder.kiwiHubAtRest
        pin(keys, .kiwiHub, .atRest, "kiwihub at rest")
        #expect(keys.count == KiwiHubSide.allCases.count)
        #expect(censusRows(.kiwiHub, .showMore).isEmpty)
        #expect(censusRows(.kiwiHub, .immediate).isEmpty)
    }

    /// KiwiHub draws its WHOLE list, as the KiwiDesk rows do
    /// below: the `ForEach` takes `kiwiHubAtRest` as it stands,
    /// and the section mounts the group.
    @Test("KiwiHub draws every row")
    func kiwiHubRowsAreAllDrawn() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        func squeezed(_ file: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
        let group = try #require(
            SourceScan.declarationBody(
                after: "structKiwiHubGroup",
                in: try squeezed(
                    "Components/Keybindings/KiwiHubGroup.swift"
                )
            )
        )
        #expect(
            group.contains(
                "ForEach(ShortcutsRowOrder.kiwiHubAtRest,id:\\.id)"
            )
        )
        let section = try squeezed("Sections/ShortcutsSection.swift")
        #expect(section.occurrences(of: "KiwiHubGroup(") == 1)
    }
}
