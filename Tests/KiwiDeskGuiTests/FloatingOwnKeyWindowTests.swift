import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// KiwiHub's panel floats above the normal level, which is what the
/// reading's `floatsOverWindows` facet keys on (#2373); the
/// consumers are `FloatingOwnPanelConsumerTests`'.
@Suite("Floating own key window (#2373)")
@MainActor
struct FloatingOwnKeyWindowTests {
    @Test("a window above the normal level floats, one at it does not")
    func levelVerdict() {
        #expect(EventLoop.floatsAboveWindows(.floating))
        #expect(EventLoop.floatsAboveWindows(.statusBar))
        #expect(!EventLoop.floatsAboveWindows(.normal))
    }

    @Test("KiwiHub's panel floats, as a panel")
    func kiwiHubFloats() {
        let panel = JumpPanelController(core: makeTestCore()).makePanel()
        #expect(EventLoop.floatsAboveWindows(panel.level))
        #expect((panel as NSWindow) is NSPanel)
    }

    /// The facet needs a real key window, so its classification is
    /// pinned where it is written: a non-modal panel above normal.
    @Test("the reading marks a non-modal floating panel")
    func readingMarksIt() throws {
        let reading = try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDeskCore/Events/EventLoop+RaiseStandDown.swift"
            )
        ).split(whereSeparator: \.isWhitespace).joined()
        #expect(
            reading.contains(
                "floatsOverWindows:classifiedisNSPanel"
                    + "&&app.modalWindow!==key"
                    + "&&floatsAboveWindows(key.level)"
            )
        )
    }
}
