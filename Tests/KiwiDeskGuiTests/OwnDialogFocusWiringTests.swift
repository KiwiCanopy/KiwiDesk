import Foundation
import Testing

/// The own key window stand-down at the close-return raise (#929).
///
/// Ensures KiwiCore+Events.swift consults `!eventLoop.hasOwnKeyWindow()`
/// in the close-return raise condition so an active own dialog (Sparkle
/// update alert, NSAlert) is never submerged by a background window
/// raise.
@Suite("Own dialog focus wiring (#929)")
struct OwnDialogFocusWiringTests {
    @Test("the close-return raise stands down when own window is key")
    func raiseSiteConsultsOwnKeyWindowPredicate() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDeskCore/App/KiwiCore+Events.swift"
            )
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        try #require(!text.isEmpty)
        let anchor = "effects.removedWindow?.focusLost == true"
        let at = try #require(text.range(of: anchor))
        let condition = text[at.lowerBound...].prefix(240)
        #expect(condition.contains("!eventLoop.hasOwnKeyWindow()"))
    }
}
