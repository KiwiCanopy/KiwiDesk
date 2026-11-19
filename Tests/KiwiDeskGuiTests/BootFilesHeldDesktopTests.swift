import Foundation
import Testing

/// Boot files the Desktop each Space shows, so a full-screen Space
/// entered before the session's first switch keeps the Desktop the
/// live Spaces hold, and KiwiHub's overview names it (#3486). The
/// boot tail is not test-drivable, so the call is needled where it
/// runs: after the boot arrangement places the Spaces.
@Suite("Boot files the held Desktop (#3486)")
struct BootFilesHeldDesktopTests {
    @Test("finishBoot refiles after arranging the desk")
    func bootFilesTheRecord() throws {
        let source = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDeskCore/App/KiwiCore+Boot.swift"
                )
        ).split(whereSeparator: \.isWhitespace).joined()
        let boot = try #require(
            source.range(of: "privatefuncfinishBoot(){")
        )
        let body = source[boot.upperBound...]
        #expect(
            body.contains(
                "arrangeBootDesk(session:crash.takeBootSnapshot())"
                    + "refileTilingToggles()"
            )
        )
    }
}
