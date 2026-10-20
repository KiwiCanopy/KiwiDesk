import Foundation
import Testing

/// An inheriting override row's readout wraps rather than cutting a
/// word out of its middle (owner eyeball, 2026-10-20: "follows Gaps
/// & Borde…uter 16 pt"), and keeps its hover text.
@Suite("An override readout never cuts a word")
struct OverrideReadoutWrapTests {
    @Test func readoutWraps() throws {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/SpaceOverrides/"
                    + "OverrideControls.swift"
            )
        let source = try SourceScan.strippedSource(at: url)
        let start = try #require(
            source.range(of: "func inheritedReadout(")
        )
        let tail = source[start.upperBound...]
        let end = try #require(tail.range(of: "\n    }\n")).lowerBound
        let body = tail[..<end]
        #expect(body.contains("Text(inheritedText(inherited.value))"))
        #expect(!body.contains(".truncationMode("))
        #expect(!body.contains(".lineLimit(1)\n                .help"))
        #expect(body.contains(".help(inheritedText(inherited.value))"))
    }
}
