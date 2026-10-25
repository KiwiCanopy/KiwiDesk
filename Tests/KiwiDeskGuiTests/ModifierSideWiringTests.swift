import Foundation
import Testing

/// A side tap macOS refused before Accessibility was granted is
/// asked for again at `KiwiCore.start()` (#2601), which no test core
/// may run (`TestCoreStartTripwireTests`), so the call is read from
/// source.
@Suite("Modifier side tap re-arms at start (#2601)")
struct ModifierSideWiringTests {
    @Test("start() asks for the side tap again")
    func startRetries() throws {
        let body = try SourceScan.functionBody(
            of: "start",
            in: "KiwiCore+Boot.swift",
            under: "App"
        )
        #expect(body.contains("keys.retrySideTap()"))
    }
}
