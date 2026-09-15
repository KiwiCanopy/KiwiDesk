import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A GUI-created layer is seeded with the app-chrome rows —
/// ⌃⌥K and ⌃⌥, — through the ONE `appChromeRows` the base seed
/// also takes (#602, #1381). The seed is a view-private action,
/// so the wiring is pinned by its call rather than driven: a
/// hand-listed `[showShortcutsRow()]` beside the seam is how a
/// second chrome row lands in the base layer and nowhere else.
@Suite("New layers carry the app-chrome rows")
struct LayerChromeSeedTests {
    @Test("addLayer seeds through appChromeRows")
    func addLayerSeedsThroughTheSeam() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Sections/"
                        + "LayerStripEditor.swift"
                )
        )
        #expect(
            source.contains(
                "bindings: DefaultKeybindings.appChromeRows()"
            )
        )
        #expect(!source.contains("showShortcutsRow()"))
    }
}
