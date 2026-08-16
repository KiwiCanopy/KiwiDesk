import Foundation
import Testing

/// The session seam's wiring, needled rather than probed on a
/// live core (#835).
///
/// `WakeSessionPresenceWiringTests` proves the seam is not the
/// inert default, but it cannot see a seam FROZEN at bootstrap —
/// a captured `.live()` reads identically from a test, and a
/// guard-prover run proved that mutation green (2026-08-13).
/// Freezing is the defect shape the manager's "re-read at fire
/// time, not at wake" design exists to prevent, so here the
/// closure BODY is the assertion.
@Suite("Wake session seam wiring (#835)")
struct WakeSessionSeamWiringTests {
    private func source(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(path)
        let text = SourceScan.stripComments(
            try String(contentsOf: url, encoding: .utf8)
        )
        // Fail-shut on the scan itself: an empty read passes the
        // needle below for having found nothing.
        try #require(!text.isEmpty)
        return text
    }

    @Test("bootstrap wires the session seam to a fresh read")
    func sessionSeamReadsFreshEachCall() throws {
        let text = try source(
            "Sources/KiwiDeskCore/App/KiwiCore+Bootstrap.swift"
        )
        #expect(
            text.contains("sessionPresence = { .live() }"),
            """
            The session seam is no longer wired to a call of \
            .live() inside the closure. Wired to a value captured \
            once, every replay reports the session as it was at \
            bootstrap — which is never locked, since bootstrap \
            runs before any lock (#835).
            """
        )
    }
}
