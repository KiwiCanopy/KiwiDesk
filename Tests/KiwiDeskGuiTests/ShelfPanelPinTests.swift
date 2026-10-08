import Foundation
import Testing

/// **Both test cores pin the shelf panel off** (#1894): the Core
/// twin's pin is counted by `ShelfPanelInertTests`, which cannot
/// reach this target's twin, so the pin is held here for both.
@Suite("Shelf panel pin (#1894)")
struct ShelfPanelPinTests {
    @Test("both twins turn shelf panels off")
    func twinsPinPanelsOff() throws {
        let repo = SourceScan.repoRoot(from: #filePath)
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: repo.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                )
            )
            #expect(
                source.components(
                    separatedBy: "core.shelves.drawsPanels = false"
                ).count == 2,
                .init(rawValue: "\(target) misses the pin")
            )
        }
    }
}
