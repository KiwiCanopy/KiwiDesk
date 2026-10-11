import Foundation
import Testing

@testable import KiwiDesk

/// The Layout group mounts its two setting rows (#453, #2144):
/// `ShortcutsBespokeContainerTests` holds `layoutList`'s
/// membership and `SettingsCatalogSiteTests` the anchors, and both
/// stay green with a row's mount deleted — search would then land
/// on a row that is never drawn. Keyed on the mount inside
/// `LayoutGroup`'s body, never the file.
@Suite("Layout group mounts its rows")
struct LayoutGroupMountTests {
    @Test("LayoutGroup draws the cycle row and the plate switch")
    func rowsAreMounted() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "KeybindingGroups.swift"
            )
        let text = try SourceScan.strippedSource(at: url)
        let group = try #require(
            SourceScan.declarationBody(
                after: "struct LayoutGroup: View",
                in: text
            )
        )
        #expect(group.contains("LayoutCycleRow(model: model)"))
        #expect(group.contains("LayoutCueRow(model: model)"))
        #expect(group.contains("ShortcutsRowOrder.layoutAtRest"))
    }
}
