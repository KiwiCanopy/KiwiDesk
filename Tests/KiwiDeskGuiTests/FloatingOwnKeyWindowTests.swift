import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiHub floats over every window, so it reads as no own key
/// window and the focus ring and KiwiVision stay on the focus
/// beneath it; Settings, at the normal level, keeps today's
/// reading (#2373). The production reading needs a real key
/// window, so its gate is pinned by a needle beside the verdict.
@Suite("Floating own key window (#2373)")
@MainActor
struct FloatingOwnKeyWindowTests {
    @Test("a window above the normal level floats, one at it does not")
    func levelVerdict() {
        #expect(EventLoop.floatsAboveWindows(.floating))
        #expect(EventLoop.floatsAboveWindows(.statusBar))
        #expect(!EventLoop.floatsAboveWindows(.normal))
    }

    @Test("the reading drops a floating key window, KiwiHub floats")
    func readingDropsKiwiHub() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        let reading = try SourceScan.blankedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDeskCore/Events/EventLoop+RaiseStandDown.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            reading.contains(
                "guardletkey,!floatsAboveWindows(key.level)else{returnnil}"
            )
        )
        let hub = try SourceScan.blankedSource(
            at: root.appendingPathComponent(
                "Sources/KiwiDesk/Jump/JumpPanelController.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(hub.contains("panel.level=.floating"))
        #expect(EventLoop.floatsAboveWindows(.floating))
    }
}
