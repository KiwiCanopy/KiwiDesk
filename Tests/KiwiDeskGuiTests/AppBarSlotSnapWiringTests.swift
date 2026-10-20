import Foundation
import Testing

/// On a new slot the App Bar's items, their box glass and the float
/// break all take the run's one verdict, so a box never glides while
/// its item snaps (code review, 2026-10-20). Off the main actor: it
/// reads one file.
@Suite("App Bar slot snap reaches every run member")
struct AppBarSlotSnapWiringTests {
    @Test func everyMemberTakesTheVerdict() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Bar/AppBarOverlay.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
        #expect(source.contains("moveFrame(view, frames[index], travels)"))
        #expect(source.components(separatedBy: "animated: travels").count == 3)
        #expect(!source.contains("animated: !lands\n"))
    }
}
