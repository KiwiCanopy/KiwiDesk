import Foundation
import Testing

@testable import KiwiDesk

/// The Looks page's pointer to the AI page (#1685) draws only
/// where that page can open: it is withdrawn while a stored
/// profile is edited.
@Suite("AI look pointer")
struct AILookPointerTests {
    @Test("drawn only where the AI page is reachable")
    @MainActor
    func gate() {
        #expect(AILookPointer.isDrawn(editingStoredProfile: false))
        #expect(!AILookPointer.isDrawn(editingStoredProfile: true))
    }

    @Test("the view asks the gate with the model's state")
    func bodyConsultsTheGate() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks/"
                    + "AILookPointer.swift"
            )
        let squashed = try SourceScan.blankedSource(at: url)
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(
            squashed.contains(
                "ifSelf.isDrawn(editingStoredProfile:"
                    + "model.editingStoredProfile)"
            )
        )
        let mount = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Looks/"
                    + "LooksShelf.swift"
            )
        let shelf = try SourceScan.blankedSource(at: mount)
        #expect(shelf.occurrences(of: "AILookPointer(model: model)") == 1)
    }
}
