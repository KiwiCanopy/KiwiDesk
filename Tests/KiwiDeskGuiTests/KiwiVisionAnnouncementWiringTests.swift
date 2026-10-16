import Foundation
import Testing

@testable import KiwiDesk

/// VoiceOver hears every KiwiVision change, whichever door made it
/// (#2103). The wiring lives in `AppDelegate+KiwiVision`, which no
/// test constructs, so it is pinned where it lives.
@Suite("KiwiVision announcement is wired")
struct KiwiVisionAnnouncementWiringTests {
    @Test("the app delegate wires the announcement and the page")
    func delegateWiresTheAnnouncement() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let text = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate+KiwiVision.swift"
            )
        ).filter { !$0.isWhitespace }
        for needle in [
            "core.vision.onChange={[weakself]",
            "core.onAppWideChange={[weakself]in",
            "notification:.announcementRequested",
        ] {
            #expect(text.contains(needle), "missing \(needle)")
        }
        let delegate = try SourceScan.strippedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/AppDelegate.swift"
            )
        )
        #expect(delegate.contains("wireKiwiVision()"))
    }
}
