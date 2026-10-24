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
            // One write per manager, and it is the pin: a later
            // `= true` in the same twin would undo it. The overflow
            // marks' panels are the second (#2235).
            #expect(
                source.components(separatedBy: "ordersPanels =").count
                    == 3
                    && source.contains("core.shelves.ordersPanels = false")
                    && source.contains(
                        "core.overflowMarks.ordersPanels = false"
                    )
                    // A hidden shelf's handle is a panel too
                    // (#761).
                    && source.contains(
                        "core.shelves.handles.ordersHandlePanels"
                            + " = false"
                    ),
                .init(rawValue: "\(target) misses the pin")
            )
        }
    }
}
