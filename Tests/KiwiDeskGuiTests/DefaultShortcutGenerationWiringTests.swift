import Foundation
import Testing

/// The generation top-up (#2211) runs at boot: every behaviour
/// suite calls it directly, so a deleted call would leave them all
/// green while no upgrader got a row.
@Suite("Generation top-up wiring (#2211)")
struct DefaultShortcutGenerationWiringTests {
    @Test("boot calls the generation top-up once")
    func bootCallsTheTopUp() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDeskCore")
        var calls: [String: Int] = [:]
        for url in try SourceScan.swiftSources(under: root) {
            let source = SourceScan.stripComments(
                try String(contentsOf: url, encoding: .utf8)
            )
            let hits =
                source.occurrences(
                    of: "topUpGenerationShortcuts()"
                ) - source.occurrences(of: "func topUpGenerationShortcuts()")
            if hits > 0 { calls[url.lastPathComponent] = hits }
        }
        #expect(calls == ["KiwiCore+Boot.swift": 1])
    }
}
