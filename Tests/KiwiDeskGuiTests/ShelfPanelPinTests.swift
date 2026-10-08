import Foundation
import Testing

/// **Both test cores pin the shelf panel off** (#1894): the Core
/// twin's pin is counted by `ShelfPanelInertTests`, which cannot
/// reach this target's twin, so the pin is held here for both.
@Suite("Shelf panel pin (#1894)")
struct ShelfPanelPinTests {
    @Test("both twins hold shelf panels out")
    func twinsPinPanelsOff() throws {
        let repo = SourceScan.repoRoot(from: #filePath)
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: repo.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                )
            )
            // One write, and it is the pin: a later `= true` in the
            // same twin would undo it.
            #expect(
                source.components(separatedBy: "ordersPanels =").count
                    == 2
                    && source.contains("core.shelves.ordersPanels = false"),
                .init(rawValue: "\(target) misses the pin")
            )
        }
    }
}
