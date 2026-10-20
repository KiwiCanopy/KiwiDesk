import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// A lens hold's reminder pill (#2103 rulings 12, 14): centred on
/// the held window, on an overlay of its own so a refusal flashed
/// on that window never replaces it, following the window at each
/// settle, and a stand-down screen makes no landing. These cores
/// start the private runtime, so the pills draw real panels.
@Suite("KiwiVision lens hold pill", .serialized)
@MainActor
struct KiwiVisionHoldPillTests {
    private typealias F = VisionHoldFixture

    private func core() -> KiwiCore {
        let (core, _) = F.core()
        core.borders.privateRuntimeStarted = true
        return core
    }

    @Test("the hold pill is centred on its window and follows it")
    func pillIsCentredAndFollows() throws {
        let overlay = SizeLimitOverlay()
        let frame = CGRect(x: 200, y: 200, width: 800, height: 600)
        #expect(overlay.hold(window: 1, frame: frame, text: "Wait"))
        let pill = try #require(overlay.pillForTest(1))
        let flipped = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        #expect(abs(pill.panel.midX - flipped.midX) < 1)
        #expect(abs(pill.panel.midY - flipped.midY) < 1)
        let moved = frame.offsetBy(dx: 120, dy: 0)
        #expect(overlay.hold(window: 1, frame: moved, text: "Wait"))
        let after = try #require(overlay.pillForTest(1))
        #expect(abs(after.panel.midX - (flipped.midX + 120)) < 1)
    }

    @Test("a refusal on the held window leaves the reminder standing")
    func refusalLeavesTheReminder() throws {
        let core = core()
        F.focus(core, F.stranger)
        try #require(
            core.borders.holdPillOverlay.pillForTest(F.stranger.raw) != nil
        )
        core.flashRefusalPill(
            F.stranger,
            text: "No",
            symbol: "nosign",
            announce: false
        )
        #expect(
            core.borders.holdPillOverlay.pillForTest(F.stranger.raw) != nil
        )
    }

    @Test("a standing hold's pill follows its window at each settle")
    func settleMovesThePill() throws {
        let core = core()
        F.focus(core, F.stranger)
        let before = try #require(
            core.borders.holdPillOverlay.pillForTest(F.stranger.raw)
        )
        let frame = core.state.windows[F.stranger]!.frame
        core.state.apply(
            .windowMoved(F.stranger, frame.offsetBy(dx: 150, dy: 0))
        )
        core.updateVision()
        let after = try #require(
            core.borders.holdPillOverlay.pillForTest(F.stranger.raw)
        )
        #expect(abs(after.panel.midX - (before.panel.midX + 150)) < 1)
    }

    @Test("a landing while every screen stands down holds nothing")
    func standDownMakesNoLanding() {
        let core = core()
        let displays = Set(core.visionRequest().screens.map(\.display))
        core.noteVisionStandDown(displays)
        F.focus(core, F.stranger)
        #expect(core.vision.hold == nil)
        core.noteVisionStandDown([])
        F.focus(core, F.other)
        #expect(core.vision.hold?.window == F.other)
    }
}
